// lib/mobile/shell/controllers/handlers/spatial_elevator_handler.dart
import 'package:beacon_os/core/audio/sound_controller.dart';
import 'package:beacon_os/core/haptics/haptic_manager.dart';
import 'package:beacon_os/core/physics/spatial_physics.dart';
import 'package:beacon_os/core/topology/spatial_topology.dart';

/// معالج فيزياء وإيماءات مصعد الطوابق الرأسي (Z-Axis Multi-Floor Elevator).
///
/// يدير حسابات التكبير والتصغير بإصبعين، ومقاومة الحدود المطاطية (Rubber-Banding)،
/// وإطلاق نبضات الاهتزاز عند منتصف الطوابق مع إمكانية حقن التبعيات للاختبارات المعزولة.
class SpatialElevatorHandler {
  SpatialElevatorHandler({
    SoundController? soundController,
    HapticManager? hapticManager,
  })  : _sound = soundController ?? SoundController.instance,
        _haptics = hapticManager ?? HapticManager.instance;

  final SoundController _sound;
  final HapticManager _haptics;

  double _initialScale = 0.0;
  bool _boundaryBumpFired = false;
  bool _hapticDetentFired = false;

  /// القيمة الابتدائية للعمق Z عند بداية لمس الإصبعين
  double get initialScale => _initialScale;

  /// تهيئة الجلسة عند بدء لمس الإصبعين
  void onScaleStart(double currentZ) {
    _initialScale = currentZ;
    _boundaryBumpFired = false;
    _hapticDetentFired = false;
  }

  /// حساب الإزاحة اللحظية في المحور Z مع تطبيق المطاطية ونبضات التثبيت
  double handleScaleUpdate({
    required double scaleFactor,
    required SpatialTopology topology,
  }) {
    final minFloor = topology.minFloor.toDouble();
    final maxFloor = topology.maxFloor.toDouble();

    final scaleDelta = (scaleFactor - 1.0) * 1.5;
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
        _sound.playBoundaryBump();
        _haptics.selectionClick();
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
        _sound.playBoundaryBump();
        _haptics.selectionClick();
      }
    } else {
      computedZ = rawZ;
      _boundaryBumpFired = false;
    }

    // إطلاق نبضة اهتزازية خفيفة عند بلوغ منتصف المسافة بين الطابقين
    final currentBaseFloor = computedZ.floorToDouble();
    final midPoint = currentBaseFloor + 0.50;

    if ((computedZ >= midPoint && _initialScale < midPoint) ||
        (computedZ <= midPoint && _initialScale >= midPoint)) {
      if (!_hapticDetentFired) {
        _haptics.selectionClick();
        _hapticDetentFired = true;
      }
    } else if ((computedZ < midPoint - 0.15 && _initialScale < midPoint) ||
        (computedZ > midPoint + 0.15 && _initialScale >= midPoint)) {
      _hapticDetentFired = false;
    }

    return computedZ;
  }

  /// حساب استقرار الطابق النهائي المستهدف وسرعة الانزلاق عند رفع الأصابع
  ({int targetFloor, double targetZ, double velocity}) calculateLanding({
    required double currentZ,
    required double scaleVelocity,
    required SpatialTopology topology,
  }) {
    final minFloor = topology.minFloor;
    final maxFloor = topology.maxFloor;

    final vz = (scaleVelocity * 1.5).clamp(-4.0, 4.0);
    final velocityBias = vz.clamp(-1.5, 1.5) * 0.35;
    final projectedZ = currentZ + velocityBias;

    int targetFloor;
    final deltaFromInitial = currentZ - _initialScale;

    if (deltaFromInitial > 0.40 || vz > 0.5) {
      targetFloor = (_initialScale + 1).round();
    } else if (deltaFromInitial < -0.40 || vz < -0.5) {
      targetFloor = (_initialScale - 1).round();
    } else {
      targetFloor = projectedZ.round();
    }

    targetFloor = targetFloor.clamp(minFloor, maxFloor);

    return (
      targetFloor: targetFloor,
      targetZ: targetFloor.toDouble(),
      velocity: vz,
    );
  }

  /// إعادة تعيين الحالة الداخلية
  void reset() {
    _boundaryBumpFired = false;
    _hapticDetentFired = false;
  }
}