// lib/mobile/shell/controllers/spatial_camera_controller.dart
import 'package:beacon_os/core/audio/sound_controller.dart';
import 'package:beacon_os/core/haptics/haptic_manager.dart';
import 'package:beacon_os/core/physics/spatial_physics.dart';
import 'package:beacon_os/core/topology/topology.dart';
import 'package:beacon_os/mobile/shell/controllers/handlers/spatial_elevator_handler.dart';
import 'package:beacon_os/mobile/shell/controllers/handlers/spatial_pan_handler.dart';
import 'package:beacon_os/mobile/shell/cubit/spatial_shell_state.dart';
import 'package:flutter/widgets.dart';

/// أنماط إيماءات اللمس بإصبعين
enum TwoFingerGestureMode {
  undecided,
  elevator, // Z-Axis (Pinch / Spread لمصعد الطوابق)
  pan, // XY-Axis (سحب للتنقل بين الغرف في الاتجاهات الأربعة)
}

/// منسق ومحرك فيزياء الكاميرا الفضائية (Spatial Camera Orchestrator).
///
/// يعتمد قاعدة الإصبعين الصارمة:
/// - إصبع واحد: يُترك بالكامل للقوائم والعناصر التفاعلية الداخلية.
/// - إصبعان: يُصنف حركياً إلى تنقل ديكارتي بين الغرف (Pan) أو مصعد الطوابق (Elevator).
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

  // 📐 متغيرات التجميع لنافذة التحكيم الدقيقة (Disambiguation Window)
  double _accumulatedFocalDistance = 0.0;

  // 🎯 عتبات التمييز الحسابية القياسية
  static const double _elevatorScaleThreshold = 0.055; // 5.5% تباعد أو تقارب
  static const double _panDisplacementThreshold = 9.0; // 9 بكسل إزاحة فعلية للمركز

  // ===========================================================================
  // 🧭 Public Getters
  // ===========================================================================

  /// الارتفاع اللحظي الحالي في المحور Z
  double get currentZ => _floorZ.value;

  /// إزاحة الكاميرا الحالية على المستويين الأفقي والرأسي
  Offset get panOffset => Offset(_panX.value, _panY.value);

  /// هل هناك إيماءة فضائية نشطة حالياً بإصبعين
  bool get isGestureActive => _gestureMode != TwoFingerGestureMode.undecided;

  // ===========================================================================
  // ✋ دورة حياة الإيماءات (Two-Finger Gesture Lifecycle)
  // ===========================================================================

  void onScaleStart(ScaleStartDetails details, {required int floorLevel}) {
    _panX.stop();
    _panY.stop();
    _floorZ.stop();

    _gestureMode = TwoFingerGestureMode.undecided;
    _accumulatedFocalDistance = 0.0;

    // 🛡️ شرط الحماية: لا نبدأ أي عملية فضائية إلا إذا وُضع إصبعان على الأقل
    if (details.pointerCount >= 2) {
      _elevatorHandler.onScaleStart(_floorZ.value);
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
    required ValueChanged<SpatialDirection> onWhisperDirection,
    bool isWhisperEnabled = false,
  }) {
    // 🛡️ 1. إصبع واحد: تجاهل تام وفوري لترك القوائم الداخلية تتصفح بحرية 100%
    if (details.pointerCount < 2) {
      return;
    }

    // 🎯 2. تصنيف حركة الإصبعين عبر نافذة التجميع التراكمية (Arbitration Engine)
    if (_gestureMode == TwoFingerGestureMode.undecided) {
      final scaleDelta = (details.scale - 1.0).abs();
      _accumulatedFocalDistance += details.focalPointDelta.distance;

      // أولوية كشف المصعد: إذا حدث تباعد/تقارب ملحوظ نتجاهل انزياح نقطة الارتكاز
      if (scaleDelta >= _elevatorScaleThreshold) {
        _gestureMode = TwoFingerGestureMode.elevator;
        _panHandler.stopRadarAndWhisper();
      }
      // إذا تحرك المركز مسافة واضحة تفوق عتبة الـ Slop دون مباعدة
      else if (_accumulatedFocalDistance >= _panDisplacementThreshold) {
        _gestureMode = TwoFingerGestureMode.pan;
      } else {
        // لا تزال الإيماءة في نافذة التحديد (أقل من العتبات) -> لا نحرك الكاميرا بعد
        return;
      }
    }

    // 🏢 3. تنفيذ مصعد الطوابق (Pinch / Spread)
    if (_gestureMode == TwoFingerGestureMode.elevator) {
      _floorZ.value = _elevatorHandler.handleScaleUpdate(
        scaleFactor: details.scale,
        topology: topology,
      );
      return;
    }

    // 🧭 4. تنفيذ التنقل الديكارتي بين الغرف (Two-Finger Pan)
    if (_gestureMode == TwoFingerGestureMode.pan) {
      final update = _panHandler.handlePanUpdate(
        focalPointDelta: details.focalPointDelta,
        currentPanX: _panX.value,
        currentPanY: _panY.value,
        state: state,
        topology: topology,
        screenSize: screenSize,
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
    _accumulatedFocalDistance = 0.0;

    // 🏢 إنهاء إيماءة مصعد الطوابق
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
        _isTransitioningViaGesture = false;
        notifyListeners();
      });

      if (landing.targetFloor != state.currentFloor) {
        onTargetFloorSelected(landing.targetFloor);
      }
      return;
    }

    // 🧭 إنهاء إيماءة سحب الغرف
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
      return;
    }

    // إعادة تعيين الحالة في أي سيناريو آخر
    _gestureMode = TwoFingerGestureMode.undecided;
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