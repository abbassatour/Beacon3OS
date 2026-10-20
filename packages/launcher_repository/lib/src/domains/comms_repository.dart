// packages/launcher_repository/lib/src/domains/comms_repository.dart
import 'dart:async';
import 'dart:developer';
import 'dart:math' as math;

import 'package:cloud_sync_api/cloud_sync_api.dart';
import 'package:drift/drift.dart';
import 'package:equatable/equatable.dart';
import 'package:launcher_repository/src/domains/services/contacts_reconciliation_service.dart';
import 'package:launcher_repository/src/mappers/comms_mapper.dart';
import 'package:launcher_repository/src/models/contact_entity.dart';
import 'package:launcher_repository/src/models/message_entity.dart';
import 'package:launcher_repository/src/models/remote_action_event.dart';
import 'package:local_vault_api/local_vault_api.dart' as db;
import 'package:system_hardware_api/system_hardware_api.dart';
import 'package:uuid/uuid.dart';

export 'package:cloud_sync_api/cloud_sync_api.dart'
    show LocalNodeInfo, SyncTransportMode;
export 'package:launcher_repository/src/models/contact_entity.dart';
export 'package:launcher_repository/src/models/message_entity.dart';
export 'package:launcher_repository/src/models/remote_action_event.dart';

/// كائن يمثل سجل استغاثة طوارئ موثق في الخزنة وعلى البلوكتشين
class SosAlertRecord extends Equatable {
  const SosAlertRecord({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.batteryLevel,
    required this.status,
    required this.googleMapsUrl,
    required this.triggeredAt,
  });

  final String id;
  final double latitude;
  final double longitude;
  final int batteryLevel;
  final String status;
  final String googleMapsUrl;
  final DateTime triggeredAt;

