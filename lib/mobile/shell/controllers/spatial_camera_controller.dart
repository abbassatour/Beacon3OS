// lib/mobile/shell/controllers/spatial_camera_controller.dart
import 'package:beacon_os/core/audio/sound_controller.dart';
import 'package:beacon_os/core/haptics/haptic_manager.dart';
import 'package:beacon_os/core/physics/spatial_physics.dart';
import 'package:beacon_os/core/topology/topology.dart';
import 'package:beacon_os/mobile/shell/controllers/handlers/spatial_elevator_handler.dart';
import 'package:beacon_os/mobile/shell/controllers/handlers/spatial_pan_handler.dart';
import 'package:beacon_os/mobile/shell/cubit/spatial_shell_state.dart';
import 'package:flutter/widgets.dart';

/// منسق ومحرك فيزياء الكاميرا الفضائية (Spatial Camera Orchestrator).
///
/// ينسق بين متحكمات الحركة AnimationControllers ومعالجي الإيماءات:
/// [SpatialElevatorHandler] لمصعد الطوابق الرأسي (Z-Axis)،
/// و [SpatialPanHandler] للسحب الأفقي والرأسي بين الغرف (XY-Axis).
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

  bool _isTwoFingerElevator = false;
  bool _isTransitioningViaGesture = false;

  // ===========================================================================
  // 🧭 Public Getters (مطابقة تماماً للواجهة الخارجية القديمة)
  // ===========================================================================

  /// الارتفاع اللحظي الحالي في المحور Z
  double get currentZ => _floorZ.value;

  /// إزاحة الكاميرا الحالية على المستويين الأفقي والرأسي
  Offset get panOffset => Offset(_panX.value, _panY.value);

  /// هل هناك إيماءة نشطة حالياً يتبعها المستخدم بإصبعه
  bool get isGestureActive =>
      _panHandler.lockedAxis != null || _isTwoFingerElevator;

  // ===========================================================================
  // ✋ دورة حياة الإيماءات (Scale & Pan Gesture Lifecycle)
  // ===========================================================================

  void onScaleStart(ScaleStartDetails details, {required int floorLevel}) {
    _panX.stop();
    _panY.stop();
    _floorZ.stop();

    _isTwoFingerElevator = details.pointerCount >= 2;

    if (_isTwoFingerElevator) {
      _elevatorHandler.onScaleStart(_floorZ.value);
    } else if (details.pointerCount < 3) {
      _panHandler.onScaleStart(
        startPanX: _panX.value,
        startPanY: _panY.value,
        floorLevel: floorLevel,
      );
    }
  }

  void onScaleUpdate({
    required ScaleUpdateDetails details,
    required SpatialShellState state,
    required SpatialTopology topology,
    required Size screenSize,
    required bool isInnerListScrolling,
    required ValueChanged<SpatialDirection> onWhisperDirection,
    bool isWhisperEnabled = false,
  }) {
    // 🏢 1. إيماءة مصعد الطوابق (إصبعين أو أكثر)
    if (details.pointerCount >= 2) {
      _isTwoFingerElevator = true;
      _floorZ.value = _elevatorHandler.handleScaleUpdate(
        scaleFactor: details.scale,
        topology: topology,
      );
      return;
    }

    if (_isTwoFingerElevator && details.pointerCount < 2) return;

    // 🧭 2. إيماءة السحب الأفقي/الرأسي بين الغرف
    final update = _panHandler.handlePanUpdate(
      focalPointDelta: details.focalPointDelta,
      currentPanX: _panX.value,
      currentPanY: _panY.value,
      state: state,
      topology: topology,
      screenSize: screenSize,
      isInnerListScrolling: isInnerListScrolling,
      onWhisperDirection: onWhisperDirection,
      isWhisperEnabled: isWhisperEnabled,
    );

    if (update.newPanX != null) {
      _panX.value = update.newPanX!;
    }
    if (update.newPanY != null) {
      _panY.value = update.newPanY!;
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
    // 🔊 إيقاف الرادار الصوتي فوراً في جميع حالات الإفلات لضمان عدم استمراره
    _panHandler.stopRadarAndWhisper();

    // 🏢 1. إنهاء إيماءة مصعد الطوابق
    if (_isTwoFingerElevator) {
      _isTwoFingerElevator = false;
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
        _isTransitioningViaGesture = false;
        notifyListeners();
      });

      if (landing.targetFloor != state.currentFloor) {
        onTargetFloorSelected(landing.targetFloor);
      }
      return;
    }

    // 🧭 2. إنهاء إيماءة السحب بين الغرف
    if (_panHandler.isInnerScrollingActive) {
      snapToCoordinate(state.currentCoordinate, screenSize);
      _panHandler.reset();
      return;
    }

    final landing = _panHandler.resolvePanLanding(
      velocity: details.velocity.pixelsPerSecond,
      panX: _panX.value,
      panY: _panY.value,
      state: state,
      topology: topology,
      screenSize: screenSize,
    );

    if (_panHandler.lockedAxis != null) {
      final finalX = -landing.destination.x * screenSize.width;
      final finalY = landing.destination.y * screenSize.height;

      _panX.animateWith(
        SpatialPhysics.createPanSimulation(
          start: _panX.value,
          end: finalX,
          velocity: landing.velocityX,
        ),
      );
      _panY.animateWith(
        SpatialPhysics.createPanSimulation(
          start: _panY.value,
          end: finalY,
          velocity: landing.velocityY,
        ),
      );

      if (landing.destination != state.currentCoordinate) {
        onTargetCoordinateSelected(landing.destination);
      } else if (landing.shouldPlayBoundaryBump) {
        _sound.playBoundaryBump();
      }
    } else {
      snapToCoordinate(state.currentCoordinate, screenSize);
    }

    _panHandler.reset();
  }

  // ===========================================================================
  // 🎬 التوجيه البرمجي المباشر (Programmatic Snapping & Animation)
  // ===========================================================================

  /// محاذاة الكاميرا الديكارتية إلى إحداثي محدد فورياً
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

  /// تحريك مصعد الطوابق برمجياً إلى طابق معين
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
    _panHandler.dispose();
    _panX.dispose();
    _panY.dispose();
    _floorZ.dispose();
    super.dispose();
  }
}