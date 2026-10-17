// lib/desktop/agenda/cubit/desktop_agenda_state.dart
import 'package:equatable/equatable.dart';
import 'package:launcher_repository/launcher_repository.dart'; // ✅ الاستيراد النقي

enum DesktopAgendaStatus { initial, loading, success, error }

class DesktopAgendaState extends Equatable {
  const DesktopAgendaState({
    this.status = DesktopAgendaStatus.initial,
    this.tasks = const [],
    this.memos = const [],
    this.searchQuery = '',
    this.priorityFilter = 'all',
    this.errorMessage,
  });

  final DesktopAgendaStatus status;
  final List<TaskEntity> tasks; // ✅ الكيان النقي
  final List<VoiceMemoEntity> memos; // ✅ الكيان النقي
  final String searchQuery;
  final String priorityFilter; 
  final String? errorMessage;

  /// المهام قيد الإنجاز مفلترة ومرتبة
  List<TaskEntity> get pendingTasks {
    final pending = tasks.where((t) => !t.isCompleted).toList();

    return pending.where((task) {
      final matchesSearch = searchQuery.isEmpty ||
          task.title.toLowerCase().contains(searchQuery.toLowerCase());
      final matchesPriority =
          priorityFilter == 'all' || task.priority.toLowerCase() == priorityFilter;
      return matchesSearch && matchesPriority;
    }).toList()
      ..sort((a, b) {
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
  }

  /// المهام المكتملة
  List<TaskEntity> get completedTasks {
    final completed = tasks.where((t) => t.isCompleted).toList();

    return completed.where((task) {
      if (searchQuery.isEmpty) return true;
      return task.title.toLowerCase().contains(searchQuery.toLowerCase());
    }).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  /// المذكرات الصوتية
  List<VoiceMemoEntity> get filteredMemos {
    return memos.where((memo) {
      if (searchQuery.isEmpty) return true;
      final q = searchQuery.toLowerCase();
      return memo.title.toLowerCase().contains(q) ||
          memo.content.toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  DesktopAgendaState copyWith({
    DesktopAgendaStatus? status,
    List<TaskEntity>? tasks,
    List<VoiceMemoEntity>? memos,
    String? searchQuery,
    String? priorityFilter,
    String? errorMessage,
  }) {
    return DesktopAgendaState(
      status: status ?? this.status,
      tasks: tasks ?? this.tasks,
      memos: memos ?? this.memos,
      searchQuery: searchQuery ?? this.searchQuery,
      priorityFilter: priorityFilter ?? this.priorityFilter,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        tasks,
        memos,
        searchQuery,
        priorityFilter,
        errorMessage,
      ];
}