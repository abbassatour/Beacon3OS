// packages/launcher_repository/lib/src/domains/comms_repository.dart
import 'dart:async';
import 'dart:developer';
import 'dart:math' as math;

import 'package:cloud_sync_api/cloud_sync_api.dart';
import 'package:drift/drift.dart';
import 'package:local_vault_api/local_vault_api.dart';
import 'package:system_hardware_api/system_hardware_api.dart';
import 'package:uuid/uuid.dart';

/// أنواع الأوامر السحابية الواردة عن بُعد من Alexa+
enum RemoteActionType {
  locateDevice,
  triggerSos,
  unknown,
}

/// كائن يمثل الأمر السحابي الوارد لحظياً
class RemoteActionEvent {
  const RemoteActionEvent({
    required this.id,
    required this.actionType,
    this.payload = const {},
  });

  final String id;
  final RemoteActionType actionType;
  final Map<String, dynamic> payload;

  factory RemoteActionEvent.fromMap(Map<String, dynamic> map) {
    final rawType = (map['action_type'] as String? ?? '').toUpperCase();
    RemoteActionType type;
    switch (rawType) {
      case 'LOCATE_DEVICE':
        type = RemoteActionType.locateDevice;
        break;
      case 'TRIGGER_SOS':
        type = RemoteActionType.triggerSos;
        break;
      default:
        type = RemoteActionType.unknown;
    }

    return RemoteActionEvent(
      id: map['id'] as String? ?? '',
      actionType: type,
      payload: map['payload'] is Map<String, dynamic>
          ? map['payload'] as Map<String, dynamic>
          : const {},
    );
  }
}

abstract class CommsRepository {
  Stream<List<Contact>> watchContacts();
  Future<List<Contact>> getEmergencyContacts();
  Future<Contact?> findContact(String query);
  Future<String> saveContact({
    required String name,
    required String phoneNumber,
    String? relationship,
    bool isEmergency = false,
  });
  Future<void> deleteContact(dynamic contactOrId);

  /// مزامنة جهات اتصال الهاتف وتسويتها داخل الخزنة المحلية عبر خوارزمية تفاضلية (Diffing Engine)
  Future<({int addedCount, int updatedCount, int deletedCount})>
      syncDeviceContactsToVault();

  Stream<List<MessagesVaultData>> watchMessages(String contactIdentifier);
  Future<List<MessagesVaultData>> getUnreadMessages();
  Future<void> markMessagesAsRead(String contactIdentifier);
  Future<String> recordMessage({
    required String contactIdentifier,
    required String senderName,
    required String messageText,
    String platform = 'sms',
    bool isOutgoing = false,
  });

  Future<String> triggerEmergencySos({
    double? latitude,
    double? longitude,
    int? batteryLevel,
  });

  /// 🛰️ تدفق الأحداث السحابية الواردة عن بُعد من أليكسا (Locate, SOS)
  Stream<RemoteActionEvent> get remoteActionEvents;

  /// 🚨 تنفيذ بروتوكول تحديد موقع الهاتف (وميض الكشاف السريع Strobe Flashlight)
  Future<void> executeLocateDevice({int pulseCycles = 8});

  Future<void> restoreCommsFromCloud();
  Future<void> syncPendingComms();

  /// 🛰️ بدء الاستماع اللحظي للسحابة وتحديث الخزنة فوراً
  void initializeRealtimeSync();

  /// 🛑 إيقاف الاشتراكات اللحظية بأمان
  void dispose();

  // ===========================================================================
  // 🔗 بروتوكول الاقتران السيادي بدون حسابات (Zero-Login Device Pairing)
  // ===========================================================================

  /// توليد كود اقتران من 6 أرقام للتلفزيون والكمبيوتر وبدء الجلسة
  Future<String?> initiateDevicePairing({required String deviceType});

  /// الاستماع اللحظي على شاشة العرض لانتظار مصادقة الهاتف
  Stream<String?> listenForDeviceAuthorization(String pairingCode);

  /// مصادقة كود الاقتران عبر الهاتف الرئيسي (يدوياً أو بالأمر الصوتي)
  Future<bool> authorizePairingCode(String pairingCode, {String? customVaultId});

  /// التحقق من حالة اقتران هذا الجهاز بخزنة رئيسية
  Future<bool> isDeviceLinked();

