// lib/core/voice_bus/ambient_voice/ambient_voice_cubit.dart
import 'dart:async';
import 'dart:developer';

import 'package:beacon_os/core/audio/sound_controller.dart';
import 'package:beacon_os/core/audio/sound_cue.dart';
import 'package:beacon_os/core/haptics/haptic_manager.dart';
import 'package:beacon_os/core/voice_bus/ambient_voice/ambient_voice_state.dart';
import 'package:beacon_os/core/voice_bus/voice_command_dispatcher.dart';
import 'package:bloc/bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:launcher_repository/launcher_repository.dart';
import 'package:local_vault_api/local_vault_api.dart';

class AmbientVoiceCubit extends Cubit<AmbientVoiceState> {
  AmbientVoiceCubit({
    required AssistantRepository assistantRepository,
    required VoiceCommandDispatcher voiceDispatcher,
    required TaskAgendaRepository taskRepository,
    required FocusAlarmsRepository focusAlarmsRepository,
    required SettingsRepository settingsRepository,
    CommsRepository? commsRepository,
    SoundController? soundController,
    HapticManager? hapticManager,
  })  : _assistant = assistantRepository,
        _dispatcher = voiceDispatcher,
        _tasksRepo = taskRepository,
        _focusRepo = focusAlarmsRepository,
        _settingsRepo = settingsRepository,
        _commsRepo = commsRepository,
        _sound = soundController ?? SoundController.instance,
        _haptics = hapticManager ?? HapticManager.instance,
        super(const AmbientVoiceState());

  final AssistantRepository _assistant;
  final VoiceCommandDispatcher _dispatcher;
  final TaskAgendaRepository _tasksRepo;
  final FocusAlarmsRepository _focusRepo;
  final SettingsRepository _settingsRepo;
  final CommsRepository? _commsRepo;
  final SoundController _sound;
  final HapticManager _haptics;

  StreamSubscription<String>? _textSubscription;
  StreamSubscription<double>? _soundLevelSubscription;
  StreamSubscription<VoiceRecognitionEvent>? _recognitionSubscription;
  StreamSubscription<bool>? _isListeningSubscription;
  Timer? _autoCloseTimer;
  int _sessionGeneration = 0;

  Future<void> startSession() async {
    final currentGen = ++_sessionGeneration;
    _cancelSubscriptions();
    _autoCloseTimer?.cancel();

    await _sound.stopAll();
    await _assistant.stopSpeaking();

    emit(
      state.copyWith(
        status: AmbientVoiceStatus.listening,
        liveTranscript: '',
        soundLevel: 0.0,
        spokenResponse: '',
        intent: null,
        errorMessage: null,
      ),
    );

    await _sound.play(SoundCue.wake);
    await Future<void>.delayed(const Duration(milliseconds: 200));

    if (_sessionGeneration != currentGen || !state.isListening) {
      return;
    }

    _haptics.startListeningPulse();

    _textSubscription = _assistant.textStream.listen((text) {
      if (state.isListening && text.isNotEmpty) {
        emit(state.copyWith(liveTranscript: text));
      }
    });

    _soundLevelSubscription = _assistant.soundLevelStream.listen((level) {
      if (state.isListening) {
        emit(state.copyWith(soundLevel: level));
      }
    });

    _recognitionSubscription =
        _assistant.recognitionStream.listen((event) async {
      if (event.isFinal && state.isListening) {
        await stopAndExecute(queryOverride: event.text);
      }
    });

    _isListeningSubscription =
        _assistant.isListeningStream.listen((isListening) {
      if (!isListening && state.isListening) {
        stopAndExecute();
      }
    });

    await _assistant.startListening();
  }

  Future<void> stopAndExecute({
    String? queryOverride,
    BuildContext? context,
  }) async {
    if (!state.isListening || state.isProcessing) return;

    _sessionGeneration++;
    _haptics.stopListeningPulse();
    await _sound.play(SoundCue.processing);

    emit(state.copyWith(status: AmbientVoiceStatus.processing));

    final recognizedFromMic = await _assistant.stopListening();
    final effectiveQuery = queryOverride ??
        (recognizedFromMic.isNotEmpty
            ? recognizedFromMic
            : state.liveTranscript.trim());

    if (effectiveQuery.isEmpty) {
      await _sound.play(SoundCue.error);
      await _haptics.errorAlert();
      const silenceMessage =
          "I didn't catch that. Please hold or swipe to try again.";

      emit(
        state.copyWith(
          status: AmbientVoiceStatus.error,
          errorMessage: "Didn't catch that",
          spokenResponse: silenceMessage,
        ),
      );

      await _assistant.speak(silenceMessage);

      _autoCloseTimer?.cancel();
      _autoCloseTimer = Timer(const Duration(seconds: 3), () {
        if (state.isOpen) closeSession();
      });
      return;
    }

    // ⚡️ تمرير _fetchLiveSystemContext كـ Provider يتم استدعاؤه كسولاً فقط إذا احتاجه الموديل
    final result = await _dispatcher.dispatchAndAnnounce(
      effectiveQuery,
      context: context,
      contextProvider: _fetchLiveSystemContext,
    );

    final isError =
        result.intent == 'ERROR' || result.intent.endsWith('_FAILED');

    emit(
      state.copyWith(
        status: isError
            ? AmbientVoiceStatus.error
            : AmbientVoiceStatus.speaking,
        spokenResponse: result.spokenResponse,
        intent: result.intent,
        errorMessage: isError ? result.spokenResponse : null,
      ),
    );

    _autoCloseTimer?.cancel();
    _autoCloseTimer = Timer(const Duration(seconds: 4), () {
      if (state.isOpen) closeSession();
    });
  }

