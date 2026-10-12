// lib/desktop/cubit/desktop_agenda_cubit.dart
import 'dart:async';
import 'dart:developer';

import 'package:beacon_os/desktop/cubit/desktop_agenda_state.dart';
import 'package:bloc/bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';
import 'package:local_vault_api/local_vault_api.dart';

class DesktopAgendaCubit extends Cubit<DesktopAgendaState> {
  DesktopAgendaCubit({
    required TaskAgendaRepository taskRepository,
  })  : _taskRepo = taskRepository,
        super(const DesktopAgendaState()) {
    _initStreams();
  }

  final TaskAgendaRepository _taskRepo;
  StreamSubscription<List<Task>>? _tasksSub;
  StreamSubscription<List<VoiceMemo>>? _memosSub;

  void _initStreams() {
    emit(state.copyWith(status: DesktopAgendaStatus.loading));

    _tasksSub = _taskRepo.watchTasks().listen(
      (tasks) {
        emit(
          state.copyWith(
            status: DesktopAgendaStatus.success,
            tasks: tasks,
          ),
        );
      },
      onError: (Object error) {
        log('DesktopAgendaCubit: Error watching tasks: $error');
        emit(
          state.copyWith(
            status: DesktopAgendaStatus.error,
            errorMessage: error.toString(),
          ),
        );
      },
    );

    _memosSub = _taskRepo.watchMemos().listen(
      (memos) {
        emit(
          state.copyWith(
            status: DesktopAgendaStatus.success,
            memos: memos,
          ),
        );
      },
      onError: (Object error) {
        log('DesktopAgendaCubit: Error watching memos: $error');
      },
    );
  }

  void setSearchQuery(String query) {
    emit(state.copyWith(searchQuery: query.trim()));
  }

  void setPriorityFilter(String filter) {
    emit(state.copyWith(priorityFilter: filter));
  }

  Future<void> addNewTask({
    required String title,
    String priority = 'medium',
    DateTime? dueDate,
  }) async {
    final text = title.trim();
    if (text.isEmpty) return;

    try {
      await _taskRepo.createTask(
        title: text,
        priority: priority,
        dueDate: dueDate,
      );
    } catch (e) {
      log('DesktopAgendaCubit: Error creating task: $e');
      emit(state.copyWith(errorMessage: 'Failed to create task: $e'));
    }
  }

  Future<void> toggleTask(Task task) async {
    try {
      await _taskRepo.toggleTask(task);
    } catch (e) {
      log('DesktopAgendaCubit: Error toggling task: $e');
    }
  }

  Future<void> deleteTask(Task task) async {
    try {
      await _taskRepo.deleteTask(task.id);
    } catch (e) {
      log('DesktopAgendaCubit: Error deleting task: $e');
    }
  }

  Future<void> updateTaskPriority(Task task, String newPriority) async {
    try {
      await _taskRepo.updateTask(
        taskId: task.id,
        priority: newPriority,
      );
    } catch (e) {
      log('DesktopAgendaCubit: Error updating priority: $e');
    }
  }

  Future<void> addNewMemo({
    required String title,
    required String content,
  }) async {
    final t = title.trim();
    final c = content.trim();
    if (t.isEmpty && c.isEmpty) return;

    try {
      await _taskRepo.createMemo(
        title: t.isEmpty ? 'Untitled Note' : t,
        content: c.isEmpty ? t : c,
      );
    } catch (e) {
      log('DesktopAgendaCubit: Error creating memo: $e');
    }
  }

  Future<void> deleteMemo(VoiceMemo memo) async {
    try {
      await _taskRepo.deleteMemo(memo.id);
    } catch (e) {
      log('DesktopAgendaCubit: Error deleting memo: $e');
    }
  }

  @override
  Future<void> close() {
    _tasksSub?.cancel();
    _memosSub?.cancel();
    return super.close();
  }
}