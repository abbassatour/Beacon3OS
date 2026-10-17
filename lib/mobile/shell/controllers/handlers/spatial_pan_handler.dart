// lib/mobile/shell/controllers/handlers/spatial_pan_handler.dart
import 'dart:math' as math;

import 'package:beacon_os/core/audio/sound_controller.dart';
import 'package:beacon_os/core/haptics/haptic_manager.dart';
import 'package:beacon_os/core/physics/spatial_physics.dart';
import 'package:beacon_os/core/topology/topology.dart';
import 'package:beacon_os/mobile/shell/cubit/spatial_shell_state.dart';
import 'package:flutter/widgets.dart';

/// معالج فيزياء السحب والتنقل الديكارتي الحر بين الغرف.
/// يتيح الحركة السلسة في بعدين ويحسب القرار النهائي الحتمي عند الإفلات
/// بحيث تستقر الكاميرا دائماً وأبداً في مركز إحدى الغرف (Discrete Magnetic Snapping).
class SpatialPanHandler {
  SpatialPanHandler({
    SoundController? soundController,
    HapticManager? hapticManager,
  })  : _sound = soundController ?? SoundController.instance,
        _haptics = hapticManager ?? HapticManager.instance;

  final SoundController _sound;
  final HapticManager _haptics;

  double _startXAtGesture = 0.0;
  double _startYAtGesture = 0.0;
  double _accumulatedDeltaX = 0.0;
  double _accumulatedDeltaY = 0.0;

  bool _boundaryBumpFired = false;
  bool _hapticDetentFired = false;
  SpatialDirection? _lastScrubbedDirection;

  /// تهيئة إحداثيات بداية لمس الإصبعين وتشغيل الرادار الصوتي
  void onScaleStart({
    required double startPanX,
    required double startPanY,
    required int floorLevel,
  }) {
    _startXAtGesture = startPanX;
    _startYAtGesture = startPanY;
    _accumulatedDeltaX = 0.0;
    _accumulatedDeltaY = 0.0;
    _boundaryBumpFired = false;
    _hapticDetentFired = false;
    _lastScrubbedDirection = null;

    _sound.startSpatialRadar(floorLevel: floorLevel);
  }

  /// حركة حرة ولحظية أثناء السحب في بعدين مع تطبيق المقاومة المطاطية ونبضات الهابتك
  ({double newPanX, double newPanY}) handlePanUpdate({
    required Offset focalPointDelta,
    required SpatialShellState state,
    required SpatialTopology topology,
    required Size screenSize,
    required ValueChanged<SpatialDirection> onWhisperDirection,
    required bool isWhisperEnabled,
  }) {
    _accumulatedDeltaX += focalPointDelta.dx;
    _accumulatedDeltaY += focalPointDelta.dy;

    final rawValX = _startXAtGesture + _accumulatedDeltaX;
    final rawValY = _startYAtGesture + _accumulatedDeltaY;

    final currentTargetX = -state.currentCoordinate.x * screenSize.width;
    final currentTargetY = state.currentCoordinate.y * screenSize.height;

    // جلب الجيران المتاحين في الطابق النشط
    final eastNeighbor = topology.findNextOccupiedInDirection(
      origin: state.currentCoordinate,
      direction: SpatialDirection.east,
    );
    final westNeighbor = topology.findNextOccupiedInDirection(
      origin: state.currentCoordinate,
      direction: SpatialDirection.west,
    );
    final northNeighbor = topology.findNextOccupiedInDirection(
      origin: state.currentCoordinate,
      direction: SpatialDirection.north,
    );
    final southNeighbor = topology.findNextOccupiedInDirection(
      origin: state.currentCoordinate,
      direction: SpatialDirection.south,
    );

    // حدود الحركة الأفقية
    final minLimitX = eastNeighbor != null
        ? -eastNeighbor.x * screenSize.width
        : currentTargetX;
    final maxLimitX = westNeighbor != null
        ? -westNeighbor.x * screenSize.width
        : currentTargetX;

    final lowerBoundX = math.min(minLimitX, maxLimitX);
    final upperBoundX = math.max(minLimitX, maxLimitX);

    // حدود الحركة الرأسية
    final maxLimitY = northNeighbor != null
        ? northNeighbor.y * screenSize.height
        : currentTargetY;
    final minLimitY = southNeighbor != null
        ? southNeighbor.y * screenSize.height
        : currentTargetY;

    final lowerBoundY = math.min(minLimitY, maxLimitY);
    final upperBoundY = math.max(minLimitY, maxLimitY);

    double updatedPanX = rawValX;
    double updatedPanY = rawValY;
    var hitWall = false;

    // تطبيق المقاومة المطاطية عند الأطراف
    if (rawValX < lowerBoundX) {
      final excess = rawValX - lowerBoundX;
      updatedPanX = lowerBoundX +
          SpatialPhysics.applyRubberBanding(
            delta: excess,
            limit: screenSize.width * 0.40,
          );
      hitWall = true;
    } else if (rawValX > upperBoundX) {
      final excess = rawValX - upperBoundX;
      updatedPanX = upperBoundX +
          SpatialPhysics.applyRubberBanding(
            delta: excess,
            limit: screenSize.width * 0.40,
          );
      hitWall = true;
    }

    if (rawValY < lowerBoundY) {
      final excess = rawValY - lowerBoundY;
      updatedPanY = lowerBoundY +
          SpatialPhysics.applyRubberBanding(
            delta: excess,
            limit: screenSize.height * 0.40,
          );
      hitWall = true;
    } else if (rawValY > upperBoundY) {
      final excess = rawValY - upperBoundY;
      updatedPanY = upperBoundY +
          SpatialPhysics.applyRubberBanding(
            delta: excess,
            limit: screenSize.height * 0.40,
          );
      hitWall = true;
    }

    if (hitWall) {
      final totalExcess =
          (rawValX - updatedPanX).abs() + (rawValY - updatedPanY).abs();
      if (totalExcess > 14.0 && !_boundaryBumpFired) {
        _boundaryBumpFired = true;
        _sound.playBoundaryBump();
        _haptics.selectionClick();
      }
    } else {
      _boundaryBumpFired = false;
    }

    // إشعار حسي عند قطع ثلث المسافة
    final distanceX = (updatedPanX - _startXAtGesture).abs();
    final distanceY = (updatedPanY - _startYAtGesture).abs();
    final totalMove = math.sqrt(distanceX * distanceX + distanceY * distanceY);

    if (totalMove >= screenSize.width * 0.35) {
      if (!_hapticDetentFired) {
        _haptics.selectionClick();
        _hapticDetentFired = true;
      }
    } else if (totalMove < screenSize.width * 0.20) {
      _hapticDetentFired = false;
    }

    // تحديث تردد وموقع الرادار الصوتي التفاعلي
    final normalizedX = -((updatedPanX - currentTargetX) / screenSize.width);
    final normalizedY = ((updatedPanY - currentTargetY) / screenSize.height);

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
    if (!isWhisperEnabled) return;

    SpatialDirection? targetDirection;
    if (normalizedX > 0.35 && normalizedX.abs() > normalizedY.abs() * 1.15) {
      targetDirection = SpatialDirection.east;
    } else if (normalizedX < -0.35 &&
        normalizedX.abs() > normalizedY.abs() * 1.15) {
      targetDirection = SpatialDirection.west;
    } else if (normalizedY > 0.35 &&
        normalizedY.abs() > normalizedX.abs() * 1.15) {
      targetDirection = SpatialDirection.north;
    } else if (normalizedY < -0.35 &&
        normalizedY.abs() > normalizedX.abs() * 1.15) {
      targetDirection = SpatialDirection.south;
    }

    if (targetDirection != null && targetDirection != _lastScrubbedDirection) {
      _lastScrubbedDirection = targetDirection;
      onWhisperDirection(targetDirection);
    } else if (targetDirection == null) {
      _lastScrubbedDirection = null;
    }
  }

