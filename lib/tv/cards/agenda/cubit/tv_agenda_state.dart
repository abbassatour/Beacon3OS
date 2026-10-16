// lib/tv/cards/agenda/cubit/tv_agenda_state.dart
import 'package:equatable/equatable.dart';
import 'package:local_vault_api/local_vault_api.dart';

enum TvAgendaStatus { initial, loading, success, error }

class TvAgendaState extends Equatable {
  const TvAgendaState({
    this.status = TvAgendaStatus.initial,
    this.tasks = const [],
    this.errorMessage,
  });

  final TvAgendaStatus status;
  final List<Task> tasks;
  final String? errorMessage;

  bool get isEmpty => tasks.isEmpty;
  bool get isLoading => status == TvAgendaStatus.loading;

  TvAgendaState copyWith({
    TvAgendaStatus? status,
    List<Task>? tasks,
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