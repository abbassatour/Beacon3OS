// packages/launcher_repository/lib/src/domains/comms_repository.dart
import 'dart:async';
import 'dart:developer';
import 'dart:math' as math;

import 'package:cloud_sync_api/cloud_sync_api.dart';
import 'package:drift/drift.dart';
import 'package:launcher_repository/src/domains/services/contacts_reconciliation_service.dart';
import 'package:launcher_repository/src/mappers/comms_mapper.dart';
import 'package:launcher_repository/src/models/contact_entity.dart';
import 'package:launcher_repository/src/models/message_entity.dart';
import 'package:launcher_repository/src/models/remote_action_event.dart';
import 'package:local_vault_api/local_vault_api.dart' as db;
import 'package:system_hardware_api/system_hardware_api.dart';
import 'package:uuid/uuid.dart';

export 'package:cloud_sync_api/cloud_sync_api.dart' show SyncTransportMode;
export 'package:launcher_repository/src/models/contact_entity.dart';
export 'package:launcher_repository/src/models/message_entity.dart';
export 'package:launcher_repository/src/models/remote_action_event.dart';

abstract class CommsRepository {
  Stream<List<ContactEntity>> watchContacts();
  Future<List<ContactEntity>> getEmergencyContacts();
  Future<ContactEntity?> findContact(String query);
  Future<String> saveContact({
    required String name,
    required String phoneNumber,
    String? relationship,
    bool isEmergency = false,
  });
  Future<void> deleteContact(dynamic contactOrId);

  /// تبديل حالة الطوارئ لجهة الاتصال بأمان دون حذف السجل وإعادة إنشائه
  Future<void> toggleEmergencyStatus(String contactId, {bool? isEmergency});

  /// مزامنة جهات اتصال الهاتف وتسويتها داخل الخزنة المحلية عبر خوارزمية تفاضلية غير تدميرية
  Future<
      ({
        int addedCount,
        int updatedCount,
        int deletedCount,
        bool permissionDenied,
      })> syncDeviceContactsToVault();

  Stream<List<MessageEntity>> watchMessages(String contactIdentifier);
  Future<List<MessageEntity>> getUnreadMessages();
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

  /// 🛰️ تدفق الأحداث السحابية والمحلية الموحدة (Locate, SOS, Mutations)
  Stream<RemoteActionEvent> get remoteActionEvents;

  /// 🚨 تنفيذ بروتوكول وميض الكشاف والاهتزاز لتحديد موقع الهاتف
  Future<void> executeLocateDevice({int pulseCycles = 8});

  /// 🔍 تسجيل معالج إضافي (صوتي/اهتزازي) عند تحديد موقع الهاتف
  void registerLocateHandler(Future<void> Function() handler);
  void unregisterLocateHandler();

  /// 🔍 إرسال طلب تحديد موقع الهاتف من شاشة التلفزيون أو الكمبيوتر (Local-First)
  Future<bool> requestLocatePhone({String reason = 'Living room request'});

  /// 🧭 تدفق نمط الاتصال النشط (LAN Direct vs Cloud Relay vs Standalone)
  Stream<SyncTransportMode> get transportModeStream;
  SyncTransportMode get currentTransportMode;

  /// تهيئة المحرك الهجين للجهاز النشط
  Future<void> initializeHybridTransport({
    required String deviceType,
    String? nodeId,
  });

  Future<void> restoreCommsFromCloud();
  Future<void> syncPendingComms();

  /// 🛰️ بدء الاستماع اللحظي للسحابة وتحديث الخزنة فوراً
  void initializeRealtimeSync();

  /// 🛑 إيقاف الاشتراكات اللحظية بأمان
  void dispose();

  // ===========================================================================
  // 🔗 بروتوكول الاقتران السيادي بدون حسابات (Zero-Login Device Pairing)
  // ===========================================================================

  Future<String?> initiateDevicePairing({required String deviceType});
  Stream<String?> listenForDeviceAuthorization(String pairingCode);
  Future<bool> authorizePairingCode(String pairingCode, {String? customVaultId});
  Future<bool> isDeviceLinked();
  Future<String?> getLinkedVaultId();
  Future<void> unpairDevice();
}

