// lib/cockpit/cubit/cockpit_state.dart
import 'package:equatable/equatable.dart';
import 'package:local_vault_api/local_vault_api.dart';

enum CockpitStatus { initial, loading, success, error }

class CockpitState extends Equatable {
  const CockpitState({
    this.status = CockpitStatus.initial,
    this.alarms = const [],
    this.tasks = const [],
    this.memos = const [],
    this.batteryStatus = 'Checking battery...',
    this.isBriefingPlaying = false,
    this.errorMessage,
  });

  final CockpitStatus status;
  final List<Alarm> alarms;
  final List<Task> tasks;
  final List<VoiceMemo> memos;
  final String batteryStatus;
  final bool isBriefingPlaying;
  final String? errorMessage;

  /// المهام قيد الإنجاز اليوم مرتبة حسب الأولوية الصارمة (High -> Medium -> Low) ثم موعد الاستحقاق
  List<Task> get pendingTasks {
    final pending = tasks.where((t) => !t.isCompleted).toList();
    pending.sort((a, b) {
      const priorityWeight = {'high': 0, 'medium': 1, 'low': 2};
      final weightA = priorityWeight[a.priority.toLowerCase()] ?? 1;
      final weightB = priorityWeight[b.priority.toLowerCase()] ?? 1;

      if (weightA != weightB) {
        return weightA.compareTo(weightB);
      }
      if (a.dueDate != null && b.dueDate != null) {
        return a.dueDate!.compareTo(b.dueDate!);
      }
      return a.dueDate != null ? -1 : (b.dueDate != null ? 1 : 0);
    });
    return pending;
  }

  /// المنبه النشط القادم الأقرب زمنياً في المستقبل (مع حساب دورة الـ 24 ساعة بدقة)
  Alarm? get nextAlarm {
    final active = alarms.where((a) => a.isActive).toList();
    if (active.isEmpty) return null;

    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    active.sort((a, b) {
      var diffA = (a.hour * 60 + a.minute) - currentMinutes;
      if (diffA <= 0) diffA += 24 * 60; // إذا انقضى وقته اليوم، فالرنين القادم غداً

      var diffB = (b.hour * 60 + b.minute) - currentMinutes;
      if (diffB <= 0) diffB += 24 * 60;

      return diffA.compareTo(diffB);
    });

    return active.first;
  }

  /// أحدث مذكرة أو ملاحظة تم تدوينها
  VoiceMemo? get latestMemo => memos.isNotEmpty ? memos.first : null;

  CockpitState copyWith({
    CockpitStatus? status,
    List<Alarm>? alarms,
    List<Task>? tasks,
    List<VoiceMemo>? memos,
    String? batteryStatus,
    bool? isBriefingPlaying,
    String? errorMessage,
  }) {
    return CockpitState(
      status: status ?? this.status,
      alarms: alarms ?? this.alarms,
      tasks: tasks ?? this.tasks,
      memos: memos ?? this.memos,
      batteryStatus: batteryStatus ?? this.batteryStatus,
      isBriefingPlaying: isBriefingPlaying ?? this.isBriefingPlaying,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        alarms,
        tasks,
        memos,
        batteryStatus,
        isBriefingPlaying,
        errorMessage,
      ];
}

// 🛡️ اسم توافقي لمنع انكسار أي كود قديم
typedef CockpitDashboardState = CockpitState;