// lib/mobile/shell/controllers/spatial_camera_controller.dart
import 'dart:async';

import 'package:beacon_os/core/audio/sound_controller.dart';
import 'package:beacon_os/core/haptics/haptic_manager.dart';
import 'package:beacon_os/core/physics/spatial_physics.dart';
import 'package:beacon_os/core/topology/topology.dart';
import 'package:beacon_os/mobile/shell/controllers/handlers/spatial_elevator_handler.dart';
import 'package:beacon_os/mobile/shell/controllers/handlers/spatial_pan_handler.dart';
import 'package:beacon_os/mobile/shell/cubit/spatial_shell_state.dart';
import 'package:flutter/widgets.dart';

enum _ActiveGestureType {
  undecided,
  panning,
  elevator,
}

/// وحدة التحكم بكاميرا الفضاء المعزولة والمدعومة بمصعد الطوابق الرأسي
class SpatialCameraController extends ChangeNotifier {
  SpatialCameraController({
    required TickerProvider vsync,
    SoundController? soundController,
    HapticManager? hapticManager,
    SpatialPanHandler? panHandler,
    SpatialElevatorHandler? elevatorHandler,
  })  : _sound = soundController ?? SoundController.instance,
        _panHandler = panHandler ??
            SpatialPanHandler(
              soundController: soundController,
              hapticManager: hapticManager,
            ),
        _elevatorHandler = elevatorHandler ??
            SpatialElevatorHandler(
              soundController: soundController,
              hapticManager: hapticManager,
            ) {
    _panX = AnimationController.unbounded(vsync: vsync)
      ..addListener(notifyListeners);
    _panY = AnimationController.unbounded(vsync: vsync)
      ..addListener(notifyListeners);
    _floorZ = AnimationController.unbounded(vsync: vsync, value: 0.0)
      ..addListener(notifyListeners);
  }

  final SoundController _sound;
  final SpatialPanHandler _panHandler;
  final SpatialElevatorHandler _elevatorHandler;

  late final AnimationController _panX;
  late final AnimationController _panY;
  late final AnimationController _floorZ;

  // ===========================================================================
  // 🛡️ مؤشرات حركة الغرف والمصعد
  // ===========================================================================
  bool _isSettlingPan = false;
  bool _isPanSessionActive = false;
  Timer? _settleSafetyTimer;
  bool _isFloorAnimating = false;

  _ActiveGestureType _gestureType = _ActiveGestureType.undecided;
  double _accumulatedPanDistance = 0.0;

  double get currentZ => _floorZ.value;
  Offset get panOffset => Offset(_panX.value, _panY.value);

  /// هل حركة الغرف نشطة حالياً
  bool get isPanActive => _isPanSessionActive || _isSettlingPan;

  /// هل هناك أي حركة نشطة في الكاميرا
  bool get isGestureActive =>
      isPanActive || _isFloorAnimating || (_gestureType == _ActiveGestureType.elevator);

  bool get isSettling => _isSettlingPan;

  // ===========================================================================
  // 🧭 مسار الإيماءات المشترك (Pan vs Elevator)
  // ===========================================================================

  void onScaleStart(ScaleStartDetails details, {required int floorLevel}) {
    if (details.pointerCount >= 2) {
      _startGestureSession(floorLevel);
    }
  }

  void _startGestureSession(int floorLevel) {
    if (_isPanSessionActive) return;
    _isPanSessionActive = true;
    _gestureType = _ActiveGestureType.undecided;
    _accumulatedPanDistance = 0.0;

    _cancelSettle();
    _panX.stop();
    _panY.stop();
    _floorZ.stop();

    _panHandler.onScaleStart(
      startPanX: _panX.value,
      startPanY: _panY.value,
      floorLevel: floorLevel,
    );
    _elevatorHandler.onScaleStart(_floorZ.value);
  }

  void onScaleUpdate({
    required ScaleUpdateDetails details,
    required SpatialShellState state,
    required SpatialTopology topology,
    required Size screenSize,
    required ValueChanged<SpatialDirection> onWhisperDirection,
    bool isWhisperEnabled = false,
  }) {
    if (!_isPanSessionActive && details.pointerCount >= 2) {
      _startGestureSession(state.currentFloor);
    }

    if (!_isPanSessionActive) return;

    _accumulatedPanDistance += details.focalPointDelta.distance;
    final scaleDiff = (details.scale - 1.0).abs();

    // 🧠 تصنيف نوع الإيماءة بذكاء وحسم: هل هي حركة مصعد (Pinch/Spread) أم تنقل غرف (Pan)؟
    if (_gestureType == _ActiveGestureType.undecided) {
      if (scaleDiff > 0.12) {
        _gestureType = _ActiveGestureType.elevator;
        // إيقاف رادار الغرف فوراً ليتفرغ المستخدم للمصعد
        _panHandler.stopRadarAndWhisper();
      } else if (_accumulatedPanDistance > 14.0) {
        _gestureType = _ActiveGestureType.panning;
      }
    }

    if (_gestureType == _ActiveGestureType.elevator) {
      // 🏢 تحديث الارتفاع الرأسي Z للمصعد
      final newZ = _elevatorHandler.handleScaleUpdate(
        scaleFactor: details.scale,
        topology: topology,
      );
      _floorZ.value = newZ;
    } else {
      // 🧭 تحديث حركة الغرف الديكارتية XY
      final update = _panHandler.handlePanUpdate(
        focalPointDelta: details.focalPointDelta,
        state: state,
        topology: topology,
        screenSize: screenSize,
        onWhisperDirection: onWhisperDirection,
        isWhisperEnabled: isWhisperEnabled,
      );

      _panX.value = update.newPanX;
      _panY.value = update.newPanY;
    }
  }

