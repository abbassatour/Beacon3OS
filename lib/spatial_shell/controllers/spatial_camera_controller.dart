// lib/spatial_shell/controllers/spatial_camera_controller.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:beacon_os/core/audio/sound_controller.dart';
import 'package:beacon_os/core/haptics/haptic_manager.dart';
import 'package:beacon_os/core/physics/spatial_physics.dart';
import 'package:beacon_os/core/topology/topology.dart';
import 'package:beacon_os/spatial_shell/cubit/spatial_shell_state.dart';
import 'package:flutter/widgets.dart';

/// منسق ومحرك فيزياء الكاميرا الفضائية والرادار الصوتي المستمر.
class SpatialCameraController extends ChangeNotifier {
  SpatialCameraController({required TickerProvider vsync}) {
    _panX = AnimationController.unbounded(vsync: vsync)
      ..addListener(notifyListeners);
    _panY = AnimationController.unbounded(vsync: vsync)
      ..addListener(notifyListeners);
    _floorZ = AnimationController.unbounded(vsync: vsync, value: 0.0)
      ..addListener(notifyListeners);
  }

  late final AnimationController _panX;
  late final AnimationController _panY;
  late final AnimationController _floorZ;

  bool _isTwoFingerElevator = false;
  bool _isTransitioningViaGesture = false;
  Axis? _lockedAxis;

  double _initialScale = 0.0;
  double _startXAtGesture = 0.0;
  double _startYAtGesture = 0.0;

  double _accumulatedDeltaX = 0.0;
  double _accumulatedDeltaY = 0.0;

  bool _hapticDetentFired = false;
  bool _boundaryBumpFired = false;

  Timer? _scrubbingDebounceTimer;
  SpatialDirection? _lastScrubbedDirection;

  // Getters
  double get currentZ => _floorZ.value;
  Offset get panOffset => Offset(_panX.value, _panY.value);
  bool get isGestureActive => _lockedAxis != null || _isTwoFingerElevator;

  void onScaleStart(ScaleStartDetails details, {required int floorLevel}) {
    _panX.stop();
    _panY.stop();
    _floorZ.stop();

    _isTwoFingerElevator = details.pointerCount >= 2;
    _lockedAxis = null;
    _initialScale = _floorZ.value;
    _startXAtGesture = _panX.value;
    _startYAtGesture = _panY.value;
    _accumulatedDeltaX = 0.0;
    _accumulatedDeltaY = 0.0;
    _hapticDetentFired = false;
    _boundaryBumpFired = false;
    _lastScrubbedDirection = null;

    if (!_isTwoFingerElevator && details.pointerCount < 3) {
      SoundController.instance.startSpatialRadar(floorLevel: floorLevel);
    }
  }

