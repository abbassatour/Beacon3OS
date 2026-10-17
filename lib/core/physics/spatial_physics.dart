// lib/core/physics/spatial_physics.dart
import 'dart:math' as math;
import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// محرك الفيزياء الحركية الفضائية (Spatial Motion Physics Engine)
/// تم ضبط النوابض بمعايير التخميد الحرج المتصل لمنح الكاميرا انسيابية شاشات 120Hz.
class SpatialPhysics {
  SpatialPhysics._();

  // ===========================================================================
  // 📐 1. تكوينات النوابض اللارنينية (Critically Damped Smooth Springs)
  // ===========================================================================

  /// 🎯 نابض التنقل بين الغرف:
  /// mass: 1.0, stiffness: 320.0, damping: 36.0
  /// التخميد الحرج = 36 / (2 * sqrt(320)) = 1.006 (تخميد مثالي يمنع الاهتزاز والتشنج)
  static const SpringDescription panSpring = SpringDescription(
    mass: 1.0,
    stiffness: 320.0,
    damping: 36.0,
  );

  /// 🏢 نابض الانتقال الرأسي في العمق (Z-Axis Multi-Floor Elevator)
  static const SpringDescription zAxisSpring = SpringDescription(
    mass: 1.0,
    stiffness: 240.0,
    damping: 30.0,
  );

  /// حساب نسبة التخميد للتأكد الهندسي
  static double calculateDampingRatio(SpringDescription spring) {
    return spring.damping / (2.0 * math.sqrt(spring.mass * spring.stiffness));
  }

  // ===========================================================================
  // 🎥 2. ثوابت المنظور ثلاثي الأبعاد
  // ===========================================================================
  static const double perspectiveCoefficient = 0.0008;
  static const double elevationLiftOffset = 30.0;

  // ===========================================================================
  // 🚀 3. مولدات المحاكاة الحركية
  // ===========================================================================
  static SpringSimulation createPanSimulation({
    required double start,
    required double end,
    required double velocity,
  }) {
    return SpringSimulation(
      panSpring,
      start,
      end,
      velocity,
    );
  }

  static SpringSimulation createZAxisSimulation({
    required double start,
    required double end,
    required double velocity,
  }) {
    return SpringSimulation(
      zAxisSpring,
      start,
      end,
      velocity,
    );
  }

  // ===========================================================================
  // ✋ 4. حسابات المقاومة المطاطية عند الأطراف (Rubber-Banding)
  // ===========================================================================
  static double applyRubberBanding({
    required double delta,
    required double limit,
    double stiffness = 0.40,
  }) {
    if (delta == 0) return 0.0;
    final absDelta = delta.abs();
    final rubberDelta =
        limit * (1.0 - (1.0 / ((absDelta * stiffness / limit) + 1.0)));
    return delta < 0 ? -rubberDelta : rubberDelta;
  }

  // ===========================================================================
  // 🌀 5. منحنيات التنعيم الفضائي (Hermite & Smootherstep)
  // ===========================================================================
  static double smoothStep(double t) {
    final clamped = t.clamp(0.0, 1.0);
    return clamped * clamped * (3.0 - (2.0 * clamped));
  }

  static double smootherStep(double t) {
    final clamped = t.clamp(0.0, 1.0);
    return clamped *
        clamped *
        clamped *
        (clamped * (clamped * 6.0 - 15.0) + 10.0);
  }

  // ===========================================================================
  // 👁️ 6. محرك الاستبعاد البصري والفحص المكاني (Viewport Culling)
  // ===========================================================================
  static bool isIntersectingViewport({
    required Offset roomOffset,
    required Size screenSize,
    double cullBuffer = 40.0,
  }) {
    final roomLeft = roomOffset.dx;
    final roomRight = roomOffset.dx + screenSize.width;
    final roomTop = roomOffset.dy;
    final roomBottom = roomOffset.dy + screenSize.height;

    if (roomRight < -cullBuffer) return false;
    if (roomLeft > screenSize.width + cullBuffer) return false;
    if (roomBottom < -cullBuffer) return false;
    if (roomTop > screenSize.height + cullBuffer) return false;

    return true;
  }
}