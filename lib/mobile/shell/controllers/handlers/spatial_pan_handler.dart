// lib/mobile/shell/controllers/handlers/spatial_pan_handler.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:beacon_os/core/audio/sound_controller.dart';
import 'package:beacon_os/core/haptics/haptic_manager.dart';
import 'package:beacon_os/core/physics/spatial_physics.dart';
import 'package:beacon_os/core/topology/topology.dart';
import 'package:beacon_os/mobile/shell/cubit/spatial_shell_state.dart';
import 'package:flutter/widgets.dart';

/// معالج فيزياء السحب والتنقل الديكارتي بإصبعين بين الغرف (XY-Axis 2-Finger Pan & Audio Radar).
/// يدعم التوجيه الزاوي المرن، كسر القفل الحركي (Hysteresis Breakout)، والتحرير عند المركز.
class SpatialPanHandler {
  SpatialPanHandler({
    SoundController? soundController,
    HapticManager? hapticManager,
  })  : _sound = soundController ?? SoundController.instance,
        _haptics = hapticManager ?? HapticManager.instance;

  final SoundController _sound;
  final HapticManager _haptics;

  Axis? _lockedAxis;

  double _startXAtGesture = 0.0;
  double _startYAtGesture = 0.0;
  double _accumulatedDeltaX = 0.0;
  double _accumulatedDeltaY = 0.0;

  bool _boundaryBumpFired = false;
  bool _hapticDetentFired = false;

  Timer? _scrubbingDebounceTimer;
  SpatialDirection? _lastScrubbedDirection;

  // 🎯 عتبات التوجيه الزاوي وكسر القفل
  static const double _initialTouchSlop = 9.0;
  static const double _breakoutThreshold = 22.0;
  static const double _originResetThreshold = 6.0;
  static const double _dominanceRatio = 1.35;

  Axis? get lockedAxis => _lockedAxis;

  /// تهيئة الجلسة عند بدء السحب بإصبعين
  void onScaleStart({
    required double startPanX,
    required double startPanY,
    required int floorLevel,
  }) {
    _lockedAxis = null;
    _startXAtGesture = startPanX;
    _startYAtGesture = startPanY;
    _accumulatedDeltaX = 0.0;
    _accumulatedDeltaY = 0.0;
    _boundaryBumpFired = false;
    _hapticDetentFired = false;
    _lastScrubbedDirection = null;
    _scrubbingDebounceTimer?.cancel();

    _sound.startSpatialRadar(floorLevel: floorLevel);
  }