  void onScaleUpdate({
    required ScaleUpdateDetails details,
    required SpatialShellState state,
    required SpatialTopology topology,
    required Size screenSize,
    required bool isInnerListScrolling,
    required ValueChanged<SpatialDirection> onWhisperDirection,
  }) {
    // 1. مصعد الطوابق الرأسي (Z-Axis)
    if (details.pointerCount >= 2) {
      _isTwoFingerElevator = true;
      final minFloor = topology.minFloor.toDouble();
      final maxFloor = topology.maxFloor.toDouble();

      final scaleDelta = (details.scale - 1.0) * 1.5;
      final rawZ = _initialScale + scaleDelta;

      double computedZ;
      if (rawZ < minFloor) {
        final excess = minFloor - rawZ;
        computedZ = minFloor -
            SpatialPhysics.applyRubberBanding(
              delta: excess,
              limit: 0.20,
            );
        if (excess > 0.05 && !_boundaryBumpFired) {
          _boundaryBumpFired = true;
          SoundController.instance.playBoundaryBump();
          HapticManager.instance.selectionClick();
        }
      } else if (rawZ > maxFloor) {
        final excess = rawZ - maxFloor;
        computedZ = maxFloor +
            SpatialPhysics.applyRubberBanding(
              delta: excess,
              limit: 0.20,
            );
        if (excess > 0.05 && !_boundaryBumpFired) {
          _boundaryBumpFired = true;
          SoundController.instance.playBoundaryBump();
          HapticManager.instance.selectionClick();
        }
      } else {
        computedZ = rawZ;
        _boundaryBumpFired = false;
      }

      _floorZ.value = computedZ;

      final currentBaseFloor = _floorZ.value.floorToDouble();
      final midPoint = currentBaseFloor + 0.50;

      if ((_floorZ.value >= midPoint && _initialScale < midPoint) ||
          (_floorZ.value <= midPoint && _initialScale >= midPoint)) {
        if (!_hapticDetentFired) {
          HapticManager.instance.selectionClick();
          _hapticDetentFired = true;
        }
      } else if ((_floorZ.value < midPoint - 0.15 && _initialScale < midPoint) ||
          (_floorZ.value > midPoint + 0.15 && _initialScale >= midPoint)) {
        _hapticDetentFired = false;
      }
      return;
    }

    if (_isTwoFingerElevator && details.pointerCount < 2) return;

    // 2. الملاحة الأفقية وفك تعارض القوائم
    final dx = details.focalPointDelta.dx;
    final dy = details.focalPointDelta.dy;

    _accumulatedDeltaX += dx;
    _accumulatedDeltaY += dy;

    const touchSlopThreshold = 8.0;
    if (_lockedAxis == null) {
      if (_accumulatedDeltaX.abs() > touchSlopThreshold ||
          _accumulatedDeltaY.abs() > touchSlopThreshold) {
        _lockedAxis = _accumulatedDeltaX.abs() > _accumulatedDeltaY.abs()
            ? Axis.horizontal
            : Axis.vertical;
      } else {
        return;
      }
    }

    if (state.currentCoordinate.isOrigin &&
        _lockedAxis == Axis.vertical &&
        isInnerListScrolling) {
      return;
    }

    // 📐 حساب الحدود الديناميكية للغرف المأهولة المسجلة في الطوبولوجيا
    if (_lockedAxis == Axis.horizontal) {
      final rawVal = _startXAtGesture + _accumulatedDeltaX;
      final currentTargetX = -state.currentCoordinate.x * screenSize.width;

      final eastNeighbor = topology.findNextOccupiedInDirection(
        origin: state.currentCoordinate,
        direction: SpatialDirection.east,
      );
      final westNeighbor = topology.findNextOccupiedInDirection(
        origin: state.currentCoordinate,
        direction: SpatialDirection.west,
      );

      final minLimitX = eastNeighbor != null
          ? -eastNeighbor.x * screenSize.width
          : currentTargetX;
      final maxLimitX = westNeighbor != null
          ? -westNeighbor.x * screenSize.width
          : currentTargetX;

      final lowerBound = math.min(minLimitX, maxLimitX);
      final upperBound = math.max(minLimitX, maxLimitX);

      var isWall = false;
      var wallLimit = 0.0;

      if (rawVal < lowerBound) {
        isWall = true;
        wallLimit = lowerBound;
      } else if (rawVal > upperBound) {
        isWall = true;
        wallLimit = upperBound;
      }

      if (isWall) {
        final excess = rawVal - wallLimit;
        _panX.value = wallLimit +
            SpatialPhysics.applyRubberBanding(
              delta: excess,
              limit: screenSize.width,
            );

        if (excess.abs() > 14.0 && !_boundaryBumpFired) {
          _boundaryBumpFired = true;
          SoundController.instance.playBoundaryBump();
          HapticManager.instance.selectionClick();
        }
      } else {
        _panX.value = rawVal;
        _boundaryBumpFired = false;
      }

      final dragDistance = (_panX.value - _startXAtGesture).abs();
      final hapticThreshold = screenSize.width * 0.50;
      if (dragDistance >= hapticThreshold) {
        if (!_hapticDetentFired) {
          HapticManager.instance.selectionClick();
          _hapticDetentFired = true;
        }
      } else if (dragDistance < hapticThreshold * 0.85) {
        _hapticDetentFired = false;
      }
    } else if (_lockedAxis == Axis.vertical) {
      final rawVal = _startYAtGesture + _accumulatedDeltaY;
      final currentTargetY = state.currentCoordinate.y * screenSize.height;

      final northNeighbor = topology.findNextOccupiedInDirection(
        origin: state.currentCoordinate,
        direction: SpatialDirection.north,
      );
      final southNeighbor = topology.findNextOccupiedInDirection(
        origin: state.currentCoordinate,
        direction: SpatialDirection.south,
      );

      final maxLimitY = northNeighbor != null
          ? northNeighbor.y * screenSize.height
          : currentTargetY;
      final minLimitY = southNeighbor != null
          ? southNeighbor.y * screenSize.height
          : currentTargetY;

      final lowerBound = math.min(minLimitY, maxLimitY);
      final upperBound = math.max(minLimitY, maxLimitY);

      var isWall = false;
      var wallLimit = 0.0;

      if (rawVal < lowerBound) {
        isWall = true;
        wallLimit = lowerBound;
      } else if (rawVal > upperBound) {
        isWall = true;
        wallLimit = upperBound;
      }

      if (isWall) {
        final excess = rawVal - wallLimit;
        _panY.value = wallLimit +
            SpatialPhysics.applyRubberBanding(
              delta: excess,
              limit: screenSize.height,
            );

        if (excess.abs() > 14.0 && !_boundaryBumpFired) {
          _boundaryBumpFired = true;
          SoundController.instance.playBoundaryBump();
          HapticManager.instance.selectionClick();
        }
      } else {
        _panY.value = rawVal;
        _boundaryBumpFired = false;
      }

      final dragDistance = (_panY.value - _startYAtGesture).abs();
      final hapticThreshold = screenSize.height * 0.50;
      if (dragDistance >= hapticThreshold) {
        if (!_hapticDetentFired) {
          HapticManager.instance.selectionClick();
          _hapticDetentFired = true;
        }
      } else if (dragDistance < hapticThreshold * 0.85) {
        _hapticDetentFired = false;
      }
    }

    // 3. تحديث الرادار الصوتي والهمس
    final currentTargetX = -state.currentCoordinate.x * screenSize.width;
    final currentTargetY = state.currentCoordinate.y * screenSize.height;
    final normalizedX = -((_panX.value - currentTargetX) / screenSize.width);
    final normalizedY = ((_panY.value - currentTargetY) / screenSize.height);

    SoundController.instance.updateSpatialRadar(
      normalizedX: normalizedX,
      normalizedY: normalizedY,
      floorLevel: state.currentFloor,
    );

    SpatialDirection? targetDirection;
    if (normalizedX > 0.35) {
      targetDirection = SpatialDirection.east;
    } else if (normalizedX < -0.35) {
      targetDirection = SpatialDirection.west;
    } else if (normalizedY > 0.35) {
      targetDirection = SpatialDirection.north;
    } else if (normalizedY < -0.35) {
      targetDirection = SpatialDirection.south;
    }

    if (targetDirection != null && targetDirection != _lastScrubbedDirection) {
      _lastScrubbedDirection = targetDirection;
      _scrubbingDebounceTimer?.cancel();
      _scrubbingDebounceTimer = Timer(const Duration(milliseconds: 200), () {
        onWhisperDirection(targetDirection!);
      });
    } else if (targetDirection == null) {
      _lastScrubbedDirection = null;
      _scrubbingDebounceTimer?.cancel();
    }
  }

