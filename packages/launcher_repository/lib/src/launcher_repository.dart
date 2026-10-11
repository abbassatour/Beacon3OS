// packages/launcher_repository/lib/src/launcher_repository.dart
import 'dart:developer';
import 'package:cloud_sync_api/cloud_sync_api.dart';
import 'package:local_vault_api/local_vault_api.dart';
import 'package:system_hardware_api/system_hardware_api.dart';
import 'package:voice_ai_api/voice_ai_api.dart';

import 'domains/assistant_repository.dart';
import 'domains/comms_repository.dart';
import 'domains/focus_alarms_repository.dart';
import 'domains/settings_repository.dart';
import 'domains/system_hardware_repository.dart';
import 'domains/task_agenda_repository.dart';

export 'domains/assistant_repository.dart';
export 'domains/comms_repository.dart';
export 'domains/focus_alarms_repository.dart';
export 'domains/settings_repository.dart';
export 'domains/system_hardware_repository.dart';
export 'domains/task_agenda_repository.dart';

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
/// مسؤول فقط عن تهيئة نطاقات النظام وتنسيق العمليات السيادية المتقاطعة.
class LauncherRepository {
  LauncherRepository({
    AppDatabase? database,
    CloudSyncClient? cloudSyncClient,
    HardwareClient? hardwareClient,
    SpeechEngine? speechEngine,
    TtsEngine? ttsEngine,
    LlmAgent? llmAgent,
    SettingsRepository? settingsRepository,
    TaskAgendaRepository? taskAgendaRepository,
    FocusAlarmsRepository? focusAlarmsRepository,
    SystemHardwareRepository? hardwareRepository,
    CommsRepository? commsRepository,
    AssistantRepository? assistantRepository,
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

    // 🛰️ تفعيل الاستماع اللحظي للرادار وجهات الاتصال مع سحابة Supabase
    comms.initializeRealtimeSync();
  }

  // --- الوصول المباشر للمستودعات الستة المتخصصة ---
  late final SettingsRepository settings;
  late final TaskAgendaRepository tasks;
  late final FocusAlarmsRepository focusAlarms;
  late final SystemHardwareRepository hardware;
  late final CommsRepository comms;
  late final AssistantRepository assistant;

  // 🔗 مأخذ توجيه الأوامر الصوتية الذكية (Pluggable Dispatcher Hook)
  Future<LauncherCommandResult> Function(String userQuery, {String? base64Image})? _customVoiceDispatcher;

  void registerVoiceDispatcher(
    Future<LauncherCommandResult> Function(String userQuery, {String? base64Image}) dispatcher,
  ) {
    _customVoiceDispatcher = dispatcher;
    log('LauncherRepository: Custom VoiceCommandDispatcher registered successfully.');
  }

  // ===========================================================================
  // 🔄 العمليات السيادية المنسقة بين عدة نطاقات (Cross-Domain Operations)
  // ===========================================================================

  /// استعادة بيانات الخزنة بالكامل من السحابة بتنسيق بين النطاقات
  Future<void> restoreVaultFromCloud() async {
    log('BeaconKernel: Restoring full vault from cloud...');
    await settings.restoreSettingsFromCloud();
    await comms.restoreCommsFromCloud();
    await tasks.restoreTasksAndMemosFromCloud();
    log('BeaconKernel: Full vault restoration finished.');
  }

  /// مزامنة كافة العمليات المعلقة دون إنترنت عبر النطاقات
  Future<void> syncPendingOfflineChanges() async {
    log('BeaconKernel: Syncing pending changes...');
    await settings.syncPendingSettings();
    await tasks.syncPendingTasksAndMemos();
    await focusAlarms.syncPendingAlarms();
    await comms.syncPendingComms();
    log('BeaconKernel: Offline sync cycle finished.');
  }

  /// توجيه الأوامر الصوتية لحافلة النظام الذكية أو المسار الاحتياطي
  Future<LauncherCommandResult> dispatchVoiceCommand(String userQuery, {String? base64Image}) async {
    if (_customVoiceDispatcher != null) {
      return _customVoiceDispatcher!(userQuery, base64Image: base64Image);
    }

    final result = await assistant.processLlmCommand(userCommand: userQuery, base64Image: base64Image);
    final response = result['spoken_response'] as String? ?? 'Done.';
    return LauncherCommandResult(intent: result['intent'] as String? ?? 'GENERAL', spokenResponse: response);
  }

  /// 🛑 تحرير موارد النواة والاستماعات اللحظية
  void dispose() {
    comms.dispose();
  }
}