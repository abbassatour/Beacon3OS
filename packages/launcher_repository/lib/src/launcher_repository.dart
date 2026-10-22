// packages/launcher_repository/lib/src/launcher_repository.dart
import 'dart:async';
import 'dart:developer';

import 'package:cloud_sync_api/cloud_sync_api.dart';
import 'package:local_vault_api/local_vault_api.dart';
import 'package:ring_integration_api/ring_integration_api.dart';
import 'package:system_hardware_api/system_hardware_api.dart';
import 'package:voice_ai_api/voice_ai_api.dart';

import 'domains/assistant_repository.dart';
import 'domains/comms_repository.dart';
import 'domains/device_pairing_repository.dart';
import 'domains/focus_alarms_repository.dart';
import 'domains/ring_repository.dart';
import 'domains/safety_radar_repository.dart';
import 'domains/settings_repository.dart';
import 'domains/system_hardware_repository.dart';
import 'domains/task_agenda_repository.dart';
import 'domains/topology_repository.dart';
import 'domains/vault_sync_coordinator.dart';

export 'domains/assistant_repository.dart';
export 'domains/comms_repository.dart';
export 'domains/device_pairing_repository.dart';
export 'domains/focus_alarms_repository.dart';
export 'domains/ring_repository.dart';
export 'domains/safety_radar_repository.dart';
export 'domains/settings_repository.dart';
export 'domains/system_hardware_repository.dart';
export 'domains/task_agenda_repository.dart';
export 'domains/topology_repository.dart';
export 'domains/vault_sync_coordinator.dart';

export 'models/alarm_entity.dart';
export 'models/app_setting_entity.dart';
export 'models/contact_entity.dart';
export 'models/focus_session_entity.dart';
export 'models/message_entity.dart';
export 'models/remote_action_event.dart';
export 'models/ring_device_entity.dart';
export 'models/ring_event_entity.dart';
export 'models/spatial_node_entity.dart';
export 'models/task_entity.dart';
export 'models/voice_memo_entity.dart';

class LauncherCommandResult {
  const LauncherCommandResult({
    required this.intent,
    required this.spokenResponse,
    this.actionPayload,
  });

  final String intent;
  final String spokenResponse;
  final dynamic actionPayload;
}

/// منسق النظام المركزي ونواة التشغيل السيادية (BeaconOS Spatial Kernel)
/// يدير المستودعات النطاقية المتخصصة وينظم دورات المزامنة الهجينة
class LauncherRepository {
  LauncherRepository({
    AppDatabase? database,
    CloudSyncClient? cloudSyncClient,
    HardwareClient? hardwareClient,
    SpeechEngine? speechEngine,
    TtsEngine? ttsEngine,
    LlmAgent? llmAgent,
    RingClientInterface? ringClient,
    SettingsRepository? settingsRepository,
    TaskAgendaRepository? taskAgendaRepository,
    FocusAlarmsRepository? focusAlarmsRepository,
    SystemHardwareRepository? hardwareRepository,
    CommsRepository? commsRepository,
    AssistantRepository? assistantRepository,
    TopologyRepository? topologyRepository,
    RingRepository? ringRepository,
    DevicePairingRepository? devicePairingRepository,
    SafetyRadarRepository? safetyRadarRepository,
    VaultSyncCoordinator? vaultSyncCoordinator,
  }) {
    final db = database ?? AppDatabase();
    final cloud = cloudSyncClient ?? CloudSyncClient();
    final hw = hardwareClient ?? HardwareClient();
    final hybrid = HybridSyncClient(cloudSyncClient: cloud);

    settings = settingsRepository ?? SettingsRepositoryImpl(database: db, cloudSync: cloud);
    tasks = taskAgendaRepository ?? TaskAgendaRepositoryImpl(database: db, cloudSync: cloud);
    focusAlarms = focusAlarmsRepository ?? FocusAlarmsRepositoryImpl(database: db, cloudSync: cloud, hardware: hw);
    hardware = hardwareRepository ?? SystemHardwareRepositoryImpl(hardwareClient: hw);
    assistant = assistantRepository ?? AssistantRepositoryImpl(speechEngine: speechEngine, ttsEngine: ttsEngine, llmAgent: llmAgent);
    topology = topologyRepository ?? TopologyRepositoryImpl(database: db, cloudSync: cloud);

    // 🛡️ المستودعات الجديدة المعزولة
    safetyRadar = safetyRadarRepository ?? SafetyRadarRepositoryImpl(
      database: db, hardware: hw, hybridSync: hybrid,
    );

    vaultSync = vaultSyncCoordinator ?? VaultSyncCoordinatorImpl(
      database: db, cloudSync: cloud, hybridSync: hybrid, safetyRadarRepository: safetyRadar,
    );

    devicePairing = devicePairingRepository ?? DevicePairingRepositoryImpl(
      database: db, cloudSync: cloud, hybridSync: hybrid,
    );

    comms = commsRepository ?? CommsRepositoryImpl(
      database: db, cloudSync: cloud, hardware: hw, vaultSyncCoordinator: vaultSync,
    );

    // 🔔 تهيئة منظومة كاميرات Ring
    final ringCl = ringClient ?? RingSimulatorClient();
    ring = ringRepository ?? RingRepositoryImpl(
      database: db, ringClient: ringCl, assistantRepository: assistant, cloudSync: cloud,
    );

    // 🛰️ تفعيل الاستماع اللحظي التلقائي الشامل لجميع المكونات والبيانات
    vaultSync.initializeCloudRealtimeSync();
    comms.initializeRealtimeSync();
    topology.initializeRealtimeSync();
    tasks.initializeRealtimeSync();
    focusAlarms.initializeRealtimeSync();
  }