  /// 🎯 المعادلة المحورية: استقرار حتمي بنسبة 100% (Discrete Magnetic Snapping)
  /// تقرر لحظة رفع الأصابع إما الانتقال الكامل لرأس الغرفة التالية،
  /// أو الارتداد الكامل لرأس الغرفة الحالية، ومستحيل الوقوف في المنتصف.
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
    final currentTargetX = -state.currentCoordinate.x * screenSize.width;
    final currentTargetY = state.currentCoordinate.y * screenSize.height;

    final deltaX = panX - currentTargetX;
    final deltaY = panY - currentTargetY;

    // ⚡ ثابت القصور الذاتي الفيزيائي للحركة
    const tau = 0.16;
    final projectedX = deltaX + (velocity.dx * tau);
    final projectedY = deltaY + (velocity.dy * tau);

    // عتبات الحسم: 20% مسافة من أبعاد الشاشة أو سرعة قذف > 350 px/s
    final thresholdX = screenSize.width * 0.20;
    final thresholdY = screenSize.height * 0.20;
    const flickVelocityThreshold = 350.0;

    SpatialDirection? intendedDirection;

    // 1. تحديد المحور المهيمن الحقيقي (Horizontal vs Vertical)
    if (projectedX.abs() >= projectedY.abs()) {
      // المحور الأفقي مهيمن
      if (projectedX < -thresholdX || velocity.dx < -flickVelocityThreshold) {
        intendedDirection = SpatialDirection.east;
      } else if (projectedX > thresholdX ||
          velocity.dx > flickVelocityThreshold) {
        intendedDirection = SpatialDirection.west;
      }
    } else {
      // المحور الرأسي مهيمن
      if (projectedY > thresholdY || velocity.dy > flickVelocityThreshold) {
        intendedDirection = SpatialDirection.north;
      } else if (projectedY < -thresholdY ||
          velocity.dy < -flickVelocityThreshold) {
        intendedDirection = SpatialDirection.south;
      }
    }

    SpatialCoordinate? targetCoord;
    var shouldBump = false;

    // 2. التحقق الصارم من وجود غرفة مأهولة في الاتجاه المقصود
    if (intendedDirection != null) {
      targetCoord = topology.findNextOccupiedInDirection(
        origin: state.currentCoordinate,
        direction: intendedDirection,
      );

      // إذا حاول المستخدم السحب نحو جدار لا توجد بعده غرفة
      if (targetCoord == null) {
        shouldBump = true;
      }
    }

    // 3. اتخاذ القرار الحتمي: إن وُجدت غرفة ينتقل إليها، وإلا فالارتداد التام بنسبة 100% للغرفة الحالية
    final destination = targetCoord ?? state.currentCoordinate;

    // تقييد السرعة المنقولة للنابض لضمان انزلاق انسيابي خالٍ من التشنج
    final clampedVx = velocity.dx.clamp(-1500.0, 1500.0);
    final clampedVy = velocity.dy.clamp(-1500.0, 1500.0);

    return (
      destination: destination,
      velocityX: clampedVx,
      velocityY: clampedVy,
      shouldPlayBoundaryBump: shouldBump,
    );
  }

  void stopRadarAndWhisper() {
    _sound.stopSpatialRadar();
    _lastScrubbedDirection = null;
  }

  void reset() {
    stopRadarAndWhisper();
  }

  void dispose() {
    stopRadarAndWhisper();
  }
}