class CommsRepositoryImpl implements CommsRepository {
  CommsRepositoryImpl({
    required db.AppDatabase database,
    required CloudSyncClient cloudSync,
    required HardwareClient hardware,
    HybridSyncClient? hybridSync,
    ContactsReconciliationService? reconciliationService,
  })  : _db = database,
        _cloud = cloudSync,
        _hardware = hardware,
        _hybridSync =
            hybridSync ?? HybridSyncClient(cloudSyncClient: cloudSync),
        _reconciliationService =
            reconciliationService ?? ContactsReconciliationService();

  final db.AppDatabase _db;
  final CloudSyncClient _cloud;
  final HardwareClient _hardware;
  final HybridSyncClient _hybridSync;
  final ContactsReconciliationService _reconciliationService;
  final _uuid = const Uuid();

  StreamSubscription<dynamic>? _authSubscription;
  StreamSubscription<List<Map<String, dynamic>>>?
      _realtimeContactsSubscription;
  StreamSubscription<List<Map<String, dynamic>>>?
      _remoteActionsSubscription;
  StreamSubscription<P2pMessage>? _hybridEventsSubscription;

  final StreamController<RemoteActionEvent> _remoteActionController =
      StreamController<RemoteActionEvent>.broadcast();

  Future<void> Function()? _locateHandler;
  bool _isLocating = false;

  @override
  Stream<RemoteActionEvent> get remoteActionEvents =>
      _remoteActionController.stream;

  @override
  Stream<SyncTransportMode> get transportModeStream =>
      _hybridSync.transportModeStream;

  @override
  SyncTransportMode get currentTransportMode => _hybridSync.currentMode;

  @override
  void registerLocateHandler(Future<void> Function() handler) {
    _locateHandler = handler;
  }

  @override
  void unregisterLocateHandler() {
    _locateHandler = null;
  }

  @override
  Future<void> initializeHybridTransport({
    required String deviceType,
    String? nodeId,
  }) async {
    final vaultId = await getLinkedVaultId();
    await _hybridSync.initialize(
      deviceType: deviceType,
      nodeId: nodeId ?? 'beacon_${deviceType}_${_uuid.v4().substring(0, 6)}',
      linkedVaultId: vaultId,
    );

    _hybridEventsSubscription?.cancel();
    _hybridEventsSubscription = _hybridSync.unifiedEvents.listen(
      _handleUnifiedIncomingMessage,
      onError: (Object err) =>
          log('CommsRepository: Unified events error: $err'),
    );
  }

  void _handleUnifiedIncomingMessage(P2pMessage message) {
    final event = RemoteActionEvent.fromP2pMessage(message);

    // ⚡ معالجة تحديثات الخزنة المحلية عبر المقابس
    if (message.type == P2pMessageType.vaultMutation) {
      final table = message.payload['table'] as String?;
      if (table == 'contacts') {
        _handleInboundContactMutation(message.payload);
      }
    }

    if (event.actionType == RemoteActionType.unknown) return;

    log('CommsRepository: ⚡ Action Received via [${message.senderType ?? "Hybrid"}] -> ${event.actionType}');
    _remoteActionController.add(event);

    if (event.actionType == RemoteActionType.locateDevice) {
      executeLocateDevice();
    }
  }

  Future<void> _handleInboundContactMutation(
      Map<String, dynamic> payload) async {
    try {
      final action = payload['action'] as String?;
      final data = payload['data'] is Map<String, dynamic>
          ? payload['data'] as Map<String, dynamic>
          : <String, dynamic>{};

      if (action == 'INSERT' || action == 'UPDATE') {
        final id = data['id'] as String?;
        final name = data['name'] as String?;
        final phone = data['phone_number'] as String?;
        if (id != null && name != null && phone != null) {
          await _db.into(_db.contacts).insert(
                db.ContactsCompanion.insert(
                  id: id,
                  name: name,
                  phoneNumber: phone,
                  relationship: Value(data['relationship'] as String?),
                  isEmergency: Value(data['is_emergency'] as bool? ?? false),
                  isSynced: const Value(true),
                ),
                mode: InsertMode.insertOrReplace,
              );
        }
      } else if (action == 'DELETE') {
        final id = data['id'] as String?;
        if (id != null) {
          await (_db.delete(_db.contacts)..where((tbl) => tbl.id.equals(id)))
              .go();
        }
      }
    } catch (e) {
      log('CommsRepository: Inbound contact mutation note: $e');
    }
  }

