// lib/desktop/cubit/desktop_agenda_state.dart
import 'package:equatable/equatable.dart';
import 'package:local_vault_api/local_vault_api.dart';

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
  final List<Task> tasks;
  final List<VoiceMemo> memos;
  final String searchQuery;
  final String priorityFilter; // 'all', 'high', 'medium', 'low'
  final String? errorMessage;

  /// Ø§Ù„Ù…Ù‡Ø§Ù… Ù‚ÙŠØ¯ Ø§Ù„Ø¥Ù†Ø¬Ø§Ø² Ù…ÙÙ„ØªØ±Ø© ÙˆÙ…Ø±ØªØ¨Ø© Ø¨Ø¯Ù‚Ø©
  List<Task> get pendingTasks {
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

  /// Ø§Ù„Ù…Ù‡Ø§Ù… Ø§Ù„Ù…ÙƒØªÙ…Ù„Ø© Ù…ÙÙ„ØªØ±Ø© ÙˆÙ…Ø±ØªØ¨Ø© Ù…Ù† Ø§Ù„Ø£Ø­Ø¯Ø« Ø¥Ù†Ø¬Ø§Ø²Ø§Ù‹
  List<Task> get completedTasks {
    final completed = tasks.where((t) => t.isCompleted).toList();

    return completed.where((task) {
      if (searchQuery.isEmpty) return true;
      return task.title.toLowerCase().contains(searchQuery.toLowerCase());
    }).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  /// Ø§Ù„Ù…Ø°ÙƒØ±Ø§Øª Ø§Ù„ØµÙˆØªÙŠØ© Ù…ÙÙ„ØªØ±Ø© ÙˆÙ…Ø±ØªØ¨Ø© Ù…Ù† Ø§Ù„Ø£Ø­Ø¯Ø« Ø¥Ù„Ù‰ Ø§Ù„Ø£Ù‚Ø¯Ù…
  List<VoiceMemo> get filteredMemos {
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
    List<Task>? tasks,
    List<VoiceMemo>? memos,
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
