// packages/launcher_repository/lib/src/domains/vault_sync_coordinator.dart
import 'dart:async';
import 'dart:developer';

import 'package:cloud_sync_api/cloud_sync_api.dart';
import 'package:drift/drift.dart';
import 'package:local_vault_api/local_vault_api.dart' as db;
import 'package:uuid/uuid.dart';

import '../models/remote_action_event.dart';
import 'safety_radar_repository.dart';

export 'package:cloud_sync_api/cloud_sync_api.dart' show LocalNodeInfo, SyncTransportMode;

abstract class VaultSyncCoordinator {
  Stream<RemoteActionEvent> get remoteActionEvents;

  Stream<SyncTransportMode> get transportModeStream;
  SyncTransportMode get currentTransportMode;

  Stream<List<LocalNodeInfo>> get activeMeshNodesStream;
  List<LocalNodeInfo> get activeMeshNodes;

  Future<void> initializeHybridTransport({
    required String deviceType,
    String? nodeId,
    String? linkedVaultId,
  });

  void initializeCloudRealtimeSync();

  Future<void> requestVaultSnapshot();

  Future<void> sendVaultSnapshotToPeers();

  Future<void> requestVaultDelta({DateTime? since});

  Future<void> sendVaultDeltaToPeers({DateTime? since});

  void broadcastVaultMutation({
    required String table,
    required String action,
    required Map<String, dynamic> data,
  });

  void updatePairingCredentials({String? pairingCode, String? linkedVaultId});

  void dispose();
}

class VaultSyncCoordinatorImpl implements VaultSyncCoordinator {
  VaultSyncCoordinatorImpl({
    required db.AppDatabase database,
    required CloudSyncClient cloudSync,
    required HybridSyncClient hybridSync,
    required SafetyRadarRepository safetyRadarRepository,
  })  : _db = database,
        _cloud = cloudSync,
        _hybridSync = hybridSync,
        _safetyRadar = safetyRadarRepository;

  final db.AppDatabase _db;
  final CloudSyncClient _cloud;
  final HybridSyncClient _hybridSync;
  final SafetyRadarRepository _safetyRadar;
  final _uuid = const Uuid();

  StreamSubscription<P2pMessage>? _hybridEventsSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _remoteActionsSubscription;
  StreamSubscription<dynamic>? _authSubscription;

  final StreamController<RemoteActionEvent> _remoteActionController =
      StreamController<RemoteActionEvent>.broadcast();

  @override
  Stream<RemoteActionEvent> get remoteActionEvents => _remoteActionController.stream;

  @override
  Stream<SyncTransportMode> get transportModeStream => _hybridSync.transportModeStream;

  @override
  SyncTransportMode get currentTransportMode => _hybridSync.currentMode;

  @override
  Stream<List<LocalNodeInfo>> get activeMeshNodesStream => _hybridSync.activePeersStream;

  @override
  List<LocalNodeInfo> get activeMeshNodes => _hybridSync.activePeers;

  @override
  Future<void> initializeHybridTransport({
    required String deviceType,
    String? nodeId,
    String? linkedVaultId,
  }) async {
    final vaultId = linkedVaultId ?? await _db.getDevicePairingMeta('linked_vault_id');
    await _hybridSync.initialize(
      deviceType: deviceType,
      nodeId: nodeId ?? 'beacon_${deviceType}_${_uuid.v4().substring(0, 6)}',
      linkedVaultId: vaultId,
    );

    _hybridEventsSubscription?.cancel();
    _hybridEventsSubscription = _hybridSync.unifiedEvents.listen(
      _handleUnifiedIncomingMessage,
      onError: (Object err) => log('VaultSyncCoordinator: Unified events error: $err'),
    );
  }

  @override
  void updatePairingCredentials({String? pairingCode, String? linkedVaultId}) {
    if (pairingCode != null) _hybridSync.updatePairingCode(pairingCode);
    if (linkedVaultId != null) _hybridSync.updateLinkedVaultId(linkedVaultId);
  }

  @override
  void initializeCloudRealtimeSync() {
    _authSubscription?.cancel();
    _authSubscription = _cloud.authStateChanges?.listen((authState) {
      if (_cloud.isAuthenticated) {
        _subscribeToRemoteActions();
      } else {
        _remoteActionsSubscription?.cancel();
        _remoteActionsSubscription = null;
      }
    });

    _subscribeToRemoteActions();
  }

