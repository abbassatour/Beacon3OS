// lib/tv/cards/agenda/cubit/tv_agenda_state.dart
import 'package:equatable/equatable.dart';
import 'package:launcher_repository/launcher_repository.dart'; // ✅ الاستيراد النقي

enum TvAgendaStatus { initial, loading, success, error }

class TvAgendaState extends Equatable {
  const TvAgendaState({
    this.status = TvAgendaStatus.initial,
    this.tasks = const [],
    this.errorMessage,
  });

  final TvAgendaStatus status;
  final List<TaskEntity> tasks; // ✅
  final String? errorMessage;

  bool get isEmpty => tasks.isEmpty;
  bool get isLoading => status == TvAgendaStatus.loading;

  TvAgendaState copyWith({
    TvAgendaStatus? status,
    List<TaskEntity>? tasks,
    String? errorMessage,
  }) {
    return TvAgendaState(
      status: status ?? this.status,
      tasks: tasks ?? this.tasks,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, tasks, errorMessage];
}