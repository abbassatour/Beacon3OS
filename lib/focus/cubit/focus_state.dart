// lib/focus/cubit/focus_state.dart
import 'package:equatable/equatable.dart';
import 'package:local_vault_api/local_vault_api.dart';

enum TimerStatus { idle, running, paused, breakTime }

class FocusState extends Equatable {
  const FocusState({
    this.timerStatus = TimerStatus.idle,
    this.selectedDurationMinutes = 25,
    this.remainingSeconds = 25 * 60,
    this.alarms = const [],
    this.todayCompletedSessions = const [],
  });

  final TimerStatus timerStatus;
  final int selectedDurationMinutes;
  final int remainingSeconds;
  final List<Alarm> alarms;
  final List<FocusSession> todayCompletedSessions;

  bool get isTimerRunning => timerStatus == TimerStatus.running;
  bool get isPaused => timerStatus == TimerStatus.paused;
  bool get isBreakTime => timerStatus == TimerStatus.breakTime;

  /// إجمالي دقائق التركيز المنجزة اليوم
  int get totalFocusMinutesToday =>
      todayCompletedSessions.fold<int>(0, (sum, s) => sum + s.durationMinutes);

  /// نسبة تقدم المؤقت من 0.0 إلى 1.0
  double get progress {
    final totalSec = selectedDurationMinutes * 60;
    if (totalSec == 0) return 0.0;
    return (1.0 - (remainingSeconds / totalSec)).clamp(0.0, 1.0);
  }

  /// الوقت المتبقي بصيغة MM:SS
  String get formattedRemainingTime {
    final mins = (remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (remainingSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  FocusState copyWith({
    TimerStatus? timerStatus,
    int? selectedDurationMinutes,
    int? remainingSeconds,
    List<Alarm>? alarms,
    List<FocusSession>? todayCompletedSessions,
  }) {
    return FocusState(
      timerStatus: timerStatus ?? this.timerStatus,
      selectedDurationMinutes:
          selectedDurationMinutes ?? this.selectedDurationMinutes,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      alarms: alarms ?? this.alarms,
      todayCompletedSessions:
          todayCompletedSessions ?? this.todayCompletedSessions,
    );
  }

  @override
  List<Object?> get props => [
        timerStatus,
        selectedDurationMinutes,
        remainingSeconds,
        alarms,
        todayCompletedSessions,
      ];
}

// 🛡️ اسم توافقي لمنع انكسار أي كود قديم
typedef FocusAlarmsState = FocusState;