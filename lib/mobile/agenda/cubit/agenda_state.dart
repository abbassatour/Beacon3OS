// lib/agenda/cubit/agenda_state.dart
import 'package:equatable/equatable.dart';
import 'package:local_vault_api/local_vault_api.dart';

enum AgendaStatus { initial, loading, success, error }

class AgendaState extends Equatable {
  const AgendaState({
    this.status = AgendaStatus.initial,
    this.tasks = const [],
    this.memos = const [],
    this.errorMessage,
  });

  final AgendaStatus status;
  final List<Task> tasks;
  final List<VoiceMemo> memos;
  final String? errorMessage;

  /// المهام قيد الإنجاز مرتبة حسب الأولوية الصارمة (High -> Medium -> Low) ثم موعد الاستحقاق الأقرب
  List<Task> get pendingTasks {
    final pending = tasks.where((t) => !t.isCompleted).toList();
    pending.sort((a, b) {
      const priorityWeights = {'high': 0, 'medium': 1, 'low': 2};
      final weightA = priorityWeights[a.priority.toLowerCase()] ?? 1;
      final weightB = priorityWeights[b.priority.toLowerCase()] ?? 1;

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

  /// المهام المكتملة مرتبة من الأحدث إنجازاً إلى الأقدم
  List<Task> get completedTasks {
    final completed = tasks.where((t) => t.isCompleted).toList();
    completed.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return completed;
  }

  /// المذكرات الصوتية مرتبة من الأحدث إلى الأقدم
  List<VoiceMemo> get sortedMemos {
    final list = List<VoiceMemo>.from(memos);
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  AgendaState copyWith({
    AgendaStatus? status,
    List<Task>? tasks,
    List<VoiceMemo>? memos,
    String? errorMessage,
  }) {
    return AgendaState(
      status: status ?? this.status,
      tasks: tasks ?? this.tasks,
      memos: memos ?? this.memos,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, tasks, memos, errorMessage];
}