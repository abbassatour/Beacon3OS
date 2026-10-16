// lib/tv/cards/safety/cubit/tv_safety_cubit.dart
import 'dart:async';
import 'dart:developer';

import 'package:beacon_os/core/audio/sound_controller.dart';
import 'package:beacon_os/core/audio/sound_cue.dart';
import 'package:beacon_os/tv/cards/safety/cubit/tv_safety_state.dart';
import 'package:bloc/bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';

class TvSafetyCubit extends Cubit<TvSafetyState> {
  TvSafetyCubit({
    required CommsRepository commsRepository,
    SoundController? soundController,
  })  : _commsRepo = commsRepository,
        _sound = soundController ?? SoundController.instance,
        super(const TvSafetyState());

  final CommsRepository _commsRepo;
  final SoundController _sound;
  Timer? _broadcastCooldownTimer;

  static const Duration _cooldownDuration = Duration(seconds: 5);

  Future<void> triggerEmergencySos() async {
    if (state.isBroadcasting) return;

    emit(state.copyWith(
      status: TvSafetyStatus.broadcasting,
      clearErrorMessage: true,
    ));

    await _sound.play(SoundCue.sosAlarm);

    try {
      final alertId = await _commsRepo.triggerEmergencySos();
      emit(state.copyWith(
        status: TvSafetyStatus.success,
        lastSosAlertId: alertId,
      ));
    } catch (e) {
      log('TvSafetyCubit: Error triggering SOS from TV: $e');
      emit(state.copyWith(
        status: TvSafetyStatus.error,
        errorMessage: 'Failed to broadcast SOS: $e',
      ));
    } finally {
      _broadcastCooldownTimer?.cancel();
      _broadcastCooldownTimer = Timer(_cooldownDuration, () {
        if (!isClosed) {
          emit(state.copyWith(status: TvSafetyStatus.idle));
        }
      });
    }
  }

  @override
  Future<void> close() {
    _broadcastCooldownTimer?.cancel();
    return super.close();
  }
}