  @override
  void initializeRealtimeSync() {
    _authSubscription?.cancel();
    _authSubscription = _cloud.authStateChanges?.listen((authState) {
      if (_cloud.isAuthenticated) {
        _subscribeToRealtimeContacts();
      } else {
        _realtimeContactsSubscription?.cancel();
        _realtimeContactsSubscription = null;
      }
    });

    _subscribeToRemoteActions();

    if (_cloud.isAuthenticated) {
      _subscribeToRealtimeContacts();
    }
  }

  void _subscribeToRealtimeContacts() {
    _realtimeContactsSubscription?.cancel();
    try {
      final stream = _cloud.streamContacts();
      if (stream != null) {
        _realtimeContactsSubscription = stream.listen(
          _handleCloudRealtimeContacts,
          onError: (Object error) {
            log('CommsRepository: Realtime contacts stream error (offline handled): $error');
          },
          cancelOnError: false,
        );
        log('CommsRepository: 🛰️ Subscribed to Supabase Realtime contacts stream.');
      }
    } catch (e) {
      log('CommsRepository: Safe catch on streamContacts init: $e');
    }
  }

  void _subscribeToRemoteActions() {
    _remoteActionsSubscription?.cancel();
    try {
      final stream = _cloud.streamRemoteActions();
      if (stream != null) {
        _remoteActionsSubscription = stream.listen(
          _handleIncomingRemoteActions,
          onError: (Object error) {
            log('CommsRepository: Remote actions stream error (offline handled): $error');
          },
          cancelOnError: false,
        );
        log('CommsRepository: 🛰️ Listening for remote actions (Alexa / Displays)...');
      }
    } catch (e) {
      log('CommsRepository: Safe catch on streamRemoteActions init: $e');
    }
  }

  Future<void> _handleIncomingRemoteActions(
    List<Map<String, dynamic>> rawActions,
  ) async {
    for (final raw in rawActions) {
      final event = RemoteActionEvent.fromMap(raw);
      if (event.id.isEmpty || event.actionType == RemoteActionType.unknown) {
        continue;
      }

      await _cloud.acknowledgeRemoteAction(event.id, status: 'acknowledged');
      _remoteActionController.add(event);

      if (event.actionType == RemoteActionType.locateDevice) {
        await executeLocateDevice();
      } else if (event.actionType == RemoteActionType.triggerSos) {
        await triggerEmergencySos();
      }

      await _cloud.acknowledgeRemoteAction(event.id, status: 'completed');
    }
  }

  @override
  Future<void> executeLocateDevice({int pulseCycles = 8}) async {
    if (_isLocating) return;
    _isLocating = true;

    log('CommsRepository: 📢 Locating Device: Triggering audio siren, haptics & flashlight strobe...');

    if (_locateHandler != null) {
      unawaited(_locateHandler!().catchError((Object err) {
        log('CommsRepository: Custom locate handler note: $err');
      }));
    }

    try {
      for (var i = 0; i < pulseCycles; i++) {
        await _hardware.toggleFlashlight(enable: true);
        await Future<void>.delayed(const Duration(milliseconds: 180));
        await _hardware.toggleFlashlight(enable: false);
        await Future<void>.delayed(const Duration(milliseconds: 180));
      }
    } catch (e) {
      log('CommsRepository: Hardware locator strobe error: $e');
    } finally {
      await _hardware.toggleFlashlight(enable: false).catchError((_) => false);
      _isLocating = false;
    }
  }

  @override
  Future<bool> requestLocatePhone({String reason = 'Living room request'}) async {
    return _hybridSync.dispatchLocatePhone(reason: reason);
  }

