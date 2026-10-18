// lib/mobile/shell/controllers/spatial_camera_controller.dart
import 'dart:async';

import 'package:beacon_os/core/audio/sound_controller.dart';
import 'package:beacon_os/core/haptics/haptic_manager.dart';
import 'package:beacon_os/core/physics/spatial_physics.dart';
import 'package:beacon_os/core/topology/topology.dart';
import 'package:beacon_os/mobile/shell/controllers/handlers/spatial_pan_handler.dart';
import 'package:beacon_os/mobile/shell/cubit/spatial_shell_state.dart';
import 'package:flutter/widgets.dart';

/// وحدة التحكم بكاميرا الفضاء المعزولة.
///
/// تم عزل مسار التنقل بين الغرف (XY Pan) بالكامل عن مسار الطوابق (Z Axis)
/// لضمان استقرار حركة الغرف ونعومتها بنسبة 100% دون أي تداخل فيزيائي.
class SpatialCameraController extends ChangeNotifier {
  SpatialCameraController({
    required TickerProvider vsync,
    SoundController? soundController,
    HapticManager? hapticManager,
    SpatialPanHandler? panHandler,
  })  : _sound = soundController ?? SoundController.instance,
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
  final SpatialPanHandler _panHandler;

  late final AnimationController _panX;
  late final AnimationController _panY;
  late final AnimationController _floorZ;

  // ===========================================================================
  // 🛡️ مؤشرات حركة الغرف (Pan Pipeline - Isolated & Protected)
  // ===========================================================================
  bool _isSettlingPan = false;
  bool _isPanSessionActive = false;
  Timer? _settleSafetyTimer;

  // ===========================================================================
  // 🏢 مؤشرات حركة الطوابق (Z-Axis Pipeline - Independent)
  // ===========================================================================
  bool _isFloorAnimating = false;

  double get currentZ => _floorZ.value;
  Offset get panOffset => Offset(_panX.value, _panY.value);

  /// هل حركة الغرف نشطة حالياً (إما لمس مباشر أو انزلاق مغناطيسي نحو الغرفة)
  bool get isPanActive => _isPanSessionActive || _isSettlingPan;

  /// هل هناك أي حركة نشطة في الكاميرا
  bool get isGestureActive => isPanActive || _isFloorAnimating;

  bool get isSettling => _isSettlingPan;

  // ===========================================================================
  // 🧭 مسار التنقل الديكارتي بين الغرف (XY Pan - 100% Pure & Fast)
  // ===========================================================================

  void onScaleStart(ScaleStartDetails details, {required int floorLevel}) {
    // 🛡️ حماية: لا نوقف حركة الكاميرا إلا عند ثبوت لمس إصبعين للملاحة الفضائية
    if (details.pointerCount >= 2) {
      _startPanSession(floorLevel);
    }
  }

  void _startPanSession(int floorLevel) {
    if (_isPanSessionActive) return;
    _isPanSessionActive = true;

    _cancelSettle();
    _panX.stop();
    _panY.stop();

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
    if (!_isPanSessionActive && details.pointerCount >= 2) {
      _startPanSession(state.currentFloor);
    }

    if (!_isPanSessionActive) return;

    // ⚡ توجيه مباشر وفوري لحركة الغرف دون أي شروط أو فحص لمصعد الطوابق
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

    // 🎯 حسم هبوط الغرفة الحتمي والمعزول (Discrete Magnetic Snapping)
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
    // 🛡️ إذا كانت الكاميرا تنزلق بالفعل بفعل حركة الإصبعين، لا تقاطع مسارها
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
  // 🏢 مسار حركة الطوابق الرأسية (Z Axis - Isolated Pipeline)
  // ===========================================================================

  /// تحريك الارتفاع نحو طابق محدد دون أي تأثير جانبي على حركة الغرف
  void animateToFloor(int targetFloor) {
    final targetZ = targetFloor.toDouble();
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
            velocity: 0,
          ),
        )
        .whenComplete(() {
          // 🔒 إغلاق حتمي للقيمة وتحديث الواجهة لضمان الاستقرار التام
          _floorZ.value = targetZ;
          _isFloorAnimating = false;
          notifyListeners();
        });
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