  void _subscribeToRemoteActions() {
    _remoteActionsSubscription?.cancel();
    try {
      final stream = _cloud.streamRemoteActions();
      if (stream != null) {
        _remoteActionsSubscription = stream.listen(
          _handleIncomingRemoteActions,
          onError: (Object error) {
            log('VaultSyncCoordinator: Remote actions stream error: $error');
          },
          cancelOnError: false,
        );
        log('VaultSyncCoordinator: 🛰️ Listening for remote actions (Alexa / Displays)...');
      }
    } catch (e) {
      log('VaultSyncCoordinator: Safe catch on streamRemoteActions init: $e');
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
        await _safetyRadar.executeLocateDevice();
      } else if (event.actionType == RemoteActionType.triggerSos) {
        await _safetyRadar.triggerEmergencySos();
      }

      await _cloud.acknowledgeRemoteAction(event.id, status: 'completed');
    }
  }

  void _handleUnifiedIncomingMessage(P2pMessage message) {
    // 1. معالجة طلب لقطة الخزنة الوارد
    if (message.type == P2pMessageType.vaultSyncRequest) {
      log('VaultSyncCoordinator: 📥 Peer requested vault snapshot via LAN. Responding...');
      unawaited(sendVaultSnapshotToPeers());
      return;
    }

    // 2. معالجة لقطة الخزنة الواردة
    if (message.type == P2pMessageType.vaultSyncResponse) {
      log('VaultSyncCoordinator: 📥 Received inbound vault snapshot via LAN. Hydrating database...');
      unawaited(_handleInboundVaultDelta(message.payload));
      return;
    }

    // 3. معالجة طلب التغييرات التفاضلية (Delta Sync Request)
    if (message.type == P2pMessageType.vaultDeltaRequest) {
      final sinceStr = message.payload['since_utc'] as String?;
      final sinceUtc = sinceStr != null ? DateTime.tryParse(sinceStr) : null;
      log('VaultSyncCoordinator: 📥 Peer requested vault delta via LAN (Since: $sinceUtc). Responding...');
      unawaited(sendVaultDeltaToPeers(since: sinceUtc));
      return;
    }

    // 4. معالجة التغييرات التفاضلية الواردة وتطبيقها محلياً
    if (message.type == P2pMessageType.vaultDeltaResponse) {
      log('VaultSyncCoordinator: 📥 Received inbound vault delta via LAN. Applying changes...');
      unawaited(_handleInboundVaultDelta(message.payload));
      return;
    }

    final event = RemoteActionEvent.fromP2pMessage(message);

    // 5. معالجة التعديلات الفردية المباشرة عبر المقابس (Mutations)
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

    log('VaultSyncCoordinator: ⚡ Action Received via [${message.senderType ?? "Hybrid"}] -> ${event.actionType}');
    _remoteActionController.add(event);

    if (event.actionType == RemoteActionType.locateDevice) {
      _safetyRadar.executeLocateDevice();
    }
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
        // --- 1. المهام ---
        for (final item in rawTasks) {
          if (item is Map<String, dynamic>) {
            final id = item['id'] as String?;
            if (id == null) continue;

            final inboundUpdated = item['updated_at'] != null ? DateTime.tryParse(item['updated_at'].toString()) : null;
            final inboundDeleted = item['deleted_at'] != null ? DateTime.tryParse(item['deleted_at'].toString()) : null;

            final local = tasksMap[id];
            final shouldApply = local == null || (inboundUpdated != null && inboundUpdated.isAfter(local.updatedAt)) || local.isSynced;

            if (shouldApply) {
              if (inboundDeleted != null) {
                batch.delete(_db.tasks, db.TasksCompanion(id: Value(id)));
              } else {
                DateTime? due;
                if (item['due_date'] != null) due = DateTime.tryParse(item['due_date'].toString());
                batch.insert(
                  _db.tasks,
                  db.TasksCompanion.insert(
                    id: id,
                    title: item['title'] as String? ?? 'Untitled Task',
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

        // --- 2. المنبهات ---
        for (final item in rawAlarms) {
          if (item is Map<String, dynamic>) {
            final id = item['id'] as String?;
            if (id == null) continue;

            final inboundUpdated = item['updated_at'] != null ? DateTime.tryParse(item['updated_at'].toString()) : null;
            final inboundDeleted = item['deleted_at'] != null ? DateTime.tryParse(item['deleted_at'].toString()) : null;

            final local = alarmsMap[id];
            final shouldApply = local == null || (inboundUpdated != null && inboundUpdated.isAfter(local.updatedAt)) || local.isSynced;

            if (shouldApply) {
              if (inboundDeleted != null) {
                batch.delete(_db.alarms, db.AlarmsCompanion(id: Value(id)));
              } else {
                batch.insert(
                  _db.alarms,
                  db.AlarmsCompanion.insert(
                    id: id,
                    hour: (item['hour'] as num?)?.toInt() ?? 8,
                    minute: (item['minute'] as num?)?.toInt() ?? 0,
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

        // --- 3. جهات الاتصال ---
        for (final item in rawContacts) {
          if (item is Map<String, dynamic>) {
            final id = item['id'] as String?;
            if (id == null) continue;

            final inboundUpdated = item['updated_at'] != null ? DateTime.tryParse(item['updated_at'].toString()) : null;
            final inboundDeleted = item['deleted_at'] != null ? DateTime.tryParse(item['deleted_at'].toString()) : null;

            final local = contactsMap[id];
            final shouldApply = local == null || (inboundUpdated != null && inboundUpdated.isAfter(local.updatedAt)) || local.isSynced;

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

        // --- 4. المذكرات ---
        for (final item in rawMemos) {
          if (item is Map<String, dynamic>) {
            final id = item['id'] as String?;
            if (id == null) continue;

            final inboundUpdated = item['updated_at'] != null ? DateTime.tryParse(item['updated_at'].toString()) : null;
            final inboundDeleted = item['deleted_at'] != null ? DateTime.tryParse(item['deleted_at'].toString()) : null;

            final local = memosMap[id];
            final shouldApply = local == null || (inboundUpdated != null && inboundUpdated.isAfter(local.updatedAt)) || local.isSynced;

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

        // --- 5. العقد الفضائية ---
        for (final item in rawNodes) {
          if (item is Map<String, dynamic>) {
            final id = item['id'] as String?;
            if (id == null) continue;

            final inboundUpdated = item['updated_at'] != null ? DateTime.tryParse(item['updated_at'].toString()) : null;
            final inboundDeleted = item['deleted_at'] != null ? DateTime.tryParse(item['deleted_at'].toString()) : null;

            final local = nodesMap[id];
            final shouldApply = local == null || inboundUpdated == null || !inboundUpdated.isBefore(local.updatedAt.subtract(const Duration(seconds: 10))) || local.isSynced;

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

        // --- 6. الإعدادات ---
        for (final item in rawSettings) {
          if (item is Map<String, dynamic>) {
            final inboundUpdated = item['updated_at'] != null ? DateTime.tryParse(item['updated_at'].toString()) : null;

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
      log('VaultSyncCoordinator: ⚡ Full-Vault Delta applied with LWW resolution across all tables.');
    } catch (e, st) {
      log('VaultSyncCoordinator: Error applying inbound delta: $e', stackTrace: st);
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
          'id': t.id, 'title': t.title, 'due_date': t.dueDate?.toIso8601String(),
          'priority': t.priority, 'is_completed': t.isCompleted,
          'updated_at': t.updatedAt.toUtc().toIso8601String(), 'deleted_at': t.deletedAt?.toUtc().toIso8601String(),
        }).toList(),
        'alarms': alarms.map((a) => {
          'id': a.id, 'hour': a.hour, 'minute': a.minute, 'label': a.label,
          'days_of_week': a.daysOfWeek, 'is_active': a.isActive,
          'updated_at': a.updatedAt.toUtc().toIso8601String(), 'deleted_at': a.deletedAt?.toUtc().toIso8601String(),
        }).toList(),
        'contacts': contacts.map((c) => {
          'id': c.id, 'name': c.name, 'phone_number': c.phoneNumber,
          'relationship': c.relationship, 'is_emergency': c.isEmergency,
          'updated_at': c.updatedAt.toUtc().toIso8601String(), 'deleted_at': c.deletedAt?.toUtc().toIso8601String(),
        }).toList(),
        'memos': memos.map((m) => {
          'id': m.id, 'title': m.title, 'content': m.content,
          'created_at': m.createdAt.toUtc().toIso8601String(),
          'updated_at': m.updatedAt.toUtc().toIso8601String(), 'deleted_at': m.deletedAt?.toUtc().toIso8601String(),
        }).toList(),
        'spatial_nodes': nodes.map((n) => {
          'id': n.id, 'module_id': n.moduleId, 'floor_level': n.floorLevel, 'x': n.x, 'y': n.y,
          'custom_title': n.customTitle, 'config_json': n.configJson, 'is_visible': n.isVisible,
          'updated_at': n.updatedAt.toUtc().toIso8601String(), 'deleted_at': n.deletedAt?.toUtc().toIso8601String(),
        }).toList(),
        'settings': settings.map((s) => {
          'id': s.id, 'user_persona': s.userPersona, 'has_completed_onboarding': s.hasCompletedOnboarding,
          'speech_rate': s.speechRate, 'haptics_enabled': s.hapticsEnabled, 'sound_cues_enabled': s.soundCuesEnabled,
          'is_high_contrast': s.isHighContrast, 'spatial_whisper_enabled': s.spatialWhisperEnabled,
          'default_priority': s.defaultPriority, 'auto_archive_completed': s.autoArchiveCompleted,
          'speak_due_dates_aloud': s.speakDueDatesAloud, 'auto_dial_emergency': s.autoDialEmergency,
          'share_gps_on_sos': s.shareGpsOnSos, 'speak_incoming_sms': s.speakIncomingSms,
          'voice_chime_halfway': s.voiceChimeHalfway, 'vibrate_on_session_finish': s.vibrateOnSessionFinish,
          'sync_alarms_with_android_clock': s.syncAlarmsWithAndroidClock, 'vision_inspection_detail': s.visionInspectionDetail,
          'auto_flashlight_in_dark': s.autoFlashlightInDark, 'preferred_currency': s.preferredCurrency,
          'updated_at': s.updatedAt.toUtc().toIso8601String(),
        }).toList(),
      };

      _hybridSync.sendVaultDelta(deltaPayload);
      log('VaultSyncCoordinator: 📤 Dispatched Vault Delta to LAN peers.');
    } catch (e, st) {
      log('VaultSyncCoordinator: Error sending vault delta: $e', stackTrace: st);
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

  @override
  void broadcastVaultMutation({
    required String table,
    required String action,
    required Map<String, dynamic> data,
  }) {
    _hybridSync.broadcastVaultMutation(table: table, action: action, data: data);
  }

  // --- Handlers for individual inbound mutations ---
  Future<void> _handleInboundContactMutation(Map<String, dynamic> payload) async {
    final action = payload['action'] as String?;
    final data = payload['data'] is Map<String, dynamic> ? payload['data'] as Map<String, dynamic> : <String, dynamic>{};
    if (action == 'INSERT' || action == 'UPDATE') {
      final id = data['id'] as String?;
      if (id != null) {
        await _db.into(_db.contacts).insert(
              db.ContactsCompanion.insert(
                id: id, name: data['name'] as String? ?? 'Unknown', phoneNumber: data['phone_number'] as String? ?? '',
                relationship: Value(data['relationship'] as String?), isEmergency: Value(data['is_emergency'] as bool? ?? false),
                updatedAt: Value(DateTime.now().toUtc()), isSynced: const Value(true),
              ),
              mode: InsertMode.insertOrReplace,
            );
      }
    } else if (action == 'DELETE') {
      final id = data['id'] as String?;
      if (id != null) await (_db.delete(_db.contacts)..where((tbl) => tbl.id.equals(id))).go();
    }
  }

  Future<void> _handleInboundTaskMutation(Map<String, dynamic> payload) async {
    final action = payload['action'] as String?;
    final data = payload['data'] is Map<String, dynamic> ? payload['data'] as Map<String, dynamic> : <String, dynamic>{};
    if (action == 'INSERT' || action == 'UPDATE') {
      final id = data['id'] as String?;
      if (id != null) {
        DateTime? due;
        if (data['due_date'] != null) due = DateTime.tryParse(data['due_date'].toString());
        await _db.into(_db.tasks).insert(
              db.TasksCompanion.insert(
                id: id, title: data['title'] as String? ?? 'Task', dueDate: Value(due?.toUtc()),
                priority: Value(data['priority'] as String? ?? 'medium'), isCompleted: Value(data['is_completed'] as bool? ?? false),
                updatedAt: Value(DateTime.now().toUtc()), isSynced: const Value(true),
              ),
              mode: InsertMode.insertOrReplace,
            );
      }
    } else if (action == 'DELETE') {
      final id = data['id'] as String?;
      if (id != null) await (_db.delete(_db.tasks)..where((tbl) => tbl.id.equals(id))).go();
    }
  }

  Future<void> _handleInboundAlarmMutation(Map<String, dynamic> payload) async {
    final action = payload['action'] as String?;
    final data = payload['data'] is Map<String, dynamic> ? payload['data'] as Map<String, dynamic> : <String, dynamic>{};
    if (action == 'INSERT' || action == 'UPDATE') {
      final id = data['id'] as String?;
      if (id != null) {
        await _db.into(_db.alarms).insert(
              db.AlarmsCompanion.insert(
                id: id, hour: (data['hour'] as num?)?.toInt() ?? 8, minute: (data['minute'] as num?)?.toInt() ?? 0,
                label: Value(data['label'] as String? ?? 'Alarm'), daysOfWeek: Value(data['days_of_week'] as String? ?? 'daily'),
                isActive: Value(data['is_active'] as bool? ?? true), updatedAt: Value(DateTime.now().toUtc()), isSynced: const Value(true),
              ),
              mode: InsertMode.insertOrReplace,
            );
      }
    } else if (action == 'DELETE') {
      final id = data['id'] as String?;
      if (id != null) await (_db.delete(_db.alarms)..where((tbl) => tbl.id.equals(id))).go();
    }
  }

  Future<void> _handleInboundMemoMutation(Map<String, dynamic> payload) async {
    final action = payload['action'] as String?;
    final data = payload['data'] is Map<String, dynamic> ? payload['data'] as Map<String, dynamic> : <String, dynamic>{};
    if (action == 'INSERT' || action == 'UPDATE') {
      final id = data['id'] as String?;
      if (id != null) {
        DateTime? created;
        if (data['created_at'] != null) created = DateTime.tryParse(data['created_at'].toString());
        await _db.into(_db.voiceMemos).insert(
              db.VoiceMemosCompanion.insert(
                id: id, title: data['title'] as String? ?? 'Memo', content: data['content'] as String? ?? '',
                createdAt: Value(created?.toUtc() ?? DateTime.now().toUtc()), updatedAt: Value(DateTime.now().toUtc()), isSynced: const Value(true),
              ),
              mode: InsertMode.insertOrReplace,
            );
      }
    } else if (action == 'DELETE') {
      final id = data['id'] as String?;
      if (id != null) await (_db.delete(_db.voiceMemos)..where((tbl) => tbl.id.equals(id))).go();
    }
  }

  Future<void> _handleInboundSpatialNodeMutation(Map<String, dynamic> payload) async {
    final action = payload['action'] as String?;
    final data = payload['data'] is Map<String, dynamic> ? payload['data'] as Map<String, dynamic> : <String, dynamic>{};
    if (action == 'INSERT' || action == 'UPDATE') {
      final id = data['id'] as String?;
      if (id != null) {
        await _db.into(_db.spatialNodes).insert(
              db.SpatialNodesCompanion.insert(
                id: id, moduleId: data['module_id'] as String? ?? 'unknown', floorLevel: Value((data['floor_level'] as num?)?.toInt() ?? 0),
                x: Value((data['x'] as num?)?.toInt() ?? 0), y: Value((data['y'] as num?)?.toInt() ?? 0),
                customTitle: Value(data['custom_title'] as String?), configJson: Value(data['config_json'] as String?),
                isVisible: Value(data['is_visible'] as bool? ?? true), updatedAt: Value(DateTime.now().toUtc()), isSynced: const Value(true),
              ),
              mode: InsertMode.insertOrReplace,
            );
      }
    } else if (action == 'DELETE') {
      final id = data['id'] as String?;
      if (id != null) await (_db.delete(_db.spatialNodes)..where((tbl) => tbl.id.equals(id))).go();
    }
  }

  Future<void> _handleInboundSettingsMutation(Map<String, dynamic> payload) async {
    final data = payload['data'] is Map<String, dynamic> ? payload['data'] as Map<String, dynamic> : <String, dynamic>{};
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
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _hybridEventsSubscription?.cancel();
    _remoteActionsSubscription?.cancel();
    _remoteActionController.close();
  }
}