  void onScaleEnd({
    required ScaleEndDetails details,
    required SpatialShellState state,
    required SpatialTopology topology,
    required Size screenSize,
    required ValueChanged<SpatialCoordinate> onTargetCoordinateSelected,
    required ValueChanged<int> onTargetFloorSelected,
  }) {
    SoundController.instance.stopSpatialRadar();
    _scrubbingDebounceTimer?.cancel();
    _lastScrubbedDirection = null;

    if (_isTwoFingerElevator) {
      _isTwoFingerElevator = false;
      _isTransitioningViaGesture = true;

      final minFloor = topology.minFloor;
      final maxFloor = topology.maxFloor;

      final scaleVel = details.scaleVelocity;
      final vz = (scaleVel * 1.5).clamp(-4.0, 4.0);
      final velocityBias = vz.clamp(-1.5, 1.5) * 0.35;
      final projectedZ = _floorZ.value + velocityBias;

      int targetFloor;
      final deltaFromInitial = _floorZ.value - _initialScale;

      if (deltaFromInitial > 0.40 || vz > 0.5) {
        targetFloor = (_initialScale + 1).round();
      } else if (deltaFromInitial < -0.40 || vz < -0.5) {
        targetFloor = (_initialScale - 1).round();
      } else {
        targetFloor = projectedZ.round();
      }

      targetFloor = targetFloor.clamp(minFloor, maxFloor);
      final targetZ = targetFloor.toDouble();

      _floorZ
          .animateWith(
        SpatialPhysics.createZAxisSimulation(
          start: _floorZ.value,
          end: targetZ,
          velocity: vz,
        ),
      )
          .whenComplete(() {
        _isTransitioningViaGesture = false;
        notifyListeners();
      });

      if (targetFloor != state.currentFloor) {
        onTargetFloorSelected(targetFloor);
      }
      return;
    }

    // 🎯 الجاذبية المكانية الذكية
    const distanceThresholdPercent = 0.50;
    const velocityThreshold = 220.0;

    if (_lockedAxis == Axis.horizontal) {
      final vx = details.velocity.pixelsPerSecond.dx;
      final currentTargetX = -state.currentCoordinate.x * screenSize.width;
      final deltaFromTarget = _panX.value - currentTargetX;

      SpatialCoordinate? targetCoord;

      if (deltaFromTarget < -screenSize.width * distanceThresholdPercent ||
          vx < -velocityThreshold) {
        targetCoord = topology.findNextOccupiedInDirection(
          origin: state.currentCoordinate,
          direction: SpatialDirection.east,
        );
      } else if (deltaFromTarget > screenSize.width * distanceThresholdPercent ||
          vx > velocityThreshold) {
        targetCoord = topology.findNextOccupiedInDirection(
          origin: state.currentCoordinate,
          direction: SpatialDirection.west,
        );
      }

      final destination = targetCoord ?? state.currentCoordinate;
      final finalX = -destination.x * screenSize.width;
      final finalY = destination.y * screenSize.height;

      _panX.animateWith(
        SpatialPhysics.createPanSimulation(
          start: _panX.value,
          end: finalX,
          velocity: vx,
        ),
      );
      _panY.animateWith(
        SpatialPhysics.createPanSimulation(
          start: _panY.value,
          end: finalY,
          velocity: 0,
        ),
      );

      if (destination != state.currentCoordinate) {
        onTargetCoordinateSelected(destination);
      } else if (targetCoord == null &&
          (deltaFromTarget.abs() > screenSize.width * 0.25 || vx.abs() > 180)) {
        SoundController.instance.playBoundaryBump();
      }
    } else if (_lockedAxis == Axis.vertical) {
      final vy = details.velocity.pixelsPerSecond.dy;
      final currentTargetY = state.currentCoordinate.y * screenSize.height;
      final deltaFromTarget = _panY.value - currentTargetY;

      SpatialCoordinate? targetCoord;

      if (deltaFromTarget > screenSize.height * distanceThresholdPercent ||
          vy > velocityThreshold) {
        targetCoord = topology.findNextOccupiedInDirection(
          origin: state.currentCoordinate,
          direction: SpatialDirection.north,
        );
      } else if (deltaFromTarget < -screenSize.height * distanceThresholdPercent ||
          vy < -velocityThreshold) {
        targetCoord = topology.findNextOccupiedInDirection(
          origin: state.currentCoordinate,
          direction: SpatialDirection.south,
        );
      }

      final destination = targetCoord ?? state.currentCoordinate;
      final finalX = -destination.x * screenSize.width;
      final finalY = destination.y * screenSize.height;

      _panY.animateWith(
        SpatialPhysics.createPanSimulation(
          start: _panY.value,
          end: finalY,
          velocity: vy,
        ),
      );
      _panX.animateWith(
        SpatialPhysics.createPanSimulation(
          start: _panX.value,
          end: finalX,
          velocity: 0,
        ),
      );

      if (destination != state.currentCoordinate) {
        onTargetCoordinateSelected(destination);
      } else if (targetCoord == null &&
          (deltaFromTarget.abs() > screenSize.height * 0.25 || vy.abs() > 180)) {
        SoundController.instance.playBoundaryBump();
      }
    } else {
      snapToCoordinate(state.currentCoordinate, screenSize);
    }

    _lockedAxis = null;
  }

  void snapToCoordinate(SpatialCoordinate coord, Size screenSize) {
    final tx = -coord.x * screenSize.width;
    final ty = coord.y * screenSize.height;

    _panX.animateWith(
      SpatialPhysics.createPanSimulation(
        start: _panX.value,
        end: tx,
        velocity: 0,
      ),
    );
    _panY.animateWith(
      SpatialPhysics.createPanSimulation(
        start: _panY.value,
        end: ty,
        velocity: 0,
      ),
    );
  }

  void animateToFloor(int targetFloor) {
    if (_isTransitioningViaGesture) return;
    final targetZ = targetFloor.toDouble();
    if ((_floorZ.value - targetZ).abs() > 0.001) {
      _floorZ.animateWith(
        SpatialPhysics.createZAxisSimulation(
          start: _floorZ.value,
          end: targetZ,
          velocity: 0,
        ),
      );
    }
  }

  @override
  void dispose() {
    _scrubbingDebounceTimer?.cancel();
    _panX.dispose();
    _panY.dispose();
    _floorZ.dispose();
    super.dispose();
  }
}