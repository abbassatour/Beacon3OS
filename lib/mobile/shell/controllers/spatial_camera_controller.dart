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

enum TwoFingerGestureMode {
  undecided,
  elevator, // Z-Axis (Pinch/Spread لمصعد الطوابق فقط)
  pan, // XY-Axis (تمرير ديكارتي حر بين الغرف)
}

class SpatialCameraController extends ChangeNotifier {
  SpatialCameraController({
    required TickerProvider vsync,
    SoundController? soundController,
    HapticManager? hapticManager,
    SpatialElevatorHandler? elevatorHandler,
    SpatialPanHandler? panHandler,
  })  : _sound = soundController ?? SoundController.instance,
        _elevatorHandler = elevatorHandler ??
            SpatialElevatorHandler(
              soundController: soundController,
              hapticManager: hapticManager,
            ),
        _panHandler = panHandler ??
            SpatialPanHandler(
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
  final SpatialElevatorHandler _elevatorHandler;
  final SpatialPanHandler _panHandler;

  late final AnimationController _panX;
  late final AnimationController _panY;
  late final AnimationController _floorZ;

  TwoFingerGestureMode _gestureMode = TwoFingerGestureMode.undecided;
  bool _isTransitioningViaGesture = false;
  bool _isSettlingPan = false;
  bool _sessionInitialized = false;
  Timer? _settleSafetyTimer;

  // عتبة المصعد تكون واضحة ومقصودة (Pinch متعمد في المكان)
  static const double _elevatorScaleThreshold = 0.18;

  double get currentZ => _floorZ.value;
  Offset get panOffset => Offset(_panX.value, _panY.value);

  /// تُعتبر الكاميرا نشطة طالما أن المستخدم يلمس الشاشة أو أن النابض في مرحلة الانزلاق الحتمي (Glide Lock)
  bool get isGestureActive =>
      _gestureMode != TwoFingerGestureMode.undecided ||
      _isSettlingPan ||
      _isTransitioningViaGesture;

  bool get isSettling => _isSettlingPan || _isTransitioningViaGesture;

  void onScaleStart(ScaleStartDetails details, {required int floorLevel}) {
    _gestureMode = TwoFingerGestureMode.undecided;
    _sessionInitialized = false;

    // 🛡️ حماية حاسمة: لا نوقف حركة الكاميرا عند اللمس بإصبع واحد (كالقوائم والأزرار)
    // نوقفها فقط عندما يتأكد هبوط إصبعين للملاحة الفضائية
    if (details.pointerCount >= 2) {
      _startSession(floorLevel);
    }
  }

  void _startSession(int floorLevel) {
    if (_sessionInitialized) return;
    _sessionInitialized = true;

    _cancelSettle();
    _panX.stop();
    _panY.stop();
    _floorZ.stop();

    _elevatorHandler.onScaleStart(_floorZ.value);
    _panHandler.onScaleStart(
      startPanX: _panX.value,
      startPanY: _panY.value,
      floorLevel: floorLevel,
    );
  }

  void onScaleUpdate({
    required ScaleUpdateDetails details,
    required SpatialShellState state,
    required SpatialTopology topology,
    required Size screenSize,
    required ValueChanged<SpatialDirection> onWhisperDirection,
    bool isWhisperEnabled = false,
  }) {
    // تفعيل الجلسة فور وصول الإصبع الثاني
    if (!_sessionInitialized && details.pointerCount >= 2) {
      _startSession(state.currentFloor);
    }

    if (!_sessionInitialized) return;

    // تمييز فوري دون أي تجميد
    if (_gestureMode == TwoFingerGestureMode.undecided) {
      final scaleDelta = (details.scale - 1.0).abs();
      final moveDistance = details.focalPointDelta.distance;

      if (scaleDelta >= _elevatorScaleThreshold && moveDistance < 3.0) {
        _gestureMode = TwoFingerGestureMode.elevator;
        _panHandler.stopRadarAndWhisper();
      } else {
        _gestureMode = TwoFingerGestureMode.pan;
      }
    }

    // 🏢 مصعد الطوابق
    if (_gestureMode == TwoFingerGestureMode.elevator) {
      _floorZ.value = _elevatorHandler.handleScaleUpdate(
        scaleFactor: details.scale,
        topology: topology,
      );
      return;
    }

    // 🧭 التمرير الفضائي الحر في بعدين
    if (_gestureMode == TwoFingerGestureMode.pan) {
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
    required ValueChanged<int> onTargetFloorSelected,
  }) {
    _panHandler.stopRadarAndWhisper();
    _sessionInitialized = false;

    // 1. إفلات مصعد الطوابق
    if (_gestureMode == TwoFingerGestureMode.elevator) {
      _gestureMode = TwoFingerGestureMode.undecided;
      _isTransitioningViaGesture = true;

      final landing = _elevatorHandler.calculateLanding(
        currentZ: _floorZ.value,
        scaleVelocity: details.scaleVelocity,
        topology: topology,
      );

      _floorZ
          .animateWith(
        SpatialPhysics.createZAxisSimulation(
          start: _floorZ.value,
          end: landing.targetZ,
          velocity: landing.velocity,
        ),
      )
          .whenComplete(() {
        _floorZ.value = landing.targetZ;
        _isTransitioningViaGesture = false;
        notifyListeners();
      });

      if (landing.targetFloor != state.currentFloor) {
        onTargetFloorSelected(landing.targetFloor);
      }
      return;
    }

    // 2. إفلات السحب الفضائي بين الغرف (Magnetic Discrete Snapping)
    if (_gestureMode == TwoFingerGestureMode.pan) {
      _gestureMode = TwoFingerGestureMode.undecided;

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

      // 🔒 تفعيل قفل الانزلاق لحماية حركة النابض من أي مقاطعة خارجية
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
      return;
    }

    _gestureMode = TwoFingerGestureMode.undecided;
    _panHandler.reset();
  }

  /// إطلاق محاكاة الانزلاق الحتمي نحو الهدف مع صمام أمان زمني
  void _startPanSettling({
    required double targetX,
    required double targetY,
    required double velocityX,
    required double velocityY,
  }) {
    _isSettlingPan = true;
    _settleSafetyTimer?.cancel();

    // صمام أمان (Watchdog): يضمن فك القفل واستقرار الكاميرا حتى لو تأخرت محاكاة النابض
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

  /// القفز الحتمي نحو إحداثي معين (يُستدعى برمجياً أو عند الضغط على الـ HUD)
  void snapToCoordinate(SpatialCoordinate coord, Size screenSize) {
    // 🛡️ إذا كانت الكاميرا تنزلق بالفعل بفعل إيماءة الإصبعين، لا تقاطع مسارها
    if (_isSettlingPan) return;

    final tx = -coord.x * screenSize.width;
    final ty = coord.y * screenSize.height;

    // إذا كانت الكاميرا في مكانها بالفعل بدقة نصف بكسل
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
    _cancelSettle();
    _panHandler.dispose();
    _panX.dispose();
    _panY.dispose();
    _floorZ.dispose();
    super.dispose();
  }
}