  Future<void> _handleCloudRealtimeContacts(
    List<Map<String, dynamic>> cloudContacts,
  ) async {
    try {
      if (cloudContacts.isEmpty) return;

      final localContacts = await (_db.select(_db.contacts)).get();
      final Map<String, db.Contact> localMap = {
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
              batch.delete(_db.contacts, db.ContactsCompanion(id: Value(id)));
            }
          } else {
            final name = (cloudItem['name'] as String? ?? '').trim();
            final phone = (cloudItem['phone_number'] as String? ?? '').trim();
            if (name.isEmpty || phone.isEmpty) continue;

            final relationship = cloudItem['relationship'] as String?;
            final isEmergency = cloudItem['is_emergency'] as bool? ?? false;

            batch.insert(
              _db.contacts,
              db.ContactsCompanion.insert(
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
    _hybridEventsSubscription?.cancel();
    _hybridSync.dispose();
    _remoteActionController.close();
  }

  // ===========================================================================
  // 📇 جهات الاتصال
  // ===========================================================================

  @override
  Stream<List<ContactEntity>> watchContacts() {
    return _db.watchAllContacts().map(
          (list) => list.map((c) => c.toEntity()).toList(),
        );
  }

  @override
  Future<List<ContactEntity>> getEmergencyContacts() async {
    final list = await _db.getEmergencyContacts();
    return list.map((c) => c.toEntity()).toList();
  }

  @override
  Future<ContactEntity?> findContact(String query) async {
    final contact = await _db.findContactByNameOrRelation(query);
    return contact?.toEntity();
  }

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

    _hybridSync.broadcastVaultMutation(
      table: 'contacts',
      action: 'INSERT',
      data: {
        'id': id,
        'name': name,
        'phone_number': phoneNumber,
        'relationship': relationship,
        'is_emergency': isEmergency,
      },
    );

    return id;
  }

  @override
  Future<void> toggleEmergencyStatus(String contactId, {bool? isEmergency}) async {
    final contacts = await _db.getAllContacts();
    final existing = contacts.where((c) => c.id == contactId).firstOrNull;
    if (existing == null) return;

    final nextStatus = isEmergency ?? !existing.isEmergency;

    await (_db.update(_db.contacts)..where((tbl) => tbl.id.equals(contactId))).write(
      db.ContactsCompanion(
        isEmergency: Value(nextStatus),
        updatedAt: Value(DateTime.now()),
        isSynced: const Value(false),
      ),
    );

    _cloud.syncContact(
      id: existing.id,
      name: existing.name,
      phoneNumber: existing.phoneNumber,
      relationship: existing.relationship,
      isEmergency: nextStatus,
    ).catchError((Object err) {
      log('CommsRepository: Cloud emergency toggle deferred: $err');
    });

    _hybridSync.broadcastVaultMutation(
      table: 'contacts',
      action: 'UPDATE',
      data: {
        'id': existing.id,
        'name': existing.name,
        'phone_number': existing.phoneNumber,
        'relationship': existing.relationship,
        'is_emergency': nextStatus,
      },
    );
  }

  @override
  Future<void> deleteContact(dynamic contactOrId) async {
    final String id =
        contactOrId is ContactEntity ? contactOrId.id : contactOrId.toString();
    await _db.softDeleteContact(id);

    _cloud.softDeleteContactInCloud(id).catchError((Object error) {
      log('CommsRepository: Cloud contact delete deferred: $error');
    });

    _hybridSync.broadcastVaultMutation(
      table: 'contacts',
      action: 'DELETE',
      data: {'id': id},
    );
  }

  @override
  Future<
      ({
        int addedCount,
        int updatedCount,
        int deletedCount,
        bool permissionDenied,
      })> syncDeviceContactsToVault() async {
    // 1. فحص إذن الوصول لسجل الهاتف مع دعم Limited Access
    final hasPerm = await _hardware.hasContactsPermission();
    if (!hasPerm) {
      log('CommsRepository: Cannot sync contacts. Permission not granted.');
      return (
        addedCount: 0,
        updatedCount: 0,
        deletedCount: 0,
        permissionDenied: true,
      );
    }

    // 2. قراءة جهات الاتصال وتسويتها
    final deviceRecords = await _hardware.getDeviceContacts();
    final result = await _reconciliationService.reconcile(
      deviceRecords: deviceRecords,
      database: _db,
    );

    // 3. بث التحديث محلياً عبر P2P للأجهزة المقترنة (TV / Desktop)
    if (result.addedCount > 0 || result.updatedCount > 0) {
      _hybridSync.broadcastVaultMutation(
        table: 'contacts',
        action: 'RECONCILE',
        data: {
          'added': result.addedCount,
          'updated': result.updatedCount,
        },
      );
    }

    // 4. مزامنة التغييرات المعلقة مع السحابة
    syncPendingComms().catchError((Object err) {
      log('CommsRepository: Cloud sync deferred after diffing: $err');
    });

    return (
      addedCount: result.addedCount,
      updatedCount: result.updatedCount,
      deletedCount: result.deletedCount,
      permissionDenied: false,
    );
  }

  // ===========================================================================
  // 💬 الرسائل
  // ===========================================================================

  @override
  Stream<List<MessageEntity>> watchMessages(String contactIdentifier) {
    return _db.watchMessagesForContact(contactIdentifier).map(
          (list) => list.map((m) => m.toEntity()).toList(),
        );
  }

  @override
  Future<List<MessageEntity>> getUnreadMessages() async {
    final list = await _db.getUnreadMessages();
    return list.map((m) => m.toEntity()).toList();
  }

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

  // ===========================================================================
  // 🚨 استغاثة الطوارئ SOS
  // ===========================================================================

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

    await _hybridSync.dispatchEmergencySos(
      latitude: effectiveLat,
      longitude: effectiveLng,
      batteryLevel: actualBattery,
    );

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
            db.ContactsCompanion.insert(
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
        await (_db.delete(_db.contacts)..where((tbl) => tbl.id.isIn(deleteIds))).go();
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
            .write(const db.ContactsCompanion(isSynced: Value(true)));
      }
    } catch (e, st) {
      log('CommsRepository: Pending batch sync error: $e', stackTrace: st);
    }
  }