  /// جلب معرف الخزنة المقترنة
  Future<String?> getLinkedVaultId();

  /// فك الاقتران والعودة للوضع المستقل
  Future<void> unpairDevice();
}

class CommsRepositoryImpl implements CommsRepository {
  CommsRepositoryImpl({
    required AppDatabase database,
    required CloudSyncClient cloudSync,
    required HardwareClient hardware,
  })  : _db = database,
        _cloud = cloudSync,
        _hardware = hardware;

  final AppDatabase _db;
  final CloudSyncClient _cloud;
  final HardwareClient _hardware;
  final _uuid = const Uuid();

  StreamSubscription<dynamic>? _authSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _realtimeContactsSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _remoteActionsSubscription;

  final StreamController<RemoteActionEvent> _remoteActionController =
      StreamController<RemoteActionEvent>.broadcast();

  @override
  Stream<RemoteActionEvent> get remoteActionEvents =>
      _remoteActionController.stream;

  // ===========================================================================
  // 🛰️ إدارة الاستماع اللحظي السحابي (Supabase Realtime Sync)
  // ===========================================================================

  @override
  void initializeRealtimeSync() {
    _authSubscription?.cancel();
    _authSubscription = _cloud.authStateChanges?.listen((authState) {
      if (_cloud.isAuthenticated) {
        _subscribeToRealtimeContacts();
        _subscribeToRemoteActions();
      } else {
        _realtimeContactsSubscription?.cancel();
        _realtimeContactsSubscription = null;
        _remoteActionsSubscription?.cancel();
        _remoteActionsSubscription = null;
      }
    });

    // الاشتراك في الأوامر السحابية فوراً (يعمل أيضاً مع الضيف المحلي)
    _subscribeToRemoteActions();

    if (_cloud.isAuthenticated) {
      _subscribeToRealtimeContacts();
    }
  }

  void _subscribeToRealtimeContacts() {
    _realtimeContactsSubscription?.cancel();
    final stream = _cloud.streamContacts();
    if (stream != null) {
      _realtimeContactsSubscription = stream.listen(
        _handleCloudRealtimeContacts,
        onError: (Object error) {
          log('CommsRepository: Realtime contacts stream error: $error');
        },
      );
      log('CommsRepository: 🛰️ Subscribed to Supabase Realtime contacts stream.');
    }
  }

  void _subscribeToRemoteActions() {
    _remoteActionsSubscription?.cancel();
    final stream = _cloud.streamRemoteActions();
    if (stream != null) {
      _remoteActionsSubscription = stream.listen(
        _handleIncomingRemoteActions,
        onError: (Object error) {
          log('CommsRepository: Remote actions stream error: $error');
        },
      );
      log('CommsRepository: 🛰️ Subscribed to Alexa+ remote_actions stream.');
    }
  }

  /// معالجة الأوامر الفورية الواردة من خادم Alexa+ MCP
  Future<void> _handleIncomingRemoteActions(
    List<Map<String, dynamic>> rawActions,
  ) async {
    for (final raw in rawActions) {
      final event = RemoteActionEvent.fromMap(raw);
      if (event.id.isEmpty || event.actionType == RemoteActionType.unknown) {
        continue;
      }

      log('CommsRepository: ⚡ Alexa+ Action Received -> [${event.actionType}] (ID: ${event.id})');

      // 1. تأكيد استلام الأمر للسحابة
      await _cloud.acknowledgeRemoteAction(event.id, status: 'acknowledged');

      // 2. ضخ الحدث في التدفق للاستجابة الصوتية والحسية
      _remoteActionController.add(event);

      // 3. التنفيذ العتادي المباشر
      if (event.actionType == RemoteActionType.locateDevice) {
        await executeLocateDevice();
      } else if (event.actionType == RemoteActionType.triggerSos) {
        await triggerEmergencySos();
      }

      // 4. تأكيد اكتمال التنفيذ
      await _cloud.acknowledgeRemoteAction(event.id, status: 'completed');
    }
  }

