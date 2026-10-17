// lib/tv/cards/alarms/cubit/tv_alarms_cubit.dart
import 'dart:async';
import 'dart:developer';

import 'package:beacon_os/core/audio/sound_controller.dart';
import 'package:beacon_os/core/audio/sound_cue.dart';
import 'package:beacon_os/tv/cards/alarms/cubit/tv_alarms_state.dart';
import 'package:bloc/bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';

class TvAlarmsCubit extends Cubit<TvAlarmsState> {
  TvAlarmsCubit({
    required FocusAlarmsRepository focusAlarmsRepository,
    SoundController? soundController,
  })  : _focusRepo = focusAlarmsRepository,
        _sound = soundController ?? SoundController.instance,
        super(const TvAlarmsState()) {
    _initAlarmsStream();
  }

  final FocusAlarmsRepository _focusRepo;
  final SoundController _sound;
  StreamSubscription<List<AlarmEntity>>? _alarmsSubscription;

  void _initAlarmsStream() {
    emit(state.copyWith(status: TvAlarmsStatus.loading));

    _alarmsSubscription = _focusRepo.watchAlarms().listen(
      (alarmsList) {
        final upcoming = _computeNextUpcomingAlarm(alarmsList);
        emit(
          state.copyWith(
            status: TvAlarmsStatus.success,
            alarms: alarmsList,
            nextAlarm: upcoming,
            clearNextAlarm: upcoming == null,
          ),
        );
      },
      onError: (Object error) {
        log('TvAlarmsCubit: Error watching alarms: $error');
        emit(
          state.copyWith(
            status: TvAlarmsStatus.error,
            errorMessage: error.toString(),
          ),
        );
      },
    );
  }

  AlarmEntity? _computeNextUpcomingAlarm(List<AlarmEntity> alarms) {
    final activeAlarms = alarms.where((a) => a.isActive).toList();
    if (activeAlarms.isEmpty) return null;

    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    activeAlarms.sort((a, b) {
      var diffA = (a.hour * 60 + a.minute) - currentMinutes;
      if (diffA <= 0) diffA += 24 * 60;

      var diffB = (b.hour * 60 + b.minute) - currentMinutes;
      if (diffB <= 0) diffB += 24 * 60;

      return diffA.compareTo(diffB);
    });

    return activeAlarms.first;
  }

  Future<void> toggleAlarm(AlarmEntity alarm) async {
    try {
      await _sound.play(SoundCue.navCenter);
      await _focusRepo.toggleAlarm(alarm);
    } catch (e) {
      log('TvAlarmsCubit: Error toggling alarm: $e');
      emit(state.copyWith(errorMessage: 'Failed to toggle alarm: $e'));
    }
  }

  @override
  Future<void> close() {
    _alarmsSubscription?.cancel();
    return super.close();
  }
}