  // ===========================================================================
  // 🔗 بروتوكول الاقتران السيادي الصامت (Offline-First Device Pairing)
  // ===========================================================================

  @override
  Future<String?> initiateDevicePairing({required String deviceType}) async {
    final rng = math.Random();
    final code = (rng.nextInt(900000) + 100000).toString();

    try {
      await _cloud.createPairingSession(
        pairingCode: code,
        targetDeviceType: deviceType,
      );
      log('CommsRepository: Pairing code registered with cloud: $code');
    } catch (e) {
      log('CommsRepository: Cloud pairing registration deferred (offline-first): $e');
    }

    return code;
  }

  @override
  Stream<String?> listenForDeviceAuthorization(String pairingCode) {
    try {
      final stream = _cloud.streamPairingSession(pairingCode);
      if (stream == null) return const Stream.empty();

      return stream
          .handleError((Object error) {
            log('CommsRepository: Safe catch on pairing stream error: $error');
          })
          .asyncMap((data) async {
            if (data != null && data['status'] == 'paired') {
              final vaultId = data['vault_id'] as String?;
              if (vaultId != null && vaultId.isNotEmpty) {
                await _db.setDevicePairingMeta('linked_vault_id', vaultId);
                try {
                  await _cloud.burnPairingSession(pairingCode);
                } catch (_) {}

                await initializeHybridTransport(
                  deviceType: 'fire_tv',
                  nodeId: 'node_$vaultId',
                );

                return vaultId;
              }
            }
            return null;
          })
          .handleError((Object error) {
            log('CommsRepository: Pairing auth stream error handled: $error');
          });
    } catch (e) {
      log('CommsRepository: Unable to listen for device authorization: $e');
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
        log('CommsRepository: Successfully paired with code $cleanCode for Vault $masterVaultId');
      }
      return success;
    } catch (e) {
      log('CommsRepository: Cloud pairing authorization failed: $e');
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
    log('CommsRepository: Device unpaired successfully.');
  }
}

extension on db.AppDatabase {
  Future<List<db.Contact>> getAllContacts() {
    return (select(contacts)..where((c) => c.deletedAt.isNull())).get();
  }
}