  void onScaleEnd({
    required ScaleEndDetails details,
    required SpatialShellState state,
    required SpatialTopology topology,
    required Size screenSize,
    required ValueChanged<SpatialCoordinate> onTargetCoordinateSelected,
    ValueChanged<int>? onTargetFloorSelected,
  }) {
    if (!_isPanSessionActive) return;

    _panHandler.stopRadarAndWhisper();
    _isPanSessionActive = false;

    // 🏢 1. حسم حركة المصعد الرأسي إذا كانت الإيماءة مخصصة للطوابق
    if (_gestureType == _ActiveGestureType.elevator) {
      final landing = _elevatorHandler.calculateLanding(
        currentZ: _floorZ.value,
        scaleVelocity: details.scaleVelocity,
        topology: topology,
      );

      _animateFloorTo(landing.targetZ, velocity: landing.velocity);

      if (landing.targetFloor != state.currentFloor) {
        onTargetFloorSelected?.call(landing.targetFloor);
      }

      _elevatorHandler.reset();
      _panHandler.reset();
      _gestureType = _ActiveGestureType.undecided;
      return;
    }

    // 🎯 2. حسم هبوط الغرفة الحتمي والمعزول (Discrete Magnetic Snapping)
    final landing = _panHandler.resolvePanLanding(
      velocity: details.velocity.pixelsPerSecond,
      panX: _panX.value,
      panY: _panY.value,
      state: state,
      topology: topology,
      screenSize: screenSize,
    );

    final finalX = -landing.destination.x * screenSize.width;
    final finalY = landing.destination.y * screenSize.height;

    // 🔒 تفعيل قفل الانزلاق لحماية حركة النابض
    _startPanSettling(
      targetX: finalX,
      targetY: finalY,
      velocityX: landing.velocityX,
      velocityY: landing.velocityY,
    );

    if (landing.destination != state.currentCoordinate) {
      onTargetCoordinateSelected(landing.destination);
    } else if (landing.shouldPlayBoundaryBump) {
      _sound.playBoundaryBump();
    }

    _panHandler.reset();
    _elevatorHandler.reset();
    _gestureType = _ActiveGestureType.undecided;
  }

  /// إطلاق محاكاة الانزلاق نحو الغرفة المستهدفة مع صمام أمان زمني
  void _startPanSettling({
    required double targetX,
    required double targetY,
    required double velocityX,
    required double velocityY,
  }) {
    _isSettlingPan = true;
    _settleSafetyTimer?.cancel();

    _settleSafetyTimer = Timer(const Duration(milliseconds: 380), () {
      _finalizePanSettling(targetX, targetY);
    });

    final simX = SpatialPhysics.createPanSimulation(
      start: _panX.value,
      end: targetX,
      velocity: velocityX,
    );
    final simY = SpatialPhysics.createPanSimulation(
      start: _panY.value,
      end: targetY,
      velocity: velocityY,
    );

    final futureX = _panX.animateWith(simX);
    final futureY = _panY.animateWith(simY);

    Future.wait([futureX, futureY]).whenComplete(() {
      _finalizePanSettling(targetX, targetY);
    });
  }

  /// التثبيت النهائي الحتمي للكاميرا عند نقطة الهدف
  void _finalizePanSettling(double targetX, double targetY) {
    if (!_isSettlingPan) return;
    _settleSafetyTimer?.cancel();
    _settleSafetyTimer = null;

    _panX.value = targetX;
    _panY.value = targetY;
    _isSettlingPan = false;
    notifyListeners();
  }

  void _cancelSettle() {
    _settleSafetyTimer?.cancel();
    _settleSafetyTimer = null;
    _isSettlingPan = false;
  }

  /// القفز الحتمي نحو إحداثي غرفة معينة (يُستدعى برمجياً أو عبر الـ HUD)
  void snapToCoordinate(SpatialCoordinate coord, Size screenSize) {
    if (_isSettlingPan) return;

    final tx = -coord.x * screenSize.width;
    final ty = coord.y * screenSize.height;

    if ((_panX.value - tx).abs() < 0.5 && (_panY.value - ty).abs() < 0.5) {
      _panX.value = tx;
      _panY.value = ty;
      return;
    }

    _startPanSettling(
      targetX: tx,
      targetY: ty,
      velocityX: 0,
      velocityY: 0,
    );
  }

  // ===========================================================================
  // 🏢 مسار حركة الطوابق الرأسية (Z Axis)
  // ===========================================================================

  void animateToFloor(int targetFloor) {
    _animateFloorTo(targetFloor.toDouble(), velocity: 0.0);
  }

  void _animateFloorTo(double targetZ, {double velocity = 0.0}) {
    if ((_floorZ.value - targetZ).abs() <= 0.001) {
      _floorZ.value = targetZ;
      return;
    }

    _isFloorAnimating = true;
    _floorZ
        .animateWith(
          SpatialPhysics.createZAxisSimulation(
            start: _floorZ.value,
            end: targetZ,
            velocity: velocity,
          ),
        )
        .whenComplete(() {
          _floorZ.value = targetZ;
          _isFloorAnimating = false;
          notifyListeners();
        });
  }

  @override
  void dispose() {
    _cancelSettle();
    _panHandler.dispose();
    _elevatorHandler.reset();
    _panX.dispose();
    _panY.dispose();
    _floorZ.dispose();
    super.dispose();
  }
}