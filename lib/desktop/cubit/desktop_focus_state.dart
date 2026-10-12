// lib/desktop/cubit/desktop_focus_state.dart
import 'package:equatable/equatable.dart';
import 'package:local_vault_api/local_vault_api.dart';

enum DesktopFocusStatus { initial, loading, success, error }
enum DesktopTimerStatus { idle, running, paused }

class DesktopFocusState extends Equatable {
  const DesktopFocusState({
    this.status = DesktopFocusStatus.initial,
    this.timerStatus = DesktopTimerStatus.idle,
    this.selectedDurationMinutes = 25,
    this.remainingSeconds = 25 * 60,
    this.alarms = const [],
    this.todaySessions = const [],
    this.errorMessage,
  });

  final DesktopFocusStatus status;
  final DesktopTimerStatus timerStatus;
  final int selectedDurationMinutes;
  final int remainingSeconds;
  final List<Alarm> alarms;
  final List<FocusSession> todaySessions;
  final String? errorMessage;

  bool get isRunning => timerStatus == DesktopTimerStatus.running;
  bool get isPaused => timerStatus == DesktopTimerStatus.paused;

  /// إجمالي دقائق التركيز المنجزة اليوم
  int get totalFocusMinutesToday =>
      todaySessions.fold<int>(0, (sum, s) => sum + s.durationMinutes);

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

  /// المنبه النشط القادم الأقرب زمنياً
  Alarm? get nextUpcomingAlarm {
    final active = alarms.where((a) => a.isActive).toList();
    if (active.isEmpty) return null;

    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    active.sort((a, b) {
      var diffA = (a.hour * 60 + a.minute) - currentMinutes;
      if (diffA <= 0) diffA += 24 * 60;

      var diffB = (b.hour * 60 + b.minute) - currentMinutes;
      if (diffB <= 0) diffB += 24 * 60;

      return diffA.compareTo(diffB);
    });

    return active.first;
  }

  DesktopFocusState copyWith({
    DesktopFocusStatus? status,
    DesktopTimerStatus? timerStatus,
    int? selectedDurationMinutes,
    int? remainingSeconds,
    List<Alarm>? alarms,
    List<FocusSession>? todaySessions,
    String? errorMessage,
  }) {
    return DesktopFocusState(
      status: status ?? this.status,
      timerStatus: timerStatus ?? this.timerStatus,
      selectedDurationMinutes:
          selectedDurationMinutes ?? this.selectedDurationMinutes,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      alarms: alarms ?? this.alarms,
      todaySessions: todaySessions ?? this.todaySessions,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        timerStatus,
        selectedDurationMinutes,
        remainingSeconds,
        alarms,
        todaySessions,
        errorMessage,
      ];
}