  /// تجميع سياق النظام بشكل متوازٍ ومحصن بمهلات زمنية وسقف للبيانات
  Future<Map<String, dynamic>> _fetchLiveSystemContext() async {
    try {
      const timeout = Duration(milliseconds: 700);

      // 🚀 تنفيذ الاستعلامات بالتوازي عبر Future.wait بدلاً من التسلسل البطيء
      final results = await Future.wait([
        _tasksRepo.getPendingTasks().timeout(timeout, onTimeout: () => []),
        _focusRepo.watchAlarms().first.timeout(timeout, onTimeout: () => []),
        _settingsRepo.getSettings().timeout(
              timeout,
              onTimeout: () => AppSetting(
                id: 'fallback',
                userPersona: 'digital_minimalist',
                hasCompletedOnboarding: true,
                speechRate: 0.5,
                hapticsEnabled: true,
                soundCuesEnabled: true,
                isHighContrast: false,
                defaultPriority: 'medium',
                autoArchiveCompleted: true,
                speakDueDatesAloud: true,
                autoDialEmergency: true,
                shareGpsOnSos: true,
                speakIncomingSms: true,
                voiceChimeHalfway: true,
                vibrateOnSessionFinish: true,
                syncAlarmsWithAndroidClock: true,
                visionInspectionDetail: 'concise',
                autoFlashlightInDark: true,
                preferredCurrency: 'USD / Local',
                updatedAt: DateTime.now(), // 👈 استبدال null بـ DateTime.now() وإزالة const
                isSynced: true,
              ),
            ),
        _tasksRepo.watchMemos().first.timeout(timeout, onTimeout: () => []),
        _commsRepo != null
            ? _commsRepo!.watchContacts().first.timeout(timeout, onTimeout: () => [])
            : Future.value(<Contact>[]),
      ]);

      // 🛡️ تحديد سقف منطقي لحجم البيانات لحماية التوكنز وتسريع الاستجابة
      final tasks = (results[0] as List<Task>).take(15).toList();
      final alarms = (results[1] as List<Alarm>).take(10).toList();
      final settings = results[2] as AppSetting;
      final memos = (results[3] as List<VoiceMemo>).take(5).toList();
      final contacts = (results[4] as List<Contact>).take(20).toList();

      return {
        'tasks': tasks
            .map((t) => {
                  'id': t.id,
                  'title': t.title,
                  'priority': t.priority,
                  'due_date': t.dueDate?.toIso8601String(),
                })
            .toList(),
        'alarms': alarms
            .map((a) => {
                  'id': a.id,
                  'hour': a.hour,
                  'minute': a.minute,
                  'label': a.label,
                  'isActive': a.isActive,
                })
            .toList(),
        'memos': memos
            .map((m) => {
                  'id': m.id,
                  'title': m.title,
                  'content': m.content.length > 120
                      ? '${m.content.substring(0, 120)}...'
                      : m.content,
                })
            .toList(),
        'contacts': contacts
            .map((c) => {
                  'id': c.id,
                  'name': c.name,
                  'phone_number': c.phoneNumber,
                  'relationship': c.relationship,
                  'is_emergency': c.isEmergency,
                })
            .toList(),
        'settings': {
          'speech_rate': settings.speechRate,
          'haptics_enabled': settings.hapticsEnabled,
          'sound_cues_enabled': settings.soundCuesEnabled,
          'is_high_contrast': settings.isHighContrast,
          'default_priority': settings.defaultPriority,
          'auto_archive_completed': settings.autoArchiveCompleted,
          'vision_inspection_detail': settings.visionInspectionDetail,
          'preferred_currency': settings.preferredCurrency,
        },
      };
    } catch (e, st) {
      log('AmbientVoiceCubit: Exception while assembling system context: $e',
          stackTrace: st);
      return {};
    }
  }

  void closeSession() {
    _sessionGeneration++;
    _cancelSubscriptions();
    _autoCloseTimer?.cancel();
    _haptics.stopListeningPulse();
    _assistant.cancelListening();
    emit(const AmbientVoiceState(status: AmbientVoiceStatus.idle));
  }

  void _cancelSubscriptions() {
    _textSubscription?.cancel();
    _soundLevelSubscription?.cancel();
    _recognitionSubscription?.cancel();
    _isListeningSubscription?.cancel();
  }

  @override
  Future<void> close() {
    _sessionGeneration++;
    _cancelSubscriptions();
    _autoCloseTimer?.cancel();
    return super.close();
  }
}