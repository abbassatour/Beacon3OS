// lib/core/voice_bus/ambient_voice/ambient_voice_cubit.dart
import 'dart:async';
import 'dart:developer';

import 'package:beacon_os/core/audio/sound_controller.dart';
import 'package:beacon_os/core/audio/sound_cue.dart';
import 'package:beacon_os/core/haptics/haptic_manager.dart';
import 'package:beacon_os/core/topology/spatial_module_registry.dart';
import 'package:beacon_os/core/voice_bus/ambient_voice/ambient_voice_state.dart';
import 'package:beacon_os/core/voice_bus/voice_command_dispatcher.dart';
import 'package:bloc/bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:launcher_repository/launcher_repository.dart';

class AmbientVoiceCubit extends Cubit<AmbientVoiceState> {
  AmbientVoiceCubit({
    required AssistantRepository assistantRepository,
    required VoiceCommandDispatcher voiceDispatcher,
    required TaskAgendaRepository taskRepository,
    required FocusAlarmsRepository focusAlarmsRepository,
    required SettingsRepository settingsRepository,
    CommsRepository? commsRepository,
    GlobalKey<NavigatorState>? navigatorKey,
    SoundController? soundController,
    HapticManager? hapticManager,
  })  : _assistant = assistantRepository,
        _dispatcher = voiceDispatcher,
        _tasksRepo = taskRepository,
        _focusRepo = focusAlarmsRepository,
        _settingsRepo = settingsRepository,
        _commsRepo = commsRepository,
        _navigatorKey = navigatorKey,
        _sound = soundController ?? SoundController.instance,
        _haptics = hapticManager ?? HapticManager.instance,
        super(const AmbientVoiceState());

  final AssistantRepository _assistant;
  final VoiceCommandDispatcher _dispatcher;
  final TaskAgendaRepository _tasksRepo;
  final FocusAlarmsRepository _focusRepo;
  final SettingsRepository _settingsRepo;
  final CommsRepository? _commsRepo;
  final GlobalKey<NavigatorState>? _navigatorKey;
  final SoundController _sound;
  final HapticManager _haptics;

  BuildContext? _activeContext;

  StreamSubscription<String>? _textSubscription;
  StreamSubscription<double>? _soundLevelSubscription;
  StreamSubscription<VoiceRecognitionEvent>? _recognitionSubscription;
  StreamSubscription<bool>? _isListeningSubscription;

  Timer? _autoCloseTimer;
  int _sessionGeneration = 0;
  bool _isExecuting = false;
  double _lastReportedSoundLevel = 0.0;

  // ===========================================================================
  // 🎙️ 1. بدء جلسة الاستماع الصوتي الحسي
  // ===========================================================================

  Future<void> startSession([BuildContext? context]) async {
    final currentGen = ++_sessionGeneration;
    _isExecuting = false;

    _cancelSubscriptions();
    _autoCloseTimer?.cancel();

    _updateActiveContext(context);

    await _sound.stopAll();
    await _assistant.stopSpeaking();

    if (isClosed) return;

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
    await Future<void>.delayed(const Duration(milliseconds: 180));

    // حماية: التأكد من أن الجلسة لم تُلغَ أثناء تشغيل نغمة الاستيقاظ
    if (_sessionGeneration != currentGen || !state.isListening || isClosed) {
      return;
    }

    _haptics.startListeningPulse();

    _textSubscription = _assistant.textStream.listen((text) {
      if (!isClosed && state.isListening && text.isNotEmpty) {
        emit(state.copyWith(liveTranscript: text));
      }
    });

    // تكميم شدة الصوت لمنع الضغط على إطارات المعالجة
    _soundLevelSubscription = _assistant.soundLevelStream.listen((level) {
      if (!isClosed && state.isListening) {
        if ((level - _lastReportedSoundLevel).abs() > 0.35) {
          _lastReportedSoundLevel = level;
          emit(state.copyWith(soundLevel: level));
        }
      }
    });

    _recognitionSubscription =
        _assistant.recognitionStream.listen((event) async {
      if (event.isFinal && state.isListening && !_isExecuting) {
        await stopAndExecute(queryOverride: event.text);
      }
    });

    _isListeningSubscription =
        _assistant.isListeningStream.listen((isListening) {
      if (!isListening && state.isListening && !_isExecuting) {
        stopAndExecute();
      }
    });

    try {
      await _assistant.startListening();
    } catch (e, st) {
      log('AmbientVoiceCubit: Failed to initiate speech listening: $e',
          stackTrace: st);
      _haptics.stopListeningPulse();
      await _sound.play(SoundCue.error);
      await _haptics.errorAlert();

      if (!isClosed) {
        emit(
          state.copyWith(
            status: AmbientVoiceStatus.error,
            errorMessage: 'Microphone unavailable',
            spokenResponse:
                'Could not start listening. Please verify microphone permissions.',
          ),
        );
        _scheduleAutoClose(const Duration(seconds: 3));
      }
    }
  }

