// packages/launcher_repository/lib/src/launcher_repository.dart
import 'dart:developer';
import 'package:cloud_sync_api/cloud_sync_api.dart';
import 'package:local_vault_api/local_vault_api.dart';
import 'package:ring_integration_api/ring_integration_api.dart';
import 'package:system_hardware_api/system_hardware_api.dart';
import 'package:voice_ai_api/voice_ai_api.dart';

import 'domains/assistant_repository.dart';
import 'domains/comms_repository.dart';
import 'domains/focus_alarms_repository.dart';
import 'domains/ring_repository.dart';
import 'domains/settings_repository.dart';
import 'domains/system_hardware_repository.dart';
import 'domains/task_agenda_repository.dart';
import 'domains/topology_repository.dart';

export 'domains/assistant_repository.dart';
export 'domains/comms_repository.dart';
export 'domains/focus_alarms_repository.dart';
export 'domains/ring_repository.dart';
export 'domains/settings_repository.dart';
export 'domains/system_hardware_repository.dart';
export 'domains/task_agenda_repository.dart';
export 'domains/topology_repository.dart';

export 'models/app_setting_entity.dart';
export 'models/task_entity.dart';
export 'models/voice_memo_entity.dart';
export 'models/alarm_entity.dart';
export 'models/focus_session_entity.dart';
export 'models/contact_entity.dart';
export 'models/message_entity.dart';
export 'models/spatial_node_entity.dart';
export 'models/ring_device_entity.dart'; // 👈 الكيان الجديد
export 'models/ring_event_entity.dart';  // 👈 الكيان الجديد
export 'models/remote_action_event.dart';

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

/// منسق النظام المركزي (Spatial OS Kernel / Orchestrator)
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
  }) {
    final db = database ?? AppDatabase();
    final cloud = cloudSyncClient ?? CloudSyncClient();
    final hw = hardwareClient ?? HardwareClient();

    settings = settingsRepository ?? SettingsRepositoryImpl(database: db, cloudSync: cloud);
    tasks = taskAgendaRepository ?? TaskAgendaRepositoryImpl(database: db, cloudSync: cloud);
    focusAlarms = focusAlarmsRepository ?? FocusAlarmsRepositoryImpl(database: db, cloudSync: cloud, hardware: hw);
    hardware = hardwareRepository ?? SystemHardwareRepositoryImpl(hardwareClient: hw);
    comms = commsRepository ?? CommsRepositoryImpl(database: db, cloudSync: cloud, hardware: hw);
    assistant = assistantRepository ?? AssistantRepositoryImpl(speechEngine: speechEngine, ttsEngine: ttsEngine, llmAgent: llmAgent);
    topology = topologyRepository ?? TopologyRepositoryImpl(database: db, cloudSync: cloud);

    // 🔔 تهيئة منظومة كاميرات Ring مع محاكي السيناريوهات الجاهز للحكام
    final ringCl = ringClient ?? RingSimulatorClient();
    ring = ringRepository ??
        RingRepositoryImpl(
          database: db,
          ringClient: ringCl,
          assistantRepository: assistant,
          cloudSync: cloud,
        );

    // 🛰️ تفعيل الاستماع اللحظي للرادار والطوبولوجيا
    comms.initializeRealtimeSync();
    topology.initializeRealtimeSync();
  }

  // --- الوصول المباشر للمستودعات الثمانية المتخصصة ---
  late final SettingsRepository settings;
  late final TaskAgendaRepository tasks;
  late final FocusAlarmsRepository focusAlarms;
  late final SystemHardwareRepository hardware;
  late final CommsRepository comms;
  late final AssistantRepository assistant;
  late final TopologyRepository topology;
  late final RingRepository ring;

  Future<LauncherCommandResult> Function(String userQuery, {String? base64Image})? _customVoiceDispatcher;

  void registerVoiceDispatcher(
    Future<LauncherCommandResult> Function(String userQuery, {String? base64Image}) dispatcher,
  ) {
    _customVoiceDispatcher = dispatcher;
    log('LauncherRepository: Custom VoiceCommandDispatcher registered successfully.');
  }

  Future<void> restoreVaultFromCloud() async {
    log('BeaconKernel: Restoring full vault from cloud...');
    await settings.restoreSettingsFromCloud();
    await comms.restoreCommsFromCloud();
    await tasks.restoreTasksAndMemosFromCloud();
    await topology.restoreTopologyFromCloud();
    log('BeaconKernel: Full vault restoration finished.');
  }

  Future<void> syncPendingOfflineChanges() async {
    log('BeaconKernel: Syncing pending changes...');
    await settings.syncPendingSettings();
    await tasks.syncPendingTasksAndMemos();
    await focusAlarms.syncPendingAlarms();
    await comms.syncPendingComms();
    await topology.syncPendingTopology();
    log('BeaconKernel: Offline sync cycle finished.');
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
    ring.dispose();
  }
}