  /// معالجة حركة السحب اللحظية بإصبعين مع القفل الديناميكي ودعم التراجع والكسر
  ({double? newPanX, double? newPanY}) handlePanUpdate({
    required Offset focalPointDelta,
    required double currentPanX,
    required double currentPanY,
    required SpatialShellState state,
    required SpatialTopology topology,
    required Size screenSize,
    required ValueChanged<SpatialDirection> onWhisperDirection,
    required bool isWhisperEnabled,
  }) {
    _accumulatedDeltaX += focalPointDelta.dx;
    _accumulatedDeltaY += focalPointDelta.dy;

    final absX = _accumulatedDeltaX.abs();
    final absY = _accumulatedDeltaY.abs();

    // 🔄 1. ميزة التحرير التلقائي: إذا عاد المستخدم قريباً من نقطة البداية، يُفك القفل
    if (_lockedAxis != null) {
      final currentDistFromOrigin = math.sqrt(
        _accumulatedDeltaX * _accumulatedDeltaX +
            _accumulatedDeltaY * _accumulatedDeltaY,
      );
      if (currentDistFromOrigin < _originResetThreshold) {
        _lockedAxis = null;
        _boundaryBumpFired = false;
        _hapticDetentFired = false;
      }
    }

    // ⚡ 2. ميزة كسر القفل (Breakout Hysteresis): تصحيح المسار المتعمد بحركة قوية في المحور الآخر
    if (_lockedAxis == Axis.horizontal) {
      if (absY > _breakoutThreshold && absY > absX * 1.5) {
        _lockedAxis = Axis.vertical;
        _boundaryBumpFired = false;
        _hapticDetentFired = false;
        _haptics.selectionClick(); // إشعار حسي بالانتقال للمحور الجديد
      }
    } else if (_lockedAxis == Axis.vertical) {
      if (absX > _breakoutThreshold && absX > absY * 1.5) {
        _lockedAxis = Axis.horizontal;
        _boundaryBumpFired = false;
        _hapticDetentFired = false;
        _haptics.selectionClick(); // إشعار حسي بالانتقال للمحور الجديد
      }
    }

    // 🧭 3. تحديد المحور الأولي إذا كان القفل غير محسوم (Initial Lock Decision)
    if (_lockedAxis == null) {
      if (absX >= _initialTouchSlop || absY >= _initialTouchSlop) {
        if (absY > absX * _dominanceRatio) {
          _lockedAxis = Axis.vertical;
        } else if (absX > absY * _dominanceRatio) {
          _lockedAxis = Axis.horizontal;
        } else if (absX >= _initialTouchSlop * 1.6 ||
            absY >= _initialTouchSlop * 1.6) {
          // حركة واضحة قطرياً: اختيار المحور الأكبر نسبياً
          _lockedAxis = absY > absX ? Axis.vertical : Axis.horizontal;
        } else {
          // لا يزال في المنطقة المحايدة (Ambiguous Cone) -> لا نحرك بعد
          return (newPanX: null, newPanY: null);
        }
      } else {
        return (newPanX: null, newPanY: null);
      }
    }

    double? updatedPanX;
    double? updatedPanY;

    // -------------------------------------------------------------------------
    // 4. تنفيذ السحب الأفقي (شرق / غرب)
    // -------------------------------------------------------------------------
    if (_lockedAxis == Axis.horizontal) {
      // تثبيت المحور الرأسي المعاكس على نقطة الأصل لمنع الانحراف
      updatedPanY = _startYAtGesture;

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
        updatedPanX = wallLimit +
            SpatialPhysics.applyRubberBanding(
              delta: excess,
              limit: screenSize.width,
            );

        if (excess.abs() > 14.0 && !_boundaryBumpFired) {
          _boundaryBumpFired = true;
          _sound.playBoundaryBump();
          _haptics.selectionClick();
        }
      } else {
        updatedPanX = rawVal;
        _boundaryBumpFired = false;
      }

      final dragDistance = (updatedPanX - _startXAtGesture).abs();
      final hapticThreshold = screenSize.width * 0.50;
      if (dragDistance >= hapticThreshold) {
        if (!_hapticDetentFired) {
          _haptics.selectionClick();
          _hapticDetentFired = true;
        }
      } else if (dragDistance < hapticThreshold * 0.85) {
        _hapticDetentFired = false;
      }
    }
    // -------------------------------------------------------------------------
    // 5. تنفيذ السحب الرأسي (شمال / جنوب)
    // -------------------------------------------------------------------------
    else if (_lockedAxis == Axis.vertical) {
      // تثبيت المحور الأفقي المعاكس على نقطة الأصل لمنع الانحراف
      updatedPanX = _startXAtGesture;

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
        updatedPanY = wallLimit +
            SpatialPhysics.applyRubberBanding(
              delta: excess,
              limit: screenSize.height,
            );

        if (excess.abs() > 14.0 && !_boundaryBumpFired) {
          _boundaryBumpFired = true;
          _sound.playBoundaryBump();
          _haptics.selectionClick();
        }
      } else {
        updatedPanY = rawVal;
        _boundaryBumpFired = false;
      }

