// lib/tv/cards/agenda/cubit/tv_agenda_cubit.dart
import 'dart:async';
import 'dart:developer';

import 'package:beacon_os/core/audio/sound_controller.dart';
import 'package:beacon_os/core/audio/sound_cue.dart';
import 'package:beacon_os/tv/cards/agenda/cubit/tv_agenda_state.dart';
import 'package:bloc/bloc.dart';
import 'package:launcher_repository/launcher_repository.dart'; // ✅

class TvAgendaCubit extends Cubit<TvAgendaState> {
  TvAgendaCubit({
    required TaskAgendaRepository taskRepository,
    SoundController? soundController,
  })  : _taskRepo = taskRepository,
        _sound = soundController ?? SoundController.instance,
        super(const TvAgendaState()) {
    _initTasksStream();
  }

  final TaskAgendaRepository _taskRepo;
  final SoundController _sound;
  StreamSubscription<List<TaskEntity>>? _tasksSubscription;

  static const int _maxGlanceableTasks = 3;

  void _initTasksStream() {
    emit(state.copyWith(status: TvAgendaStatus.loading));

    _tasksSubscription = _taskRepo.watchTasks().listen(
      (allTasks) {
        final pendingTasks = allTasks
            .where((task) => !task.isCompleted)
            .take(_maxGlanceableTasks)
            .toList();

        emit(
          state.copyWith(
            status: TvAgendaStatus.success,
            tasks: pendingTasks,
          ),
        );
      },
      onError: (Object error) {
        log('TvAgendaCubit: Error watching tasks: $error');
        emit(
          state.copyWith(
            status: TvAgendaStatus.error,
            errorMessage: error.toString(),
          ),
        );
      },
    );
  }

  Future<void> toggleTaskCompletion(TaskEntity task) async {
    try {
      await _sound.play(SoundCue.success);
      await _taskRepo.toggleTask(task);
    } catch (e) {
      log('TvAgendaCubit: Error toggling task: $e');
      emit(state.copyWith(errorMessage: 'Failed to toggle task: $e'));
    }
  }

  @override
  Future<void> close() {
    _tasksSubscription?.cancel();
    return super.close();
  }
}