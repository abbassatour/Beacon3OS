// lib/core/voice_bus/ambient_voice/ambient_voice_cubit.dart
import 'dart:async';
import 'dart:developer';

import 'package:beacon_os/core/audio/sound_controller.dart';
import 'package:beacon_os/core/audio/sound_cue.dart';
import 'package:beacon_os/core/haptics/haptic_manager.dart';
import 'package:beacon_os/core/voice_bus/ambient_voice/ambient_voice_state.dart'; // 👈 إزالة /cubit/
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

    final systemContext = await _fetchLiveSystemContext();

    final result = await _dispatcher.dispatchAndAnnounce(
      effectiveQuery,
      context: context,
      systemContext: systemContext,
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

  Future<Map<String, dynamic>> _fetchLiveSystemContext() async {
    try {
      final tasks = await _tasksRepo.getPendingTasks();
      final alarms = await _focusRepo.watchAlarms().first;
      final settings = await _settingsRepo.getSettings();

      List<VoiceMemo> memos = const [];
      try {
        memos = await _tasksRepo.watchMemos().first;
      } catch (_) {}

      List<Contact> contacts = const [];
      if (_commsRepo != null) {
        try {
          contacts = await _commsRepo.watchContacts().first;
        } catch (_) {}
      }

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
                  'content': m.content,
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