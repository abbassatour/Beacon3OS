// lib/tv/cards/alarms/cubit/tv_alarms_state.dart
import 'package:equatable/equatable.dart';
import 'package:local_vault_api/local_vault_api.dart';

enum TvAlarmsStatus { initial, loading, success, error }

class TvAlarmsState extends Equatable {
  const TvAlarmsState({
    this.status = TvAlarmsStatus.initial,
    this.alarms = const [],
    this.nextAlarm,
    this.errorMessage,
  });

  final TvAlarmsStatus status;
  final List<Alarm> alarms;
  final Alarm? nextAlarm;
  final String? errorMessage;

  bool get hasUpcomingAlarm => nextAlarm != null;

  TvAlarmsState copyWith({
    TvAlarmsStatus? status,
    List<Alarm>? alarms,
    Alarm? nextAlarm,
    bool clearNextAlarm = false,
    String? errorMessage,
  }) {
    return TvAlarmsState(
      status: status ?? this.status,
      alarms: alarms ?? this.alarms,
      nextAlarm: clearNextAlarm ? null : (nextAlarm ?? this.nextAlarm),
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, alarms, nextAlarm, errorMessage];
}