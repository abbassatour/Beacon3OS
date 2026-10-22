// lib/tv/cards/locator/cubit/tv_locator_cubit.dart
import 'dart:async';
import 'dart:developer';

import 'package:beacon_os/core/audio/sound_controller.dart';
import 'package:beacon_os/core/audio/sound_cue.dart';
import 'package:beacon_os/tv/cards/locator/cubit/tv_locator_state.dart';
import 'package:bloc/bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';

class TvLocatorCubit extends Cubit<TvLocatorState> {
  TvLocatorCubit({
    required SafetyRadarRepository safetyRadarRepository,
    SoundController? soundController,
  })  : _safetyRadar = safetyRadarRepository,
        _sound = soundController ?? SoundController.instance,
        super(const TvLocatorState());

  final SafetyRadarRepository _safetyRadar;
  final SoundController _sound;
  Timer? _cooldownTimer;

  static const Duration _cooldownDuration = Duration(seconds: 4);

  Future<void> pingPhone({String reason = 'Fire TV living room request'}) async {
    if (state.isPinging) return;

    emit(state.copyWith(
      status: TvLocatorStatus.pinging,
      lastPingedAt: DateTime.now(),
      clearErrorMessage: true,
    ));

    await _sound.play(SoundCue.wake);

    try {
      final isDelivered = await _safetyRadar.requestLocatePhone(reason: reason);

      if (isDelivered) {
        emit(state.copyWith(status: TvLocatorStatus.success));
      } else {
        emit(state.copyWith(
          status: TvLocatorStatus.error,
          errorMessage: 'Locate command was buffered or offline.',
        ));
      }
    } catch (e) {
      log('TvLocatorCubit: Error pinging phone: $e');
      emit(state.copyWith(
        status: TvLocatorStatus.error,
        errorMessage: 'Failed to ping phone: $e',
      ));
    } finally {
      _cooldownTimer?.cancel();
      _cooldownTimer = Timer(_cooldownDuration, () {
        if (!isClosed) {
          emit(state.copyWith(status: TvLocatorStatus.idle));
        }
      });
    }
  }

  @override
  Future<void> close() {
    _cooldownTimer?.cancel();
    return super.close();
  }
}