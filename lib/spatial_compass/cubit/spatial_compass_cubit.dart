// lib/spatial_compass/cubit/spatial_compass_cubit.dart
import 'dart:async';
import 'dart:developer';
import 'package:beacon_os/core/audio/sound_controller.dart';
import 'package:beacon_os/core/audio/sound_cue.dart';
import 'package:beacon_os/core/haptics/haptic_manager.dart';
import 'package:beacon_os/core/spatial_kernel/spatial_topology.dart';
import 'package:beacon_os/spatial_compass/cubit/spatial_compass_state.dart';
import 'package:bloc/bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';

class SpatialCompassCubit extends Cubit<SpatialCompassState> {
  SpatialCompassCubit({
    required AssistantRepository assistantRepository,
    required SpatialTopology topology,
    HapticManager? hapticManager,
    SoundController? soundController,
  })  : _assistant = assistantRepository,
        _topology = topology,
        _haptics = hapticManager ?? HapticManager.instance,
        _sound = soundController ?? SoundController.instance,
        super(const SpatialCompassState());

  final AssistantRepository _assistant;
  final SpatialTopology _topology;
  final HapticManager _haptics;
  final SoundController _sound;

  // ===========================================================================
  // 🏢 1. التحكم الرأسي متعدد الطوابق (Dynamic Z-Axis Vertical Control)
  // ===========================================================================

  /// الصعود طابقاً واحداً للأعلى إن وُجد في الخريطة
  Future<void> ascend() async {
    final nextFloor = state.currentFloor + 1;
    if (!_topology.hasFloor(nextFloor)) return;
    await jumpToFloor(nextFloor);
  }

  /// الهبوط طابقاً واحداً للأسفل إن وُجد في الخريطة
  Future<void> descend() async {
    final nextFloor = state.currentFloor - 1;
    if (!_topology.hasFloor(nextFloor)) return;
    await jumpToFloor(nextFloor);
  }

  /// الانتقال المباشر لأي طابق مسجل في النظام مع إطلاق النغمة المناسبة والاهتزاز
  Future<void> jumpToFloor(int targetFloor) async {
    if (state.currentFloor == targetFloor) return;
    if (!_topology.hasFloor(targetFloor)) return; // 🛡️ حماية ضد الطوابق غير المسجلة

    final isAscending = targetFloor > state.currentFloor;
    final cue = isAscending ? SoundCue.elevatorUp : SoundCue.elevatorDown;

    // ⚡️ إطلاق متزامن وفوري بدون تأخير في نفس فريم انطلاق النابض الفيزيائي
    unawaited(_haptics.successNotification());
    unawaited(_sound.play(cue, floorLevel: targetFloor));

    emit(state.copyWith(currentFloor: targetFloor));
  }

  /// دوال مساعدة للتوافق العكسي
  Future<void> goToSettingsFloor() => jumpToFloor(1);
  Future<void> returnToGroundFloor() => jumpToFloor(0);

  /// التبديل التلقائي: الصعود إن أمكن ذلك، أو الهبوط عند الوصول للقمة
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
          moveTo(CompassDirection.east);
        } else if (velocityX > velocityThreshold || deltaX > distanceThreshold) {
          moveTo(CompassDirection.west);
        }
      } else {
        if (velocityY < -velocityThreshold || deltaY < -distanceThreshold) {
          moveTo(CompassDirection.south);
        } else if (velocityY > velocityThreshold || deltaY > distanceThreshold) {
          moveTo(CompassDirection.north);
        }
      }
    } else {
      final current = state.currentDirection;
      var shouldReturn = false;

      if (current == CompassDirection.north &&
          (velocityY < -velocityThreshold || deltaY < -distanceThreshold)) {
        shouldReturn = true;
      } else if (current == CompassDirection.south &&
          (velocityY > velocityThreshold || deltaY > distanceThreshold)) {
        shouldReturn = true;
      } else if (current == CompassDirection.east &&
          (velocityX > velocityThreshold || deltaX > distanceThreshold)) {
        shouldReturn = true;
      } else if (current == CompassDirection.west &&
          (velocityX < -velocityThreshold || deltaX < -distanceThreshold)) {
        shouldReturn = true;
      }

      if (shouldReturn) {
        returnToCenter();
      }
    }
  }

  Future<void> moveTo(CompassDirection destination) async {
    if (state.currentDirection == destination) return;

    await _haptics.successNotification();

    // 🌟 استدعاء المحرك النغمي ذي الطبقات المتمايزة بحسب الاتجاه والطابق
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
    await moveTo(CompassDirection.center);
  }

  // ===========================================================================
  // 🔊 3. النظام الصوتي الموجه للمكفوفين (On-Demand Contextual TTS)
  // ===========================================================================

  Future<void> announceCurrentLocation() async {
    final module = _topology.moduleAt(state.currentFloor, state.currentDirection);
    final announcement = module?.getFloorTitle(state.currentFloor) ??
        '${state.currentDirection.name.toUpperCase()} Floor ${state.currentFloor}';

    await _assistant.stopSpeaking();
    await _assistant.speak(announcement);
    log('SpatialCompass: Context Requested -> "$announcement"');
  }
}