  @override
  Future<void> executeLocateDevice({int pulseCycles = 8}) async {
    log('CommsRepository: 📢 Locating Device: Flashing torch & hardware strobe...');
    try {
      for (var i = 0; i < pulseCycles; i++) {
        await _hardware.toggleFlashlight(enable: true);
        await Future<void>.delayed(const Duration(milliseconds: 180));
        await _hardware.toggleFlashlight(enable: false);
        await Future<void>.delayed(const Duration(milliseconds: 180));
      }
    } catch (e) {
      log('CommsRepository: Hardware locator strobe error: $e');
    }
  }

  Future<void> _handleCloudRealtimeContacts(
    List<Map<String, dynamic>> cloudContacts,
  ) async {
    try {
      if (cloudContacts.isEmpty) return;

      final localContacts = await (_db.select(_db.contacts)).get();
      final Map<String, Contact> localMap = {
        for (final c in localContacts) c.id: c,
      };

      await _db.batch((batch) {
        for (final cloudItem in cloudContacts) {
          final id = cloudItem['id'] as String?;
          if (id == null || id.isEmpty) continue;

          final local = localMap[id];
          if (local != null && !local.isSynced) continue;

          final deletedAtStr = cloudItem['deleted_at'] as String?;
          final DateTime? deletedAt =
              deletedAtStr != null ? DateTime.tryParse(deletedAtStr) : null;

          if (deletedAt != null) {
            if (local != null) {
              batch.delete(
                _db.contacts,
                ContactsCompanion(id: Value(id)),
              );
            }
          } else {
            final name = (cloudItem['name'] as String? ?? '').trim();
            final phone = (cloudItem['phone_number'] as String? ?? '').trim();
            if (name.isEmpty || phone.isEmpty) continue;

            final relationship = cloudItem['relationship'] as String?;
            final isEmergency = cloudItem['is_emergency'] as bool? ?? false;

            batch.insert(
              _db.contacts,
              ContactsCompanion.insert(
                id: id,
                name: name,
                phoneNumber: phone,
                relationship: Value(relationship),
                isEmergency: Value(isEmergency),
                isSynced: const Value(true),
              ),
              mode: InsertMode.insertOrReplace,
            );
          }
        }
      });
      log('CommsRepository: ⚡ Reconciled ${cloudContacts.length} realtime cloud contacts.');
    } catch (e, st) {
      log('CommsRepository: Error reconciling realtime contacts: $e',
          stackTrace: st);
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _realtimeContactsSubscription?.cancel();
    _remoteActionsSubscription?.cancel();
    _remoteActionController.close();
  }

  // ===========================================================================
  // 📇 العمليات الأساسية لجهات الاتصال
  // ===========================================================================

  @override
  Stream<List<Contact>> watchContacts() => _db.watchAllContacts();

  @override
  Future<List<Contact>> getEmergencyContacts() => _db.getEmergencyContacts();

  @override
  Future<Contact?> findContact(String query) =>
      _db.findContactByNameOrRelation(query);

  @override
  Future<String> saveContact({
    required String name,
    required String phoneNumber,
    String? relationship,
    bool isEmergency = false,
  }) async {
    final id = await _db.insertContact(
      name: name,
      phoneNumber: phoneNumber,
      relationship: relationship,
      isEmergency: isEmergency,
    );

    _hardware.saveDeviceContact(
      name: name,
      phoneNumber: phoneNumber,
    ).catchError((Object error) {
      log('CommsRepository: Device contact write skipped/failed: $error');
      return false;
    });

    _cloud.syncContact(
      id: id,
      name: name,
      phoneNumber: phoneNumber,
      relationship: relationship,
      isEmergency: isEmergency,
    ).catchError((Object error) {
      log('CommsRepository: Cloud contact sync deferred: $error');
    });

    return id;
  }

  @override
  Future<void> deleteContact(dynamic contactOrId) async {
    final String id =
        contactOrId is Contact ? contactOrId.id : contactOrId.toString();
    await _db.softDeleteContact(id);
    _cloud.softDeleteContactInCloud(id).catchError((Object error) {
      log('CommsRepository: Cloud contact delete deferred: $error');
    });
  }

  @override
  Future<({int addedCount, int updatedCount, int deletedCount})>
      syncDeviceContactsToVault() async {
    try {
      final deviceRecords = await _hardware.getDeviceContacts();
      if (deviceRecords.isEmpty) {
        log('CommsRepository: No contacts found on device or permission rejected.');
        return (addedCount: 0, updatedCount: 0, deletedCount: 0);
      }

      final existingContacts = await (_db.select(_db.contacts)
            ..where((c) => c.deletedAt.isNull()))
          .get();

      final Map<String, Contact> map9 = {};
      final Map<String, Contact> map8 = {};

      for (final c in existingContacts) {
        final digits = c.phoneNumber.replaceAll(RegExp(r'\D'), '');
        if (digits.isEmpty) continue;

        if (digits.length >= 9) {
          map9[digits.substring(digits.length - 9)] = c;
        } else {
          map9[digits] = c;
        }

        if (digits.length >= 8) {
          map8[digits.substring(digits.length - 8)] = c;
        }
      }

      var addedCount = 0;
      var updatedCount = 0;
      var deletedCount = 0;

      final Set<String> matchedExistingIds = {};
      final Set<String> processedDeviceKeys = {};

      await _db.batch((batch) {
        for (final record in deviceRecords) {
          final cleanPhone = _sanitizeNumber(record.phoneNumber);
          final digits = cleanPhone.replaceAll(RegExp(r'\D'), '');
          if (digits.length < 3) continue;

          final key9 = digits.length >= 9
              ? digits.substring(digits.length - 9)
              : digits;
          final key8 = digits.length >= 8
              ? digits.substring(digits.length - 8)
              : null;

          if (processedDeviceKeys.contains(key9)) continue;
          processedDeviceKeys.add(key9);

          final existing = map9[key9] ?? (key8 != null ? map8[key8] : null);

          if (existing != null) {
            matchedExistingIds.add(existing.id);

            final nameChanged = existing.name != record.name;
            final phoneChanged = existing.phoneNumber != cleanPhone;

            if (nameChanged || phoneChanged) {
              batch.update(
                _db.contacts,
                ContactsCompanion(
                  name: Value(record.name),
                  phoneNumber: Value(cleanPhone),
                  updatedAt: Value(DateTime.now()),
                  isSynced: const Value(false),
                ),
                where: (tbl) => tbl.id.equals(existing.id),
              );
              updatedCount++;
            }
          } else {
            final newId = _uuid.v4();
            batch.insert(
              _db.contacts,
              ContactsCompanion.insert(
                id: newId,
                name: record.name,
                phoneNumber: cleanPhone,
                isEmergency: const Value(false),
                isSynced: const Value(false),
              ),
            );
            addedCount++;
          }
        }

        for (final existing in existingContacts) {
          if (!matchedExistingIds.contains(existing.id)) {
            if (existing.isEmergency) {
              log('CommsRepository: Retaining emergency contact missing from device: ${existing.name}');
              continue;
            }

            batch.update(
              _db.contacts,
              ContactsCompanion(
                deletedAt: Value(DateTime.now()),
                updatedAt: Value(DateTime.now()),
                isSynced: const Value(false),
              ),
              where: (tbl) => tbl.id.equals(existing.id),
            );
            deletedCount++;
          }
        }
      });

      syncPendingComms().catchError((Object err) {
        log('CommsRepository: Cloud sync deferred after diffing: $err');
      });

      return (
        addedCount: addedCount,
        updatedCount: updatedCount,
        deletedCount: deletedCount,
      );
    } catch (e, st) {
      log('CommsRepository: Error during contacts reconciliation diff: $e',
          stackTrace: st);
      return (addedCount: 0, updatedCount: 0, deletedCount: 0);
    }
  }

  String _sanitizeNumber(String phone) {
    return phone.replaceAll(RegExp(r'[\s\(\)\-\.]'), '').trim();
  }

  @override
  Stream<List<MessagesVaultData>> watchMessages(String contactIdentifier) =>
      _db.watchMessagesForContact(contactIdentifier);

  @override
  Future<List<MessagesVaultData>> getUnreadMessages() =>
      _db.getUnreadMessages();

  @override
  Future<void> markMessagesAsRead(String contactIdentifier) async {
    await _db.markMessagesAsRead(contactIdentifier);
    _cloud.markMessagesAsReadInCloud(contactIdentifier).catchError((Object error) {
      log('CommsRepository: Cloud mark read deferred: $error');
    });
  }

  @override
  Future<String> recordMessage({
    required String contactIdentifier,
    required String senderName,
    required String messageText,
    String platform = 'sms',
    bool isOutgoing = false,
  }) async {
    final id = await _db.insertMessage(
      contactIdentifier: contactIdentifier,
      senderName: senderName,
      messageText: messageText,
      platform: platform,
      isOutgoing: isOutgoing,
    );

    _cloud.syncMessage(
      id: id,
      contactIdentifier: contactIdentifier,
      senderName: senderName,
      messageText: messageText,
      platform: platform,
      isOutgoing: isOutgoing,
    ).catchError((Object error) {
      log('CommsRepository: Cloud message sync deferred: $error');
    });

    return id;
  }

  @override
  Future<String> triggerEmergencySos({
    double? latitude,
    double? longitude,
    int? batteryLevel,
  }) async {
    final settings = await _db.getSettings();
    final shareGps = settings.shareGpsOnSos;
    final actualBattery =
        batteryLevel ?? await _hardware.getBatteryPercentage();

    double actualLat = latitude ?? 0.0;
    double actualLng = longitude ?? 0.0;

    if (shareGps && (latitude == null || longitude == null)) {
      final coords = await _hardware.getCurrentLocation();
      if (coords != null) {
        actualLat = coords.latitude;
        actualLng = coords.longitude;
      }
    }

    final effectiveLat = shareGps ? actualLat : 0.0;
    final effectiveLng = shareGps ? actualLng : 0.0;

    final googleMapsUrl =
        (shareGps && effectiveLat != 0.0 && effectiveLng != 0.0)
            ? 'https://maps.google.com/?q=$effectiveLat,$effectiveLng'
            : (shareGps
                ? 'GPS Unavailable (Searching satellites...)'
                : 'GPS Sharing Disabled');

    log('CommsRepository: SOS Triggered! Lat: $effectiveLat, Lng: $effectiveLng, Battery: $actualBattery%');

    final alertId = await _db.insertSosAlert(
      latitude: effectiveLat,
      longitude: effectiveLng,
      batteryLevel: actualBattery,
      googleMapsUrl: googleMapsUrl,
    );

    _cloud.broadcastEmergencySos(
      id: alertId,
      latitude: effectiveLat,
      longitude: effectiveLng,
      batteryLevel: actualBattery,
    ).catchError((Object error) {
      log('CommsRepository: Cloud SOS broadcast deferred: $error');
    });

    if (settings.autoDialEmergency) {
      final emergencyContacts = await _db.getEmergencyContacts();
      if (emergencyContacts.isNotEmpty) {
        final primary = emergencyContacts.first;
        await _hardware.callPhoneNumber(primary.phoneNumber);
      }
    }

    return alertId;
  }

  @override
  Future<void> restoreCommsFromCloud() async {
    if (!_cloud.isAuthenticated) return;
    try {
      final cloudContacts = await _cloud.fetchContacts();
      if (cloudContacts.isEmpty) return;

      await _db.batch((batch) {
        for (final c in cloudContacts) {
          batch.insert(
            _db.contacts,
            ContactsCompanion.insert(
              id: c['id'] as String,
              name: c['name'] as String,
              phoneNumber: c['phone_number'] as String,
              relationship: Value(c['relationship'] as String?),
              isEmergency: Value(c['is_emergency'] as bool? ?? false),
              isSynced: const Value(true),
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
      });
      log('CommsRepository: ⚡ Restored ${cloudContacts.length} contacts from cloud in batch.');
    } catch (e, st) {
      log('CommsRepository: Contacts cloud restore error: $e', stackTrace: st);
    }
  }

  @override
  Future<void> syncPendingComms() async {
    if (!_cloud.isAuthenticated) return;
    try {
      final pending = await (_db.select(_db.contacts)
            ..where((c) => c.isSynced.equals(false)))
          .get();
      if (pending.isEmpty) return;

      final toDelete = pending.where((c) => c.deletedAt != null).toList();
      final toUpsert = pending.where((c) => c.deletedAt == null).toList();

      if (toDelete.isNotEmpty) {
        final deleteIds = toDelete.map((c) => c.id).toList();
        await _cloud.softDeleteContactsBatchInCloud(deleteIds);
        await (_db.delete(_db.contacts)..where((tbl) => tbl.id.isIn(deleteIds)))
            .go();
        log('CommsRepository: ⚡ Synced and purged ${deleteIds.length} deleted contacts in cloud.');
      }

      if (toUpsert.isNotEmpty) {
        final upsertPayload = toUpsert.map((c) => {
              'id': c.id,
              'name': c.name,
              'phone_number': c.phoneNumber,
              'relationship': c.relationship,
              'is_emergency': c.isEmergency,
            }).toList();

        await _cloud.syncContactsBatch(upsertPayload);

        final upsertIds = toUpsert.map((c) => c.id).toList();
        await (_db.update(_db.contacts)
              ..where((tbl) => tbl.id.isIn(upsertIds)))
            .write(const ContactsCompanion(isSynced: Value(true)));
        log('CommsRepository: ⚡ Batch synced ${upsertIds.length} active contacts to Supabase.');
      }
    } catch (e, st) {
      log('CommsRepository: Pending batch sync error: $e', stackTrace: st);
    }
  }

  // ===========================================================================
  // 🔗 إدارة الاقتران السيادي المحلي (Sovereign Device Pairing)
  // ===========================================================================

  Future<void> _ensurePairingTable() async {
    try {
      await _db.customStatement(
        'CREATE TABLE IF NOT EXISTS device_pairing_meta (key TEXT PRIMARY KEY, val TEXT);',
      );
    } catch (e) {
      log('CommsRepository: Pairing table creation check: $e');
    }
  }

  @override
  Future<String?> initiateDevicePairing({required String deviceType}) async {
    final rng = math.Random();
    // توليد كود مكوّن من 6 أرقام سهل النطق والفهم للكفيف (بين 100000 و 999999)
    final code = (rng.nextInt(900000) + 100000).toString();

    final success = await _cloud.createPairingSession(
      pairingCode: code,
      targetDeviceType: deviceType,
    );

    return success ? code : null;
  }

  @override
  Stream<String?> listenForDeviceAuthorization(String pairingCode) {
    final stream = _cloud.streamPairingSession(pairingCode);
    if (stream == null) return const Stream.empty();

    return stream.asyncMap((data) async {
      if (data != null && data['status'] == 'paired') {
        final vaultId = data['vault_id'] as String?;
        if (vaultId != null && vaultId.isNotEmpty) {
          await _ensurePairingTable();
          await _db.customStatement(
            'INSERT OR REPLACE INTO device_pairing_meta (key, val) VALUES ("linked_vault_id", "$vaultId");',
          );
          await _cloud.burnPairingSession(pairingCode);
          return vaultId;
        }
      }
      return null;
    });
  }

  @override
  Future<bool> authorizePairingCode(
    String pairingCode, {
    String? customVaultId,
  }) async {
    final cleanCode = pairingCode.replaceAll(RegExp(r'\D'), '').trim();
    if (cleanCode.length != 6) return false;

    // استخدام المعرف المحدد أو المعرف النشط للهاتف
    final masterVaultId = customVaultId ?? _cloud.activeUserId;

    final success = await _cloud.claimPairingSession(
      pairingCode: cleanCode,
      vaultId: masterVaultId,
    );

    if (success) {
      log('CommsRepository: Successfully paired with code $cleanCode for Vault $masterVaultId');
    }
    return success;
  }

  @override
  Future<bool> isDeviceLinked() async {
    await _ensurePairingTable();
    final rows = await _db.customSelect(
      'SELECT val FROM device_pairing_meta WHERE key = "linked_vault_id" LIMIT 1;',
    ).get();
    return rows.isNotEmpty && (rows.first.read<String>('val')).isNotEmpty;
  }

  @override
  Future<String?> getLinkedVaultId() async {
    await _ensurePairingTable();
    final rows = await _db.customSelect(
      'SELECT val FROM device_pairing_meta WHERE key = "linked_vault_id" LIMIT 1;',
    ).get();
    return rows.isNotEmpty ? rows.first.read<String>('val') : null;
  }

  @override
  Future<void> unpairDevice() async {
    await _ensurePairingTable();
    await _db.customStatement(
      'DELETE FROM device_pairing_meta WHERE key = "linked_vault_id";',
    );
    log('CommsRepository: Device unpaired successfully.');
  }
}