  @override
  List<Object?> get props => [
        id,
        latitude,
        longitude,
        batteryLevel,
        status,
        googleMapsUrl,
        triggeredAt,
      ];
}

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

  /// 📜 مراقبة سجل استغاثات الطوارئ SOS التاريخية
  Stream<List<SosAlertRecord>> watchSosHistory();

  /// 🛰️ تدفق الأحداث السحابية والمحلية الموحدة (Locate, SOS, Mutations)
  Stream<RemoteActionEvent> get remoteActionEvents;

  /// 📡 تدفق وقائمة الأجهزة النشطة المكتشفة في شبكة الـ Mesh المحلية
  Stream<List<LocalNodeInfo>> get activeMeshNodesStream;
  List<LocalNodeInfo> get activeMeshNodes;

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

  Future<String?> initiateDevicePairing({
    required String deviceType,
    String? previousCode,
  });
  Stream<String?> listenForDeviceAuthorization(
    String pairingCode, {
    String deviceType = 'fire_tv',
  });
  Future<bool> authorizePairingCode(String pairingCode, {String? customVaultId});
  Future<bool> isDeviceLinked();
  Future<String?> getLinkedVaultId();
  Future<void> unpairDevice();

  /// ⚡ طلب لقطة الخزنة المباشرة من الهاتف عبر شبكة LAN
  Future<void> requestVaultSnapshot();

  /// ⚡ إرسال لقطة الخزنة المحلية لجميع الأجهزة المقترنة بالشبكة
  Future<void> sendVaultSnapshotToPeers();

  /// 🔄 طلب التغييرات التفاضلية فقط بعد تاريخ محدد عبر LAN
  Future<void> requestVaultDelta({DateTime? since});

  /// 🔄 إرسال التغييرات التفاضلية لجميع الأجهزة المقترنة عبر LAN
  Future<void> sendVaultDeltaToPeers({DateTime? since});
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
  Stream<List<LocalNodeInfo>> get activeMeshNodesStream =>
      _hybridSync.activePeersStream;

  @override
  List<LocalNodeInfo> get activeMeshNodes => _hybridSync.activePeers;

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
    // 1. معالجة طلب لقطة الخزنة الوارد
    if (message.type == P2pMessageType.vaultSyncRequest) {
      log('CommsRepository: 📥 Peer requested vault snapshot via LAN. Responding...');
      unawaited(sendVaultSnapshotToPeers());
      return;
    }

    // 2. معالجة لقطة الخزنة الواردة
    if (message.type == P2pMessageType.vaultSyncResponse) {
      log('CommsRepository: 📥 Received inbound vault snapshot via LAN. Hydrating database...');
      unawaited(_handleInboundVaultSnapshot(message.payload));
      return;
    }

    // 3. معالجة طلب التغييرات التفاضلية (Delta Sync Request)
    if (message.type == P2pMessageType.vaultDeltaRequest) {
      final sinceStr = message.payload['since_utc'] as String?;
      final sinceUtc = sinceStr != null ? DateTime.tryParse(sinceStr) : null;
      log('CommsRepository: 📥 Peer requested vault delta via LAN (Since: $sinceUtc). Responding...');
      unawaited(sendVaultDeltaToPeers(since: sinceUtc));
      return;
    }

    // 4. معالجة التغييرات التفاضلية الواردة وتطبيقها محلياً
    if (message.type == P2pMessageType.vaultDeltaResponse) {
      log('CommsRepository: 📥 Received inbound vault delta via LAN. Applying changes...');
      unawaited(_handleInboundVaultDelta(message.payload));
      return;
    }

    final event = RemoteActionEvent.fromP2pMessage(message);

    // 5. معالجة التعديلات الفردية عبر المقابس
    if (message.type == P2pMessageType.vaultMutation) {
      final table = message.payload['table'] as String?;
      if (table == 'contacts') {
        _handleInboundContactMutation(message.payload);
      } else if (table == 'tasks') {
        _handleInboundTaskMutation(message.payload);
      } else if (table == 'alarms') {
        _handleInboundAlarmMutation(message.payload);
      } else if (table == 'memos' || table == 'voice_memos') {
        _handleInboundMemoMutation(message.payload);
      } else if (table == 'spatial_nodes') {
        _handleInboundSpatialNodeMutation(message.payload);
      } else if (table == 'settings' || table == 'app_settings') {
        _handleInboundSettingsMutation(message.payload);
      }
    }

    if (event.actionType == RemoteActionType.unknown) return;

    log('CommsRepository: ⚡ Action Received via [${message.senderType ?? "Hybrid"}] -> ${event.actionType}');
    _remoteActionController.add(event);

    if (event.actionType == RemoteActionType.locateDevice) {
      executeLocateDevice();
    }
  }

  Future<void> _handleInboundVaultSnapshot(Map<String, dynamic> payload) async {
    await _handleInboundVaultDelta(payload);
  }

  Future<void> _handleInboundVaultDelta(Map<String, dynamic> payload) async {
    try {
      final rawTasks = payload['tasks'] as List<dynamic>? ?? [];
      final rawAlarms = payload['alarms'] as List<dynamic>? ?? [];
      final rawContacts = payload['contacts'] as List<dynamic>? ?? [];
      final rawMemos = payload['memos'] as List<dynamic>? ?? [];
      final rawNodes = payload['spatial_nodes'] as List<dynamic>? ?? [];
      final rawSettings = payload['settings'] as List<dynamic>? ?? [];

      final localTasks = await _db.select(_db.tasks).get();
      final localAlarms = await _db.select(_db.alarms).get();
      final localContacts = await _db.select(_db.contacts).get();
      final localMemos = await _db.select(_db.voiceMemos).get();
      final localNodes = await _db.select(_db.spatialNodes).get();
      final localSettings = await _db.getSettings();

      final tasksMap = {for (final t in localTasks) t.id: t};
      final alarmsMap = {for (final a in localAlarms) a.id: a};
      final contactsMap = {for (final c in localContacts) c.id: c};
      final memosMap = {for (final m in localMemos) m.id: m};
      final nodesMap = {for (final n in localNodes) n.id: n};

      await _db.batch((batch) {
        // --- 1. المهام (Tasks) ---
        for (final item in rawTasks) {
          if (item is Map<String, dynamic>) {
            final id = item['id'] as String?;
            if (id == null) continue;

            final inboundUpdated = item['updated_at'] != null
                ? DateTime.tryParse(item['updated_at'].toString())
                : null;
            final inboundDeleted = item['deleted_at'] != null
                ? DateTime.tryParse(item['deleted_at'].toString())
                : null;

            final local = tasksMap[id];
            final shouldApply = local == null ||
                (inboundUpdated != null && inboundUpdated.isAfter(local.updatedAt)) ||
                (local.isSynced);

            if (shouldApply) {
              if (inboundDeleted != null) {
                batch.delete(_db.tasks, db.TasksCompanion(id: Value(id)));
              } else {
                final title = item['title'] as String? ?? 'Untitled Task';
                DateTime? due;
                if (item['due_date'] != null) {
                  due = DateTime.tryParse(item['due_date'].toString());
                }

                batch.insert(
                  _db.tasks,
                  db.TasksCompanion.insert(
                    id: id,
                    title: title,
                    dueDate: Value(due?.toUtc()),
                    priority: Value(item['priority'] as String? ?? 'medium'),
                    isCompleted: Value(item['is_completed'] as bool? ?? false),
                    updatedAt: Value(inboundUpdated ?? DateTime.now().toUtc()),
                    isSynced: const Value(true),
                  ),
                  mode: InsertMode.insertOrReplace,
                );
              }
            }
          }
        }

        // --- 2. المنبهات (Alarms) ---
        for (final item in rawAlarms) {
          if (item is Map<String, dynamic>) {
            final id = item['id'] as String?;
            if (id == null) continue;

            final inboundUpdated = item['updated_at'] != null
                ? DateTime.tryParse(item['updated_at'].toString())
                : null;
            final inboundDeleted = item['deleted_at'] != null
                ? DateTime.tryParse(item['deleted_at'].toString())
                : null;

            final local = alarmsMap[id];
            final shouldApply = local == null ||
                (inboundUpdated != null && inboundUpdated.isAfter(local.updatedAt)) ||
                (local.isSynced);

            if (shouldApply) {
              if (inboundDeleted != null) {
                batch.delete(_db.alarms, db.AlarmsCompanion(id: Value(id)));
              } else {
                final hour = (item['hour'] as num?)?.toInt() ?? 8;
                final minute = (item['minute'] as num?)?.toInt() ?? 0;

                batch.insert(
                  _db.alarms,
                  db.AlarmsCompanion.insert(
                    id: id,
                    hour: hour,
                    minute: minute,
                    label: Value(item['label'] as String? ?? 'Beacon Alarm'),
                    daysOfWeek: Value(item['days_of_week'] as String? ?? 'daily'),
                    isActive: Value(item['is_active'] as bool? ?? true),
                    updatedAt: Value(inboundUpdated ?? DateTime.now().toUtc()),
                    isSynced: const Value(true),
                  ),
                  mode: InsertMode.insertOrReplace,
                );
              }
            }
          }
        }

        // --- 3. جهات الاتصال (Contacts) ---
        for (final item in rawContacts) {
          if (item is Map<String, dynamic>) {
            final id = item['id'] as String?;
            if (id == null) continue;

            final inboundUpdated = item['updated_at'] != null
                ? DateTime.tryParse(item['updated_at'].toString())
                : null;
            final inboundDeleted = item['deleted_at'] != null
                ? DateTime.tryParse(item['deleted_at'].toString())
                : null;

            final local = contactsMap[id];
            final shouldApply = local == null ||
                (inboundUpdated != null && inboundUpdated.isAfter(local.updatedAt)) ||
                (local.isSynced);

            if (shouldApply) {
              if (inboundDeleted != null) {
                batch.delete(_db.contacts, db.ContactsCompanion(id: Value(id)));
              } else {
                final name = item['name'] as String?;
                final phone = item['phone_number'] as String?;
                if (name != null && phone != null) {
                  batch.insert(
                    _db.contacts,
                    db.ContactsCompanion.insert(
                      id: id,
                      name: name,
                      phoneNumber: phone,
                      relationship: Value(item['relationship'] as String?),
                      isEmergency: Value(item['is_emergency'] as bool? ?? false),
                      updatedAt: Value(inboundUpdated ?? DateTime.now().toUtc()),
                      isSynced: const Value(true),
                    ),
                    mode: InsertMode.insertOrReplace,
                  );
                }
              }
            }
          }
        }

        // --- 4. المذكرات الصوتية (Voice Memos) ---
        for (final item in rawMemos) {
          if (item is Map<String, dynamic>) {
            final id = item['id'] as String?;
            if (id == null) continue;

            final inboundUpdated = item['updated_at'] != null
                ? DateTime.tryParse(item['updated_at'].toString())
                : null;
            final inboundDeleted = item['deleted_at'] != null
                ? DateTime.tryParse(item['deleted_at'].toString())
                : null;

            final local = memosMap[id];
            final shouldApply = local == null ||
                (inboundUpdated != null && inboundUpdated.isAfter(local.updatedAt)) ||
                (local.isSynced);

            if (shouldApply) {
              if (inboundDeleted != null) {
                batch.delete(_db.voiceMemos, db.VoiceMemosCompanion(id: Value(id)));
              } else {
                batch.insert(
                  _db.voiceMemos,
                  db.VoiceMemosCompanion.insert(
                    id: id,
                    title: item['title'] as String? ?? 'Voice Note',
                    content: item['content'] as String? ?? '',
                    createdAt: Value(DateTime.tryParse(item['created_at']?.toString() ?? '') ?? DateTime.now().toUtc()),
                    updatedAt: Value(inboundUpdated ?? DateTime.now().toUtc()),
                    isSynced: const Value(true),
                  ),
                  mode: InsertMode.insertOrReplace,
                );
              }
            }
          }
        }

        // --- 5. العقد المكانية وتوزيع الغرف (Spatial Nodes) ---
        for (final item in rawNodes) {
          if (item is Map<String, dynamic>) {
            final id = item['id'] as String?;
            if (id == null) continue;

            final inboundUpdated = item['updated_at'] != null
                ? DateTime.tryParse(item['updated_at'].toString())
                : null;
            final inboundDeleted = item['deleted_at'] != null
                ? DateTime.tryParse(item['deleted_at'].toString())
                : null;

            final local = nodesMap[id];
            final shouldApply = local == null ||
                (inboundUpdated != null && inboundUpdated.isAfter(local.updatedAt)) ||
                (local.isSynced);

            if (shouldApply) {
              if (inboundDeleted != null) {
                batch.delete(_db.spatialNodes, db.SpatialNodesCompanion(id: Value(id)));
              } else {
                batch.insert(
                  _db.spatialNodes,
                  db.SpatialNodesCompanion.insert(
                    id: id,
                    moduleId: item['module_id'] as String,
                    floorLevel: Value((item['floor_level'] as num?)?.toInt() ?? 0),
                    x: Value((item['x'] as num?)?.toInt() ?? 0),
                    y: Value((item['y'] as num?)?.toInt() ?? 0),
                    customTitle: Value(item['custom_title'] as String?),
                    configJson: Value(item['config_json'] as String?),
                    isVisible: Value(item['is_visible'] as bool? ?? true),
                    updatedAt: Value(inboundUpdated ?? DateTime.now().toUtc()),
                    isSynced: const Value(true),
                  ),
                  mode: InsertMode.insertOrReplace,
                );
              }
            }
          }
        }

        // --- 6. الإعدادات الشاملة (App Settings) ---
        for (final item in rawSettings) {
          if (item is Map<String, dynamic>) {
            final inboundUpdated = item['updated_at'] != null
                ? DateTime.tryParse(item['updated_at'].toString())
                : null;

            if (inboundUpdated != null && inboundUpdated.isAfter(localSettings.updatedAt)) {
              batch.update(
                _db.appSettings,
                db.AppSettingsCompanion(
                  userPersona: item['user_persona'] != null ? Value(item['user_persona'].toString()) : const Value.absent(),
                  hasCompletedOnboarding: item['has_completed_onboarding'] != null ? Value(item['has_completed_onboarding'] as bool) : const Value.absent(),
                  speechRate: item['speech_rate'] != null ? Value((item['speech_rate'] as num).toDouble()) : const Value.absent(),
                  hapticsEnabled: item['haptics_enabled'] != null ? Value(item['haptics_enabled'] as bool) : const Value.absent(),
                  soundCuesEnabled: item['sound_cues_enabled'] != null ? Value(item['sound_cues_enabled'] as bool) : const Value.absent(),
                  isHighContrast: item['is_high_contrast'] != null ? Value(item['is_high_contrast'] as bool) : const Value.absent(),
                  spatialWhisperEnabled: item['spatial_whisper_enabled'] != null ? Value(item['spatial_whisper_enabled'] as bool) : const Value.absent(),
                  defaultPriority: item['default_priority'] != null ? Value(item['default_priority'].toString()) : const Value.absent(),
                  autoArchiveCompleted: item['auto_archive_completed'] != null ? Value(item['auto_archive_completed'] as bool) : const Value.absent(),
                  speakDueDatesAloud: item['speak_due_dates_aloud'] != null ? Value(item['speak_due_dates_aloud'] as bool) : const Value.absent(),
                  autoDialEmergency: item['auto_dial_emergency'] != null ? Value(item['auto_dial_emergency'] as bool) : const Value.absent(),
                  shareGpsOnSos: item['share_gps_on_sos'] != null ? Value(item['share_gps_on_sos'] as bool) : const Value.absent(),
                  speakIncomingSms: item['speak_incoming_sms'] != null ? Value(item['speak_incoming_sms'] as bool) : const Value.absent(),
                  voiceChimeHalfway: item['voice_chime_halfway'] != null ? Value(item['voice_chime_halfway'] as bool) : const Value.absent(),
                  vibrateOnSessionFinish: item['vibrate_on_session_finish'] != null ? Value(item['vibrate_on_session_finish'] as bool) : const Value.absent(),
                  syncAlarmsWithAndroidClock: item['sync_alarms_with_android_clock'] != null ? Value(item['sync_alarms_with_android_clock'] as bool) : const Value.absent(),
                  visionInspectionDetail: item['vision_inspection_detail'] != null ? Value(item['vision_inspection_detail'].toString()) : const Value.absent(),
                  autoFlashlightInDark: item['auto_flashlight_in_dark'] != null ? Value(item['auto_flashlight_in_dark'] as bool) : const Value.absent(),
                  preferredCurrency: item['preferred_currency'] != null ? Value(item['preferred_currency'].toString()) : const Value.absent(),
                  updatedAt: Value(inboundUpdated),
                  isSynced: const Value(true),
                ),
                where: (tbl) => tbl.id.equals(localSettings.id),
              );
            }
          }
        }
      });

      log('CommsRepository: ⚡ Full-Vault Delta applied with LWW resolution across all tables.');
    } catch (e, st) {
      log('CommsRepository: Error applying inbound full-vault delta: $e', stackTrace: st);
    }
  }

  @override
  Future<void> sendVaultSnapshotToPeers() async {
    await sendVaultDeltaToPeers(since: null);
  }

  @override
  Future<void> sendVaultDeltaToPeers({DateTime? since}) async {
    try {
      var tasksQuery = _db.select(_db.tasks);
      var alarmsQuery = _db.select(_db.alarms);
      var contactsQuery = _db.select(_db.contacts);
      var memosQuery = _db.select(_db.voiceMemos);
      var nodesQuery = _db.select(_db.spatialNodes);
      var settingsQuery = _db.select(_db.appSettings);

      if (since != null) {
        final sinceUtc = since.toUtc();
        tasksQuery = tasksQuery..where((t) => t.updatedAt.isBiggerOrEqualValue(sinceUtc));
        alarmsQuery = alarmsQuery..where((a) => a.updatedAt.isBiggerOrEqualValue(sinceUtc));
        contactsQuery = contactsQuery..where((c) => c.updatedAt.isBiggerOrEqualValue(sinceUtc));
        memosQuery = memosQuery..where((m) => m.updatedAt.isBiggerOrEqualValue(sinceUtc));
        nodesQuery = nodesQuery..where((n) => n.updatedAt.isBiggerOrEqualValue(sinceUtc));
        settingsQuery = settingsQuery..where((s) => s.updatedAt.isBiggerOrEqualValue(sinceUtc));
      }

      final tasks = await tasksQuery.get();
      final alarms = await alarmsQuery.get();
      final contacts = await contactsQuery.get();
      final memos = await memosQuery.get();
      final nodes = await nodesQuery.get();
      final settings = await settingsQuery.get();

      final deltaPayload = {
        'tasks': tasks.map((t) => {
          'id': t.id,
          'title': t.title,
          'due_date': t.dueDate?.toIso8601String(),
          'priority': t.priority,
          'is_completed': t.isCompleted,
          'updated_at': t.updatedAt.toUtc().toIso8601String(),
          'deleted_at': t.deletedAt?.toUtc().toIso8601String(),
        }).toList(),
        'alarms': alarms.map((a) => {
          'id': a.id,
          'hour': a.hour,
          'minute': a.minute,
          'label': a.label,
          'days_of_week': a.daysOfWeek,
          'is_active': a.isActive,
          'updated_at': a.updatedAt.toUtc().toIso8601String(),
          'deleted_at': a.deletedAt?.toUtc().toIso8601String(),
        }).toList(),
        'contacts': contacts.map((c) => {
          'id': c.id,
          'name': c.name,
          'phone_number': c.phoneNumber,
          'relationship': c.relationship,
          'is_emergency': c.isEmergency,
          'updated_at': c.updatedAt.toUtc().toIso8601String(),
          'deleted_at': c.deletedAt?.toUtc().toIso8601String(),
        }).toList(),
        'memos': memos.map((m) => {
          'id': m.id,
          'title': m.title,
          'content': m.content,
          'created_at': m.createdAt.toUtc().toIso8601String(),
          'updated_at': m.updatedAt.toUtc().toIso8601String(),
          'deleted_at': m.deletedAt?.toUtc().toIso8601String(),
        }).toList(),
        'spatial_nodes': nodes.map((n) => {
          'id': n.id,
          'module_id': n.moduleId,
          'floor_level': n.floorLevel,
          'x': n.x,
          'y': n.y,
          'custom_title': n.customTitle,
          'config_json': n.configJson,
          'is_visible': n.isVisible,
          'updated_at': n.updatedAt.toUtc().toIso8601String(),
          'deleted_at': n.deletedAt?.toUtc().toIso8601String(),
        }).toList(),
        'settings': settings.map((s) => {
          'id': s.id,
          'user_persona': s.userPersona,
          'has_completed_onboarding': s.hasCompletedOnboarding,
          'speech_rate': s.speechRate,
          'haptics_enabled': s.hapticsEnabled,
          'sound_cues_enabled': s.soundCuesEnabled,
          'is_high_contrast': s.isHighContrast,
          'spatial_whisper_enabled': s.spatialWhisperEnabled,
          'default_priority': s.defaultPriority,
          'auto_archive_completed': s.autoArchiveCompleted,
          'speak_due_dates_aloud': s.speakDueDatesAloud,
          'auto_dial_emergency': s.autoDialEmergency,
          'share_gps_on_sos': s.shareGpsOnSos,
          'speak_incoming_sms': s.speakIncomingSms,
          'voice_chime_halfway': s.voiceChimeHalfway,
          'vibrate_on_session_finish': s.vibrateOnSessionFinish,
          'sync_alarms_with_android_clock': s.syncAlarmsWithAndroidClock,
          'vision_inspection_detail': s.visionInspectionDetail,
          'auto_flashlight_in_dark': s.autoFlashlightInDark,
          'preferred_currency': s.preferredCurrency,
          'updated_at': s.updatedAt.toUtc().toIso8601String(),
        }).toList(),
      };

      _hybridSync.sendVaultDelta(deltaPayload);
      log('CommsRepository: 📤 Complete Full-Vault Delta dispatched to LAN peers (${tasks.length} tasks, ${alarms.length} alarms, ${contacts.length} contacts, ${memos.length} memos, ${nodes.length} nodes).');
    } catch (e, st) {
      log('CommsRepository: Error sending full vault delta: $e', stackTrace: st);
    }
  }

  @override
  Future<void> requestVaultSnapshot() async {
    _hybridSync.requestVaultSync();
  }

  @override
  Future<void> requestVaultDelta({DateTime? since}) async {
    _hybridSync.requestVaultDelta(since: since);
  }

  Future<void> _handleInboundContactMutation(Map<String, dynamic> payload) async {
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
                  updatedAt: Value(DateTime.now().toUtc()),
                  isSynced: const Value(true),
                ),
                mode: InsertMode.insertOrReplace,
              );
        }
      } else if (action == 'DELETE') {
        final id = data['id'] as String?;
        if (id != null) {
          await (_db.delete(_db.contacts)..where((tbl) => tbl.id.equals(id))).go();
        }
      }
    } catch (e) {
      log('CommsRepository: Inbound contact mutation note: $e');
    }
  }

  Future<void> _handleInboundTaskMutation(Map<String, dynamic> payload) async {
    try {
      final action = payload['action'] as String?;
      final data = payload['data'] is Map<String, dynamic>
          ? payload['data'] as Map<String, dynamic>
          : <String, dynamic>{};

      if (action == 'INSERT' || action == 'UPDATE') {
        final id = data['id'] as String?;
        final title = data['title'] as String?;
        if (id != null && title != null) {
          DateTime? due;
          if (data['due_date'] != null) {
            due = DateTime.tryParse(data['due_date'].toString());
          }
          await _db.into(_db.tasks).insert(
                db.TasksCompanion.insert(
                  id: id,
                  title: title,
                  dueDate: Value(due?.toUtc()),
                  priority: Value(data['priority'] as String? ?? 'medium'),
                  isCompleted: Value(data['is_completed'] as bool? ?? false),
                  updatedAt: Value(DateTime.now().toUtc()),
                  isSynced: const Value(true),
                ),
                mode: InsertMode.insertOrReplace,
              );
        }
      } else if (action == 'DELETE') {
        final id = data['id'] as String?;
        if (id != null) {
          await (_db.delete(_db.tasks)..where((tbl) => tbl.id.equals(id))).go();
        }
      }
    } catch (e) {
      log('CommsRepository: Inbound task mutation note: $e');
    }
  }

  Future<void> _handleInboundAlarmMutation(Map<String, dynamic> payload) async {
    try {
      final action = payload['action'] as String?;
      final data = payload['data'] is Map<String, dynamic>
          ? payload['data'] as Map<String, dynamic>
          : <String, dynamic>{};

      if (action == 'INSERT' || action == 'UPDATE') {
        final id = data['id'] as String?;
        final hour = (data['hour'] as num?)?.toInt();
        final minute = (data['minute'] as num?)?.toInt();
        if (id != null && hour != null && minute != null) {
          await _db.into(_db.alarms).insert(
                db.AlarmsCompanion.insert(
                  id: id,
                  hour: hour,
                  minute: minute,
                  label: Value(data['label'] as String? ?? 'Beacon Alarm'),
                  daysOfWeek: Value(data['days_of_week'] as String? ?? 'daily'),
                  isActive: Value(data['is_active'] as bool? ?? true),
                  updatedAt: Value(DateTime.now().toUtc()),
                  isSynced: const Value(true),
                ),
                mode: InsertMode.insertOrReplace,
              );
        }
      } else if (action == 'DELETE') {
        final id = data['id'] as String?;
        if (id != null) {
          await (_db.delete(_db.alarms)..where((tbl) => tbl.id.equals(id))).go();
        }
      }
    } catch (e) {
      log('CommsRepository: Inbound alarm mutation note: $e');
    }
  }

  Future<void> _handleInboundMemoMutation(Map<String, dynamic> payload) async {
    try {
      final action = payload['action'] as String?;
      final data = payload['data'] is Map<String, dynamic>
          ? payload['data'] as Map<String, dynamic>
          : <String, dynamic>{};

      if (action == 'INSERT' || action == 'UPDATE') {
        final id = data['id'] as String?;
        final title = data['title'] as String?;
        final content = data['content'] as String?;
        if (id != null && title != null) {
          DateTime? created;
          if (data['created_at'] != null) {
            created = DateTime.tryParse(data['created_at'].toString());
          }
          await _db.into(_db.voiceMemos).insert(
                db.VoiceMemosCompanion.insert(
                  id: id,
                  title: title,
                  content: content ?? '',
                  createdAt: Value(created?.toUtc() ?? DateTime.now().toUtc()),
                  updatedAt: Value(DateTime.now().toUtc()),
                  isSynced: const Value(true),
                ),
                mode: InsertMode.insertOrReplace,
              );
        }
      } else if (action == 'DELETE') {
        final id = data['id'] as String?;
        if (id != null) {
          await (_db.delete(_db.voiceMemos)..where((tbl) => tbl.id.equals(id))).go();
        }
      }
    } catch (e) {
      log('CommsRepository: Inbound memo mutation note: $e');
    }
  }

  Future<void> _handleInboundSpatialNodeMutation(Map<String, dynamic> payload) async {
    try {
      final action = payload['action'] as String?;
      final data = payload['data'] is Map<String, dynamic>
          ? payload['data'] as Map<String, dynamic>
          : <String, dynamic>{};

      if (action == 'INSERT' || action == 'UPDATE') {
        final id = data['id'] as String?;
        final moduleId = data['module_id'] as String?;
        if (id != null && moduleId != null) {
          await _db.into(_db.spatialNodes).insert(
                db.SpatialNodesCompanion.insert(
                  id: id,
                  moduleId: moduleId,
                  floorLevel: Value((data['floor_level'] as num?)?.toInt() ?? 0),
                  x: Value((data['x'] as num?)?.toInt() ?? 0),
                  y: Value((data['y'] as num?)?.toInt() ?? 0),
                  customTitle: Value(data['custom_title'] as String?),
                  configJson: Value(data['config_json'] as String?),
                  isVisible: Value(data['is_visible'] as bool? ?? true),
                  updatedAt: Value(DateTime.now().toUtc()),
                  isSynced: const Value(true),
                ),
                mode: InsertMode.insertOrReplace,
              );
        }
      } else if (action == 'DELETE') {
        final id = data['id'] as String?;
        if (id != null) {
          await (_db.delete(_db.spatialNodes)..where((tbl) => tbl.id.equals(id))).go();
        }
      }
    } catch (e) {
      log('CommsRepository: Inbound spatial node mutation note: $e');
    }
  }

  Future<void> _handleInboundSettingsMutation(Map<String, dynamic> payload) async {
    try {
      final data = payload['data'] is Map<String, dynamic>
          ? payload['data'] as Map<String, dynamic>
          : <String, dynamic>{};

      final localSettings = await _db.getSettings();
      await (_db.update(_db.appSettings)..where((tbl) => tbl.id.equals(localSettings.id))).write(
        db.AppSettingsCompanion(
          userPersona: data['user_persona'] != null ? Value(data['user_persona'].toString()) : const Value.absent(),
          hasCompletedOnboarding: data['has_completed_onboarding'] != null ? Value(data['has_completed_onboarding'] as bool) : const Value.absent(),
          speechRate: data['speech_rate'] != null ? Value((data['speech_rate'] as num).toDouble()) : const Value.absent(),
          hapticsEnabled: data['haptics_enabled'] != null ? Value(data['haptics_enabled'] as bool) : const Value.absent(),
          soundCuesEnabled: data['sound_cues_enabled'] != null ? Value(data['sound_cues_enabled'] as bool) : const Value.absent(),
          isHighContrast: data['is_high_contrast'] != null ? Value(data['is_high_contrast'] as bool) : const Value.absent(),
          spatialWhisperEnabled: data['spatial_whisper_enabled'] != null ? Value(data['spatial_whisper_enabled'] as bool) : const Value.absent(),
          defaultPriority: data['default_priority'] != null ? Value(data['default_priority'].toString()) : const Value.absent(),
          autoArchiveCompleted: data['auto_archive_completed'] != null ? Value(data['auto_archive_completed'] as bool) : const Value.absent(),
          speakDueDatesAloud: data['speak_due_dates_aloud'] != null ? Value(data['speak_due_dates_aloud'] as bool) : const Value.absent(),
          autoDialEmergency: data['auto_dial_emergency'] != null ? Value(data['auto_dial_emergency'] as bool) : const Value.absent(),
          shareGpsOnSos: data['share_gps_on_sos'] != null ? Value(data['share_gps_on_sos'] as bool) : const Value.absent(),
          speakIncomingSms: data['speak_incoming_sms'] != null ? Value(data['speak_incoming_sms'] as bool) : const Value.absent(),
          voiceChimeHalfway: data['voice_chime_halfway'] != null ? Value(data['voice_chime_halfway'] as bool) : const Value.absent(),
          vibrateOnSessionFinish: data['vibrate_on_session_finish'] != null ? Value(data['vibrate_on_session_finish'] as bool) : const Value.absent(),
          syncAlarmsWithAndroidClock: data['sync_alarms_with_android_clock'] != null ? Value(data['sync_alarms_with_android_clock'] as bool) : const Value.absent(),
          visionInspectionDetail: data['vision_inspection_detail'] != null ? Value(data['vision_inspection_detail'].toString()) : const Value.absent(),
          autoFlashlightInDark: data['auto_flashlight_in_dark'] != null ? Value(data['auto_flashlight_in_dark'] as bool) : const Value.absent(),
          preferredCurrency: data['preferred_currency'] != null ? Value(data['preferred_currency'].toString()) : const Value.absent(),
          updatedAt: Value(DateTime.now().toUtc()),
          isSynced: const Value(true),
        ),
      );
    } catch (e) {
      log('CommsRepository: Inbound settings mutation note: $e');
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

  Future<void> _handleIncomingRemoteActions(List<Map<String, dynamic>> rawActions) async {
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

  Future<void> _handleCloudRealtimeContacts(List<Map<String, dynamic>> cloudContacts) async {
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

          final cloudUpdated = cloudItem['updated_at'] != null
              ? DateTime.tryParse(cloudItem['updated_at'] as String)
              : null;
          final deletedAtStr = cloudItem['deleted_at'] as String?;
          final DateTime? deletedAt =
              deletedAtStr != null ? DateTime.tryParse(deletedAtStr) : null;

          final local = localMap[id];
          final shouldApply = local == null ||
              (cloudUpdated != null && cloudUpdated.isAfter(local.updatedAt)) ||
              (local.isSynced);

          if (!shouldApply) continue;

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
                updatedAt: Value(cloudUpdated ?? DateTime.now().toUtc()),
                isSynced: const Value(true),
              ),
              mode: InsertMode.insertOrReplace,
            );
          }
        }
      });
      log('CommsRepository: ⚡ Reconciled ${cloudContacts.length} realtime cloud contacts with LWW.');
    } catch (e, st) {
      log('CommsRepository: Error reconciling realtime contacts: $e', stackTrace: st);
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
        'updated_at': DateTime.now().toUtc().toIso8601String(),
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
    final nowUtc = DateTime.now().toUtc();

    await (_db.update(_db.contacts)..where((tbl) => tbl.id.equals(contactId))).write(
      db.ContactsCompanion(
        isEmergency: Value(nextStatus),
        updatedAt: Value(nowUtc),
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
        'updated_at': nowUtc.toIso8601String(),
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
      data: {
        'id': id,
        'deleted_at': DateTime.now().toUtc().toIso8601String(),
      },
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

    final deviceRecords = await _hardware.getDeviceContacts();
    final result = await _reconciliationService.reconcile(
      deviceRecords: deviceRecords,
      database: _db,
    );

    if (result.addedCount > 0 || result.updatedCount > 0) {
      _hybridSync.broadcastVaultMutation(
        table: 'contacts',
        action: 'RECONCILE',
        data: {
          'added': result.addedCount,
          'updated': result.updatedCount,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
      );
    }

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
  // 🚨 استغاثة الطوارئ SOS وسجل البلوكتشين
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
  Stream<List<SosAlertRecord>> watchSosHistory() {
    return (_db.select(_db.sosAlerts)
          ..where((s) => s.deletedAt.isNull())
          ..orderBy([(s) => OrderingTerm.desc(s.triggeredAt)]))
        .watch()
        .map((rows) => rows
            .map((r) => SosAlertRecord(
                  id: r.id,
                  latitude: r.latitude,
                  longitude: r.longitude,
                  batteryLevel: r.batteryLevel,
                  status: r.status,
                  googleMapsUrl: r.googleMapsUrl,
                  triggeredAt: r.triggeredAt,
                ))
            .toList());
  }

  @override
  Future<void> restoreCommsFromCloud() async {
    if (!_cloud.isAuthenticated) return;
    try {
      final cloudContacts = await _cloud.fetchContactsDelta();
      if (cloudContacts.isEmpty) return;

      final localContacts = await _db.getAllContacts();
      final localMap = {for (final c in localContacts) c.id: c};

      await _db.batch((batch) {
        for (final c in cloudContacts) {
          final id = c['id'] as String?;
          if (id == null) continue;

          final deletedAtStr = c['deleted_at'] as String?;
          final DateTime? deletedAt =
              deletedAtStr != null ? DateTime.tryParse(deletedAtStr) : null;
          final updatedStr = c['updated_at'] as String?;
          final DateTime? updatedAt =
              updatedStr != null ? DateTime.tryParse(updatedStr) : null;

          final local = localMap[id];

          if (deletedAt != null) {
            if (local != null) {
              batch.delete(_db.contacts, db.ContactsCompanion(id: Value(id)));
            }
          } else {
            final shouldApply = local == null ||
                (updatedAt != null && updatedAt.isAfter(local.updatedAt)) ||
                (local.isSynced);

            if (shouldApply) {
              batch.insert(
                _db.contacts,
                db.ContactsCompanion.insert(
                  id: id,
                  name: c['name'] as String,
                  phoneNumber: c['phone_number'] as String,
                  relationship: Value(c['relationship'] as String?),
                  isEmergency: Value(c['is_emergency'] as bool? ?? false),
                  updatedAt: Value(updatedAt ?? DateTime.now().toUtc()),
                  isSynced: const Value(true),
                ),
                mode: InsertMode.insertOrReplace,
              );
            }
          }
        }
      });
      log('CommsRepository: ⚡ Restored and reconciled ${cloudContacts.length} contacts from cloud in batch.');
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
              'updated_at': c.updatedAt.toUtc().toIso8601String(),
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
  // 🔗 بروتوكول الاقتران السيادي الصامت (Zero-Login Device Pairing)
  // ===========================================================================

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
      log('CommsRepository: Collision-proof pairing code registered: $code');
    } catch (e) {
      log('CommsRepository: Cloud pairing registration deferred (offline-first): $e');
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

                _hybridSync.updateLinkedVaultId(vaultId);
                await initializeHybridTransport(
                  deviceType: deviceType,
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
        _hybridSync.updatePairingCode(cleanCode);
        _hybridSync.updateLinkedVaultId(masterVaultId);
        log('CommsRepository: Successfully paired with code $cleanCode for Vault $masterVaultId');

        unawaited(sendVaultDeltaToPeers());
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
    await _hybridSync.unpairAndReset();
    log('CommsRepository: Device unpaired and hybrid network state fully reset.');
  }
}

extension on db.AppDatabase {
  Future<List<db.Contact>> getAllContacts() {
    return (select(contacts)..where((c) => c.deletedAt.isNull())).get();
  }
}