  // ===========================================================================
  // ⚡ 2. حسم الأمر الصوتي والتنفيذ المحمي من التكرار (Race-Free Execution)
  // ===========================================================================

  Future<void> stopAndExecute({
    String? queryOverride,
    BuildContext? context,
  }) async {
    // 🛡️ قفل فوري متزامن لمنع أي تكرار عند ورود أكثر من حدث في نفس اللحظة
    if (_isExecuting || !state.isListening || state.isProcessing) return;
    _isExecuting = true;

    final currentGen = ++_sessionGeneration;
    _haptics.stopListeningPulse();

    // إشعار فوري بحالة المعالجة لقفل واجهة المستخدم قبل أي انتظار شبكي
    if (!isClosed) {
      emit(state.copyWith(status: AmbientVoiceStatus.processing));
    }

    _updateActiveContext(context);

    // تشغيل نغمة التفكير
    unawaited(_sound.play(SoundCue.processing));

    try {
      final recognizedFromMic = await _assistant.stopListening();

      final effectiveQuery = (queryOverride != null && queryOverride.trim().isNotEmpty)
          ? queryOverride.trim()
          : (recognizedFromMic.trim().isNotEmpty
              ? recognizedFromMic.trim()
              : state.liveTranscript.trim());

      // إذا كانت الجملة فارغة (لم يسمع شيئاً)
      if (effectiveQuery.isEmpty) {
        await _sound.play(SoundCue.error);
        await _haptics.errorAlert();
        const silenceMessage =
            "I didn't catch that. Please hold or swipe to try again.";

        if (!isClosed && _sessionGeneration == currentGen) {
          emit(
            state.copyWith(
              status: AmbientVoiceStatus.error,
              errorMessage: "Didn't catch that",
              spokenResponse: silenceMessage,
            ),
          );
        }

        await _assistant.speak(silenceMessage);
        _scheduleAutoClose(const Duration(seconds: 3));
        return;
      }

      final resolvedContext = _resolveValidContext(context);

      // توجيه ونطق الأمر
      final result = await _dispatcher.dispatchAndAnnounce(
        effectiveQuery,
        context: resolvedContext,
        contextProvider: () => _fetchLiveSystemContext(resolvedContext),
      );

      // فحص هل انتهت الجلسة أو أغلقت أثناء انتظار نتيجة الذكاء الاصطناعي
      if (isClosed || _sessionGeneration != currentGen) {
        return;
      }

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

      _scheduleAutoClose(const Duration(seconds: 4));
    } catch (e, st) {
      log('AmbientVoiceCubit: Execution error: $e', stackTrace: st);
      if (!isClosed && _sessionGeneration == currentGen) {
        emit(
          state.copyWith(
            status: AmbientVoiceStatus.error,
            errorMessage: 'Execution failure',
            spokenResponse: 'An error occurred while processing your request.',
          ),
        );
        _scheduleAutoClose(const Duration(seconds: 3));
      }
    } finally {
      _isExecuting = false;
    }
  }

  // ===========================================================================
  // 🧠 3. تجميع سياق قاعدة البيانات الحي (System Context Provider)
  // ===========================================================================