  // --- الوصول المباشر للمستودعات المتخصصة ---
  late final SettingsRepository settings;
  late final TaskAgendaRepository tasks;
  late final FocusAlarmsRepository focusAlarms;
  late final SystemHardwareRepository hardware;
  late final CommsRepository comms;
  late final AssistantRepository assistant;
  late final TopologyRepository topology;
  late final RingRepository ring;
  late final DevicePairingRepository devicePairing;
  late final SafetyRadarRepository safetyRadar;
  late final VaultSyncCoordinator vaultSync;

  Future<LauncherCommandResult> Function(String userQuery, {String? base64Image})? _customVoiceDispatcher;

  void registerVoiceDispatcher(
    Future<LauncherCommandResult> Function(String userQuery, {String? base64Image}) dispatcher,
  ) {
    _customVoiceDispatcher = dispatcher;
    log('LauncherRepository: Custom VoiceCommandDispatcher registered successfully.');
  }

  /// 🔄 استعادة الخزنة من السحابة بالتوازي مع فض النزاعات الذكي LWW
  Future<void> restoreVaultFromCloud() async {
    log('BeaconKernel: 🔄 Restoring and reconciling vault delta from cloud...');
    try {
      await Future.wait([
        settings.restoreSettingsFromCloud().catchError((Object e) {
          log('BeaconKernel: Settings restore warning: $e');
        }),
        comms.restoreCommsFromCloud().catchError((Object e) {
          log('BeaconKernel: Comms restore warning: $e');
        }),
        tasks.restoreTasksAndMemosFromCloud().catchError((Object e) {
          log('BeaconKernel: Tasks restore warning: $e');
        }),
        focusAlarms.restoreAlarmsFromCloud().catchError((Object e) {
          log('BeaconKernel: Alarms restore warning: $e');
        }),
        topology.restoreTopologyFromCloud().catchError((Object e) {
          log('BeaconKernel: Topology restore warning: $e');
        }),
      ]);
      log('BeaconKernel: ✅ Vault restoration and LWW reconciliation completed.');
    } catch (e, st) {
      log('BeaconKernel: Unexpected error during vault restoration: $e', stackTrace: st);
    }
  }

  /// 🚀 مزامنة كافة التعديلات غير المزامنة بالتوازي السريع
  Future<void> syncPendingOfflineChanges() async {
    log('BeaconKernel: 🚀 Syncing pending offline changes in batch...');
    try {
      await Future.wait([
        settings.syncPendingSettings().catchError((Object e) {
          log('BeaconKernel: Settings sync warning: $e');
        }),
        tasks.syncPendingTasksAndMemos().catchError((Object e) {
          log('BeaconKernel: Tasks sync warning: $e');
        }),
        focusAlarms.syncPendingAlarms().catchError((Object e) {
          log('BeaconKernel: Alarms sync warning: $e');
        }),
        comms.syncPendingComms().catchError((Object e) {
          log('BeaconKernel: Comms sync warning: $e');
        }),
        topology.syncPendingTopology().catchError((Object e) {
          log('BeaconKernel: Topology sync warning: $e');
        }),
      ]);
      log('BeaconKernel: ✅ Offline sync cycle completed.');
    } catch (e, st) {
      log('BeaconKernel: Unexpected error during offline sync: $e', stackTrace: st);
    }
  }

  Future<LauncherCommandResult> dispatchVoiceCommand(String userQuery, {String? base64Image}) async {
    if (_customVoiceDispatcher != null) {
      return _customVoiceDispatcher!(userQuery, base64Image: base64Image);
    }

    final result = await assistant.processLlmCommand(userCommand: userQuery, base64Image: base64Image);
    final response = result['spoken_response'] as String? ?? 'Done.';
    return LauncherCommandResult(intent: result['intent'] as String? ?? 'GENERAL', spokenResponse: response);
  }

  void dispose() {
    comms.dispose();
    topology.dispose();
    tasks.dispose();
    focusAlarms.dispose();
    ring.dispose();
    vaultSync.dispose();
  }
}