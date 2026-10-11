// lib/spatial_shell/cubit/spatial_shell_cubit.dart
import 'dart:async';
import 'dart:developer';
import 'package:beacon_os/core/audio/sound_controller.dart';
import 'package:beacon_os/core/audio/sound_cue.dart';
import 'package:beacon_os/core/haptics/haptic_manager.dart';
import 'package:beacon_os/core/topology/topology.dart'; // 👈 تم التصحيح
import 'package:beacon_os/spatial_shell/cubit/spatial_shell_state.dart';
import 'package:bloc/bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';

class SpatialShellCubit extends Cubit<SpatialShellState> {
  SpatialShellCubit({
    required AssistantRepository assistantRepository,
    required SpatialTopology topology,
    HapticManager? hapticManager,
    SoundController? soundController,
  })  : _assistant = assistantRepository,
        _topology = topology,
        _haptics = hapticManager ?? HapticManager.instance,
        _sound = soundController ?? SoundController.instance,
        super(const SpatialShellState());

  final AssistantRepository _assistant;
  final SpatialTopology _topology;
  final HapticManager _haptics;
  final SoundController _sound;

  // ===========================================================================
  // 🏢 1. التحكم الرأسي متعدد الطوابق (Z-Axis Vertical Control)
  // ===========================================================================

  Future<void> ascend() async {
    final nextFloor = state.currentFloor + 1;
    if (!_topology.hasFloor(nextFloor)) return;
    await jumpToFloor(nextFloor);
  }

  Future<void> descend() async {
    final nextFloor = state.currentFloor - 1;
    if (!_topology.hasFloor(nextFloor)) return;
    await jumpToFloor(nextFloor);
  }

  Future<void> jumpToFloor(int targetFloor) async {
    if (state.currentFloor == targetFloor) return;
    if (!_topology.hasFloor(targetFloor)) return;

    final isAscending = targetFloor > state.currentFloor;
    final cue = isAscending ? SoundCue.elevatorUp : SoundCue.elevatorDown;

    unawaited(_haptics.successNotification());
    unawaited(_sound.play(cue, floorLevel: targetFloor));

    emit(state.copyWith(currentFloor: targetFloor));
  }

  Future<void> goToSettingsFloor() => jumpToFloor(1);
  Future<void> returnToGroundFloor() => jumpToFloor(0);

  void toggleFloor() {
    if (_topology.canAscendFrom(state.currentFloor)) {
      ascend();
    } else {
      descend();
    }
  }

  // ===========================================================================
  // 🧭 2. التنقل الأفقي بين الغرف (XY-Axis Pan)
  // ===========================================================================

  void handleSwipeGesture({
    required double velocityX,
    required double velocityY,
    required double deltaX,
    required double deltaY,
  }) {
    const velocityThreshold = 150.0;
    const distanceThreshold = 20.0;

    final isHorizontal = deltaX.abs() > deltaY.abs();

    if (state.isAtCenter) {
      if (isHorizontal) {
        if (velocityX < -velocityThreshold || deltaX < -distanceThreshold) {
          moveTo(SpatialDirection.east);
        } else if (velocityX > velocityThreshold || deltaX > distanceThreshold) {
          moveTo(SpatialDirection.west);
        }
      } else {
        if (velocityY < -velocityThreshold || deltaY < -distanceThreshold) {
          moveTo(SpatialDirection.south);
        } else if (velocityY > velocityThreshold || deltaY > distanceThreshold) {
          moveTo(SpatialDirection.north);
        }
      }
    } else {
      final current = state.currentDirection;
      var shouldReturn = false;

      if (current == SpatialDirection.north &&
          (velocityY < -velocityThreshold || deltaY < -distanceThreshold)) {
        shouldReturn = true;
      } else if (current == SpatialDirection.south &&
          (velocityY > velocityThreshold || deltaY > distanceThreshold)) {
        shouldReturn = true;
      } else if (current == SpatialDirection.east &&
          (velocityX > velocityThreshold || deltaX > distanceThreshold)) {
        shouldReturn = true;
      } else if (current == SpatialDirection.west &&
          (velocityX < -velocityThreshold || deltaX < -distanceThreshold)) {
        shouldReturn = true;
      }

      if (shouldReturn) {
        returnToCenter();
      }
    }
  }

  Future<void> moveTo(SpatialDirection destination) async {
    if (state.currentDirection == destination) return;

    await _haptics.successNotification();

    await _sound.playCompassMove(
      direction: destination,
      floorLevel: state.currentFloor,
    );

    emit(
      state.copyWith(
        previousDirection: state.currentDirection,
        currentDirection: destination,
        isTransitioning: false,
      ),
    );
  }

  Future<void> returnToCenter() async {
    if (state.isAtCenter) return;
    await moveTo(SpatialDirection.center);
  }

  // ===========================================================================
  // 🔊 3. النظام الصوتي الموجه للمكفوفين (On-Demand Contextual TTS)
  // ===========================================================================

  Future<void> announceCurrentLocation() async {
    final module =
        _topology.moduleAt(state.currentFloor, state.currentDirection);
    final announcement = module?.getFloorTitle(state.currentFloor) ??
        '${state.currentDirection.name.toUpperCase()} Floor ${state.currentFloor}';

    await _assistant.stopSpeaking();
    await _assistant.speak(announcement);
    log('SpatialShell: Context Requested -> "$announcement"');
  }
}

// 🛡️ توافق كامل مع الكود السابق
typedef SpatialCompassCubit = SpatialShellCubit;