  Future<Map<String, dynamic>> _fetchLiveSystemContext([
    BuildContext? context,
  ]) async {
    try {
      const timeout = Duration(milliseconds: 700);

      final results = await Future.wait([
        _tasksRepo.getPendingTasks().timeout(timeout, onTimeout: () => []),
        _focusRepo.watchAlarms().first.timeout(timeout, onTimeout: () => []),
        _settingsRepo.getSettings().timeout(
              timeout,
              onTimeout: () => AppSettingEntity(
                id: 'fallback_settings',
                userPersona: 'digital_minimalist',
                hasCompletedOnboarding: true,
                speechRate: 0.5,
                hapticsEnabled: true,
                soundCuesEnabled: true,
                isHighContrast: false,
                spatialWhisperEnabled: false,
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
                updatedAt: DateTime.now(),
                isSynced: true,
              ),
            ),
        _tasksRepo.watchMemos().first.timeout(timeout, onTimeout: () => []),
        _commsRepo != null
            ? _commsRepo.watchContacts().first.timeout(timeout, onTimeout: () => [])
            : Future.value(<ContactEntity>[]),
      ]);

      final tasks = (results[0] as List<TaskEntity>).take(15).toList();
      final alarms = (results[1] as List<AlarmEntity>).take(10).toList();
      final settings = results[2] as AppSettingEntity;
      final memos = (results[3] as List<VoiceMemoEntity>).take(5).toList();
      final contacts = (results[4] as List<ContactEntity>).take(20).toList();

      final aggregatedContext = <String, dynamic>{
        'system_time': DateTime.now().toUtc().toIso8601String(),
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
          'spatial_whisper_enabled': settings.spatialWhisperEnabled,
          'default_priority': settings.defaultPriority,
          'auto_archive_completed': settings.autoArchiveCompleted,
          'vision_inspection_detail': settings.visionInspectionDetail,
          'preferred_currency': settings.preferredCurrency,
        },
      };

      // حقن سياق الموديولات المسجلة حياً في الطوبولوجيا
      final safeContext = _resolveValidContext(context);
      if (safeContext != null) {
        for (final module in SpatialModuleRegistry.instance.allModules) {
          try {
            final modCtx = await module
                .getVoiceContext(safeContext)
                .timeout(const Duration(milliseconds: 200), onTimeout: () => null);
            if (modCtx != null && modCtx.isNotEmpty) {
              aggregatedContext[module.id] = modCtx;
            }
          } catch (e) {
            log('AmbientVoiceCubit: Context poll skipped for [${module.id}]: $e');
          }
        }
      }

      return aggregatedContext;
    } catch (e, st) {
      log('AmbientVoiceCubit: Exception assembling system context: $e',
          stackTrace: st);
      return {};
    }
  }

  // ===========================================================================
  // 🛑 4. إدارة وإغلاق الجلسة بأمان
  // ===========================================================================

  void closeSession() {
    _sessionGeneration++;
    _isExecuting = false;
    _cancelSubscriptions();
    _autoCloseTimer?.cancel();
    _haptics.stopListeningPulse();
    unawaited(_assistant.cancelListening());

    if (!isClosed) {
      emit(const AmbientVoiceState(status: AmbientVoiceStatus.idle));
    }
  }

  void _scheduleAutoClose(Duration delay) {
    _autoCloseTimer?.cancel();
    _autoCloseTimer = Timer(delay, () {
      if (!isClosed && state.isOpen) {
        closeSession();
      }
    });
  }

  void _cancelSubscriptions() {
    _textSubscription?.cancel();
    _soundLevelSubscription?.cancel();
    _recognitionSubscription?.cancel();
    _isListeningSubscription?.cancel();
  }

  void _updateActiveContext(BuildContext? context) {
    if (context != null && context.mounted) {
      _activeContext = context;
    }
  }

  BuildContext? _resolveValidContext([BuildContext? directContext]) {
    if (directContext != null && directContext.mounted) {
      return directContext;
    }
    if (_activeContext != null && _activeContext!.mounted) {
      return _activeContext;
    }
    final navContext = _navigatorKey?.currentContext;
    if (navContext != null && navContext.mounted) {
      return navContext;
    }
    return null;
  }

  @override
  Future<void> close() {
    _sessionGeneration++;
    _isExecuting = false;
    _cancelSubscriptions();
    _autoCloseTimer?.cancel();
    return super.close();
  }
}