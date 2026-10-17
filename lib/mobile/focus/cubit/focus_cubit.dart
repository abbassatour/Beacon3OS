// lib/mobile/focus/cubit/focus_cubit.dart
import 'dart:async';
import 'package:beacon_os/core/audio/sound_controller.dart';
import 'package:beacon_os/core/audio/sound_cue.dart';
import 'package:beacon_os/core/haptics/haptic_manager.dart';
import 'package:beacon_os/mobile/focus/cubit/focus_state.dart';
import 'package:bloc/bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:launcher_repository/launcher_repository.dart'; // ✅ الاستيراد النقي

class FocusCubit extends Cubit<FocusState> with WidgetsBindingObserver {
  FocusCubit({
    required FocusAlarmsRepository focusRepository,
    required AssistantRepository assistantRepository,
    required SettingsRepository settingsRepository,
    HapticManager? hapticManager,
    SoundController? soundController,
  })  : _focusRepo = focusRepository,
        _assistant = assistantRepository,
        _settings = settingsRepository,
        _haptics = hapticManager ?? HapticManager.instance,
        _sound = soundController ?? SoundController.instance,
        super(const FocusState()) {
    WidgetsBinding.instance.addObserver(this);
    _initStreams();
  }

  final FocusAlarmsRepository _focusRepo;
  final AssistantRepository _assistant;
  final SettingsRepository _settings;
  final HapticManager _haptics;
  final SoundController _sound;

  Timer? _ticker;
  DateTime? _targetEndTime;
  StreamSubscription<List<AlarmEntity>>? _alarmsSub; // ✅
  StreamSubscription<List<FocusSessionEntity>>? _sessionsSub; // ✅

  bool _halfwayAnnounced = false;
  bool _oneMinuteAnnounced = false;

