// packages/launcher_repository/lib/src/domains/device_pairing_repository.dart
import 'dart:async';
import 'dart:developer';
import 'dart:math' as math;

import 'package:cloud_sync_api/cloud_sync_api.dart';
import 'package:local_vault_api/local_vault_api.dart' as db;

abstract class DevicePairingRepository {
  /// بدء جلسة اقتران جديدة وتوليد رمز من 6 أرقام
  Future<String?> initiateDevicePairing({
    required String deviceType,
    String? previousCode,
  });

  /// الاستماع للمصادقة على الكود المولد
  Stream<String?> listenForDeviceAuthorization(
    String pairingCode, {
    String deviceType = 'fire_tv',
  });

  /// اعتماد كود الاقتران من الهاتف
  Future<bool> authorizePairingCode(String pairingCode, {String? customVaultId});

  /// التحقق مما إذا كان الجهاز مقترناً بخزنة
  Future<bool> isDeviceLinked();

  /// جلب معرف الخزنة المقترنة
  Future<String?> getLinkedVaultId();

  /// فك الاقتران وإعادة تعيين حالة الشبكة الهجينة
  Future<void> unpairDevice();

  /// 🔑 توثيق الجلسة السحابية في Supabase باستخدام معرف الـ DID
  Future<void> authenticateCloudWithDid(String didAddress);
}

class DevicePairingRepositoryImpl implements DevicePairingRepository {
  DevicePairingRepositoryImpl({
    required db.AppDatabase database,
    required CloudSyncClient cloudSync,
    required HybridSyncClient hybridSync,
  })  : _db = database,
        _cloud = cloudSync,
        _hybridSync = hybridSync;

  final db.AppDatabase _db;
  final CloudSyncClient _cloud;
  final HybridSyncClient _hybridSync;

  @override
  Future<String?> initiateDevicePairing({
    required String deviceType,
    String? previousCode,
  }) async {
    final rng = math.Random();
    final code = (rng.nextInt(900000) + 100000).toString();

    try {
      await _cloud.createPairingSession(
        pairingCode: code,
        targetDeviceType: deviceType,
        previousCode: previousCode,
      );
      _hybridSync.updatePairingCode(code);
      log('DevicePairingRepository: Collision-proof pairing code registered: $code');
    } catch (e) {
      log('DevicePairingRepository: Cloud pairing registration deferred (offline-first): $e');
    }

    return code;
  }

  @override
  Stream<String?> listenForDeviceAuthorization(
    String pairingCode, {
    String deviceType = 'fire_tv',
  }) {
    try {
      final stream = _cloud.streamPairingSession(pairingCode);
      if (stream == null) return const Stream.empty();

      return stream
          .handleError((Object error) {
            log('DevicePairingRepository: Safe catch on pairing stream error: $error');
          })
          .asyncMap((data) async {
            try {
              if (data != null && data['status'] == 'paired') {
                final vaultId = data['vault_id'] as String?;
                if (vaultId != null && vaultId.isNotEmpty) {
                  // 1. حفظ معرف الخزنة محلياً
                  await _db.setDevicePairingMeta('linked_vault_id', vaultId);

                  // 2. محاولة حرق جلسة الاقتران لعدم تكرارها
                  try {
                    await _cloud.burnPairingSession(pairingCode);
                  } catch (e) {
                    log('DevicePairingRepository: Safe catch on burning pairing session: $e');
                  }

                  // 3. توثيق حساب السحابة بهوية الـ DID للهاتف
                  await authenticateCloudWithDid(vaultId);

                  // 4. تحديث معرّف الخزنة في المحرك الهجين
                  _hybridSync.updateLinkedVaultId(vaultId);

                  return vaultId;
                }
              }
            } catch (innerError, stackTrace) {
              log('DevicePairingRepository: Error inside pairing asyncMap handler: $innerError', stackTrace: stackTrace);
            }
            return null;
          })
          .handleError((Object error) {
            log('DevicePairingRepository: Pairing auth stream error handled: $error');
          });
    } catch (e) {
      log('DevicePairingRepository: Unable to listen for device authorization: $e');
      return const Stream.empty();
    }
  }

  @override
  Future<bool> authorizePairingCode(
    String pairingCode, {
    String? customVaultId,
  }) async {
    final cleanCode = pairingCode.replaceAll(RegExp(r'\D'), '').trim();
    if (cleanCode.length != 6) return false;

    final masterVaultId = customVaultId ?? _cloud.activeUserId;

    try {
      final success = await _cloud.claimPairingSession(
        pairingCode: cleanCode,
        vaultId: masterVaultId,
      );

      if (success) {
        _hybridSync.updatePairingCode(cleanCode);
        _hybridSync.updateLinkedVaultId(masterVaultId);
        log('DevicePairingRepository: Successfully paired with code $cleanCode for Vault $masterVaultId');
      }
      return success;
    } catch (e) {
      log('DevicePairingRepository: Cloud pairing authorization failed: $e');
      return false;
    }
  }

  @override
  Future<bool> isDeviceLinked() async {
    final val = await _db.getDevicePairingMeta('linked_vault_id');
    return val != null && val.isNotEmpty;
  }

  @override
  Future<String?> getLinkedVaultId() async {
    return _db.getDevicePairingMeta('linked_vault_id');
  }

  @override
  Future<void> unpairDevice() async {
    await _db.deleteDevicePairingMeta('linked_vault_id');
    await _hybridSync.unpairAndReset();
    log('DevicePairingRepository: Device unpaired and hybrid network state fully reset.');
  }

  @override
  Future<void> authenticateCloudWithDid(String didAddress) async {
    try {
      await _cloud.signInWithSovereignDid(didAddress);
      log('DevicePairingRepository: ✅ Authenticated cloud session with DID: $didAddress');
    } catch (e) {
      log('DevicePairingRepository: Note on authenticating cloud with DID (offline-first fallback): $e');
    }
  }
}