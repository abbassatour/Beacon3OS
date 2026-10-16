// lib/desktop/cubit/desktop_focus_cubit.dart
import 'dart:async';
import 'dart:developer';

import 'package:beacon_os/desktop/focus/cubit/desktop_focus_state.dart';
import 'package:bloc/bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';
import 'package:local_vault_api/local_vault_api.dart';

class DesktopFocusCubit extends Cubit<DesktopFocusState> {
  DesktopFocusCubit({
    required FocusAlarmsRepository focusAlarmsRepository,
  })  : _focusRepo = focusAlarmsRepository,
        super(const DesktopFocusState()) {
    _initStreams();
  }

  final FocusAlarmsRepository _focusRepo;
  Timer? _ticker;
  DateTime? _targetEndTime;
  StreamSubscription<List<Alarm>>? _alarmsSub;
  StreamSubscription<List<FocusSession>>? _sessionsSub;

  void _initStreams() {
    emit(state.copyWith(status: DesktopFocusStatus.loading));

    _alarmsSub = _focusRepo.watchAlarms().listen(
      (alarms) {
        emit(
          state.copyWith(
            status: DesktopFocusStatus.success,
            alarms: alarms,
          ),
        );
      },
      onError: (Object error) {
        log('DesktopFocusCubit: Error watching alarms: $error');
      },
    );

    _sessionsSub = _focusRepo.watchTodayFocusSessions().listen(
      (sessions) {
        emit(
          state.copyWith(
            status: DesktopFocusStatus.success,
            todaySessions: sessions,
          ),
        );
      },
      onError: (Object error) {
        log('DesktopFocusCubit: Error watching sessions: $error');
      },
    );
  }

  // ===========================================================================
  // â±ï¸ Ø§Ù„ØªØ­ÙƒÙ… Ø¨Ø§Ù„Ù…Ø¤Ù‚Øª (Pomodoro Engine)
  // ===========================================================================

  void selectDuration(int minutes) {
    if (state.isRunning) return;
    _ticker?.cancel();
    _ticker = null;
    _targetEndTime = null;

    emit(
      state.copyWith(
        selectedDurationMinutes: minutes,
        remainingSeconds: minutes * 60,
        timerStatus: DesktopTimerStatus.idle,
      ),
    );
  }

  void startTimer() {
    _ticker?.cancel();
    _targetEndTime =
        DateTime.now().add(Duration(seconds: state.remainingSeconds));

    emit(state.copyWith(timerStatus: DesktopTimerStatus.running));

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void pauseTimer() {
    _ticker?.cancel();
    _ticker = null;
    _targetEndTime = null;
    emit(state.copyWith(timerStatus: DesktopTimerStatus.paused));
  }

  void resetTimer() {
    _ticker?.cancel();
    _ticker = null;
    _targetEndTime = null;

    emit(
      state.copyWith(
        timerStatus: DesktopTimerStatus.idle,
        remainingSeconds: state.selectedDurationMinutes * 60,
      ),
    );
  }

  void _tick() {
    if (_targetEndTime == null || !state.isRunning) return;

    final diff = _targetEndTime!.difference(DateTime.now()).inSeconds;

    if (diff > 0) {
      emit(state.copyWith(remainingSeconds: diff));
    } else {
      _ticker?.cancel();
      _ticker = null;
      _targetEndTime = null;
      _onSessionComplete();
    }
  }

  Future<void> _onSessionComplete() async {
    emit(state.copyWith(remainingSeconds: 0, timerStatus: DesktopTimerStatus.idle));
    try {
      await _focusRepo.recordCompletedFocusSession(state.selectedDurationMinutes);
    } catch (e) {
      log('DesktopFocusCubit: Error recording session: $e');
    }
    emit(state.copyWith(remainingSeconds: state.selectedDurationMinutes * 60));
  }

  // ===========================================================================
  // â° Ø¥Ø¯Ø§Ø±Ø© Ø§Ù„Ù…Ù†Ø¨Ù‡Ø§Øª (Alarms Scheduler)
  // ===========================================================================

  Future<void> addAlarm({
    required int hour,
    required int minute,
    String label = 'Focus Alarm',
  }) async {
    try {
      await _focusRepo.createAlarm(
        hour: hour,
        minute: minute,
        label: label.trim().isEmpty ? 'Focus Alarm' : label.trim(),
      );
    } catch (e) {
      log('DesktopFocusCubit: Error adding alarm: $e');
      emit(state.copyWith(errorMessage: 'Failed to create alarm: $e'));
    }
  }

  Future<void> toggleAlarm(Alarm alarm) async {
    try {
      await _focusRepo.toggleAlarm(alarm);
    } catch (e) {
      log('DesktopFocusCubit: Error toggling alarm: $e');
    }
  }

  Future<void> deleteAlarm(Alarm alarm) async {
    try {
      await _focusRepo.deleteAlarm(alarm.id);
    } catch (e) {
      log('DesktopFocusCubit: Error deleting alarm: $e');
    }
  }

  String getRelativeAlarmTime(int hour, int minute) {
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    var alarmMinutes = hour * 60 + minute;

    var diffMinutes = alarmMinutes - currentMinutes;
    if (diffMinutes <= 0) diffMinutes += 24 * 60;

    final h = diffMinutes ~/ 60;
    final m = diffMinutes % 60;

    if (h == 0) return 'Rings in $m minutes';
    if (m == 0) return 'Rings in $h hours';
    return 'Rings in $h hours and $m minutes';
  }

  @override
  Future<void> close() {
    _ticker?.cancel();
    _alarmsSub?.cancel();
    _sessionsSub?.cancel();
    return super.close();
  }
}