      final dragDistance = (updatedPanY - _startYAtGesture).abs();
      final hapticThreshold = screenSize.height * 0.50;
      if (dragDistance >= hapticThreshold) {
        if (!_hapticDetentFired) {
          _haptics.selectionClick();
          _hapticDetentFired = true;
        }
      } else if (dragDistance < hapticThreshold * 0.85) {
        _hapticDetentFired = false;
      }
    }

    // -------------------------------------------------------------------------
    // 6. تحديث نغمات الرادار الصوتي المتصل وميزة الهمس
    // -------------------------------------------------------------------------
    final currentTargetX = -state.currentCoordinate.x * screenSize.width;
    final currentTargetY = state.currentCoordinate.y * screenSize.height;
    final effectivePanX = updatedPanX ?? currentPanX;
    final effectivePanY = updatedPanY ?? currentPanY;

    final normalizedX = -((effectivePanX - currentTargetX) / screenSize.width);
    final normalizedY = ((effectivePanY - currentTargetY) / screenSize.height);

    _sound.updateSpatialRadar(
      normalizedX: normalizedX,
      normalizedY: normalizedY,
      floorLevel: state.currentFloor,
    );

    _handleWhisperScrubbing(
      normalizedX: normalizedX,
      normalizedY: normalizedY,
      isWhisperEnabled: isWhisperEnabled,
      onWhisperDirection: onWhisperDirection,
    );

    return (newPanX: updatedPanX, newPanY: updatedPanY);
  }

  void _handleWhisperScrubbing({
    required double normalizedX,
    required double normalizedY,
    required bool isWhisperEnabled,
    required ValueChanged<SpatialDirection> onWhisperDirection,
  }) {
    if (!isWhisperEnabled) {
      _lastScrubbedDirection = null;
      _scrubbingDebounceTimer?.cancel();
      return;
    }

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
      _scrubbingDebounceTimer = Timer(const Duration(milliseconds: 350), () {
        onWhisperDirection(targetDirection!);
      });
    } else if (targetDirection == null) {
      _lastScrubbedDirection = null;
      _scrubbingDebounceTimer?.cancel();
    }
  }

  /// تحديد الغرفة المستهدفة النهائية وحسابات القصور الذاتي عند رفع الإصبعين
  ({
    SpatialCoordinate destination,
    double velocityX,
    double velocityY,
    bool shouldPlayBoundaryBump,
  }) resolvePanLanding({
    required Offset velocity,
    required double panX,
    required double panY,
    required SpatialShellState state,
    required SpatialTopology topology,
    required Size screenSize,
  }) {
    const distanceThresholdPercent = 0.25;
    const velocityThreshold = 140.0;

    var shouldBump = false;

    if (_lockedAxis == Axis.horizontal) {
      final vx = velocity.dx;
      final currentTargetX = -state.currentCoordinate.x * screenSize.width;
      final deltaFromTarget = panX - currentTargetX;

      SpatialCoordinate? targetCoord;

      if (deltaFromTarget < -screenSize.width * distanceThresholdPercent ||
          vx < -velocityThreshold) {
        targetCoord = topology.findNextOccupiedInDirection(
          origin: state.currentCoordinate,
          direction: SpatialDirection.east,
        );
      } else if (deltaFromTarget >
              screenSize.width * distanceThresholdPercent ||
          vx > velocityThreshold) {
        targetCoord = topology.findNextOccupiedInDirection(
          origin: state.currentCoordinate,
          direction: SpatialDirection.west,
        );
      }

      final destination = targetCoord ?? state.currentCoordinate;
      if (targetCoord == null &&
          (deltaFromTarget.abs() > screenSize.width * 0.20 ||
              vx.abs() > 140)) {
        shouldBump = true;
      }

      return (
        destination: destination,
        velocityX: vx,
        velocityY: 0.0,
        shouldPlayBoundaryBump: shouldBump,
      );
    } else if (_lockedAxis == Axis.vertical) {
      final vy = velocity.dy;
      final currentTargetY = state.currentCoordinate.y * screenSize.height;
      final deltaFromTarget = panY - currentTargetY;

      SpatialCoordinate? targetCoord;

      if (deltaFromTarget > screenSize.height * distanceThresholdPercent ||
          vy > velocityThreshold) {
        targetCoord = topology.findNextOccupiedInDirection(
          origin: state.currentCoordinate,
          direction: SpatialDirection.north,
        );
      } else if (deltaFromTarget <
              -screenSize.height * distanceThresholdPercent ||
          vy < -velocityThreshold) {
        targetCoord = topology.findNextOccupiedInDirection(
          origin: state.currentCoordinate,
          direction: SpatialDirection.south,
        );
      }

      final destination = targetCoord ?? state.currentCoordinate;
      if (targetCoord == null &&
          (deltaFromTarget.abs() > screenSize.height * 0.20 ||
              vy.abs() > 140)) {
        shouldBump = true;
      }

      return (
        destination: destination,
        velocityX: 0.0,
        velocityY: vy,
        shouldPlayBoundaryBump: shouldBump,
      );
    }

    return (
      destination: state.currentCoordinate,
      velocityX: 0.0,
      velocityY: 0.0,
      shouldPlayBoundaryBump: false,
    );
  }

  /// إيقاف الرادار ومؤقتات الهمس الصوتي
  void stopRadarAndWhisper() {
    _sound.stopSpatialRadar();
    _scrubbingDebounceTimer?.cancel();
    _lastScrubbedDirection = null;
  }

  /// إعادة تعيين الإيماءة بالكامل
  void reset() {
    stopRadarAndWhisper();
    _lockedAxis = null;
  }

  /// التخلص من الموارد
  void dispose() {
    stopRadarAndWhisper();
  }
}