  void _initStreams() {
    _alarmsSub = _focusRepo.watchAlarms().listen((alarmList) {
      emit(state.copyWith(alarms: alarmList));
    });

    _sessionsSub = _focusRepo.watchTodayFocusSessions().listen((sessions) {
      emit(state.copyWith(todayCompletedSessions: sessions));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed) {
      _reconcileTimeOnResume();
    }
  }

  Future<void> _reconcileTimeOnResume() async {
    if (!state.isTimerRunning || _targetEndTime == null) return;
    await _tick();
    if (state.isTimerRunning && (_ticker == null || !_ticker!.isActive)) {
      _startPeriodicTicker();
    }
  }

  Future<void> selectDuration(int minutes) async {
    if (state.isTimerRunning) return;
    _ticker?.cancel();
    _ticker = null;
    _targetEndTime = null;

    emit(
      state.copyWith(
        selectedDurationMinutes: minutes,
        remainingSeconds: minutes * 60,
        timerStatus: TimerStatus.idle,
      ),
    );

    await _sound.play(SoundCue.navCenter);
    await _haptics.successNotification();
    await _assistant.speak('$minutes minutes focus cycle selected.');
  }

  Future<void> startTimer() async {
    _ticker?.cancel();
    _ticker = null;
    _halfwayAnnounced = false;
    _oneMinuteAnnounced = false;

    await _haptics.successNotification();
    await _sound.play(SoundCue.wake);

    _targetEndTime =
        DateTime.now().add(Duration(seconds: state.remainingSeconds));
    emit(state.copyWith(timerStatus: TimerStatus.running));

    await _assistant.speak(
      'Focus session started for ${state.selectedDurationMinutes} minutes.',
    );

    _startPeriodicTicker();
  }

  void _startPeriodicTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  Future<void> _tick() async {
    if (_targetEndTime == null || !state.isTimerRunning) return;

    final diff = _targetEndTime!.difference(DateTime.now()).inSeconds;

    if (diff > 0) {
      emit(state.copyWith(remainingSeconds: diff));

      final halfSec = (state.selectedDurationMinutes * 60) ~/ 2;
      if (diff <= halfSec && !_halfwayAnnounced) {
        _halfwayAnnounced = true;

        final settings = await _settings.getSettings();
        if (settings.voiceChimeHalfway) {
          await _sound.play(SoundCue.processing);
          final minsLeft = diff ~/ 60;
          await _assistant
              .speak('Halfway mark reached. $minsLeft minutes remaining.');
        }
      } else if (diff <= 60 && !_oneMinuteAnnounced) {
        _oneMinuteAnnounced = true;
        await _sound.play(SoundCue.processing);
        await _assistant.speak('One minute remaining.');
      }
    } else {
      _ticker?.cancel();
      _ticker = null;
      emit(state.copyWith(remainingSeconds: 0));
      await _onSessionCompleted();
    }
  }

  Future<void> pauseTimer() async {
    _ticker?.cancel();
    _ticker = null;
    _targetEndTime = null;

    await _haptics.successNotification();
    await _sound.play(SoundCue.navCenter);
    emit(state.copyWith(timerStatus: TimerStatus.paused));

    final minutes = state.remainingSeconds ~/ 60;
    await _assistant.speak('Session paused with $minutes minutes left.');
  }

  Future<void> resetTimer() async {
    _ticker?.cancel();
    _ticker = null;
    _targetEndTime = null;
    _halfwayAnnounced = false;
    _oneMinuteAnnounced = false;

    emit(
      state.copyWith(
        timerStatus: TimerStatus.idle,
        remainingSeconds: state.selectedDurationMinutes * 60,
      ),
    );

    await _haptics.successNotification();
    await _assistant.speak('Timer reset.');
  }

  Future<void> _onSessionCompleted() async {
    _ticker?.cancel();
    _ticker = null;
    _targetEndTime = null;

    await _sound.play(SoundCue.success);

    final settings = await _settings.getSettings();
    if (settings.vibrateOnSessionFinish) {
      await _haptics.emergencyAlarmPulse();
    } else {
      await _haptics.successNotification();
    }

    await _focusRepo.recordCompletedFocusSession(
      state.selectedDurationMinutes,
    );

    await _assistant.speak(
      'Session completed! You completed ${state.selectedDurationMinutes} minutes of focus.',
    );

    emit(
      state.copyWith(
        timerStatus: TimerStatus.idle,
        remainingSeconds: state.selectedDurationMinutes * 60,
      ),
    );
  }

  Future<void> toggleAlarm(AlarmEntity alarm) async { // ✅
    await _haptics.successNotification();
    await _focusRepo.toggleAlarm(alarm);

    final status = !alarm.isActive ? 'enabled' : 'disabled';
    final timeStr = _format12HourTime(alarm.hour, alarm.minute);
    await _assistant.speak('Alarm for $timeStr $status.');
  }

  Future<void> addAlarm({
    required int hour,
    required int minute,
    String label = 'Mindful Alarm',
  }) async {
    await _haptics.successNotification();
    await _focusRepo.createAlarm(hour: hour, minute: minute, label: label);

    final timeStr = _format12HourTime(hour, minute);
    final relative = getRelativeAlarmTimeString(hour, minute);
    await _assistant.speak('Alarm set for $timeStr. Rings $relative.');
  }

  Future<void> deleteAlarm(AlarmEntity alarm) async { // ✅
    await _haptics.successNotification();
    await _focusRepo.deleteAlarm(alarm.id);

    final timeStr = _format12HourTime(alarm.hour, alarm.minute);
    await _assistant.speak('Alarm for $timeStr deleted.');
  }

  Future<void> readAlarmDetailsAloud(AlarmEntity alarm) async { // ✅
    await _haptics.successNotification();

    final timeStr = _format12HourTime(alarm.hour, alarm.minute);
    if (!alarm.isActive) {
      await _assistant.speak('Alarm for $timeStr is currently turned off.');
      return;
    }

    final relative = getRelativeAlarmTimeString(alarm.hour, alarm.minute);
    await _assistant.speak('Alarm for $timeStr is active and rings $relative.');
  }

  String _format12HourTime(int hour, int minute) {
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    final period = hour >= 12 ? 'PM' : 'AM';
    final minStr = minute == 0 ? "o'clock" : minute.toString().padLeft(2, '0');
    return '$hour12 $minStr $period';
  }

  String getRelativeAlarmTimeString(int hour, int minute) {
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    var alarmMinutes = hour * 60 + minute;

    var diffMinutes = alarmMinutes - currentMinutes;
    if (diffMinutes <= 0) {
      diffMinutes += 24 * 60;
    }

    final hours = diffMinutes ~/ 60;
    final mins = diffMinutes % 60;

    if (hours == 0) {
      return 'in $mins minutes';
    } else if (mins == 0) {
      return 'in $hours hours';
    } else {
      return 'in $hours hours and $mins minutes';
    }
  }

  @override
  Future<void> close() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _alarmsSub?.cancel();
    _sessionsSub?.cancel();
    return super.close();
  }
}