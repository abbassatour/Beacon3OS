// lib/core/physics/spatial_physics.dart
import 'dart:math' as math;
import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// محرك الفيزياء الحركية الفضائية (Spatial Motion Physics Engine)
/// يعتمد على نوابض Runge-Kutta بالتخميد الحرج ζ = 1.0 لمنع الاهتزاز للكفيف.
class SpatialPhysics {
  SpatialPhysics._();

  // ===========================================================================
  // 📐 1. تكوينات النوابض اللارنينية الحرجة (Critically Damped Springs ζ = 1.0)
  // ===========================================================================

  /// 🎯 نابض الانتقال الأفقي والرأسي (XY-Axis Pan) للغرف
  /// مضبوط بنسبة تخميد حرج دقيقة (Critical Damping ζ = 1.0)
  /// k = 324.0, m = 1.0 => c = 2 * sqrt(1.0 * 324.0) = 36.0
  /// يمنع أي ارتداد زائد (Zero Overshoot / No Jitter) لتوفير ثبات كامل لقارئات الشاشة.
  static const SpringDescription panSpring = SpringDescription(
    mass: 1.0,
    stiffness: 324.0,
    damping: 36.0,
  );

  /// 🏢 نابض الانتقال الرأسي في العمق (Z-Axis Multi-Floor Elevator)
  /// مضبوط بنسبة تخميد حرج دقيقة (Critical Damping ζ = 1.0)
  /// k = 256.0, m = 1.0 => c = 2 * sqrt(1.0 * 256.0) = 32.0
  static const SpringDescription zAxisSpring = SpringDescription(
    mass: 1.0,
    stiffness: 256.0,
    damping: 32.0,
  );

  /// دالة تحقق رياضية من نسبة التخميد (Damping Ratio Verification):
  /// ζ = c / (2 * sqrt(m * k))
  static double calculateDampingRatio(SpringDescription spring) {
    return spring.damping / (2.0 * math.sqrt(spring.mass * spring.stiffness));
  }

  // ===========================================================================
  // 🎥 2. ثوابت المنظور ثلاثي الأبعاد (Spatial Portal Constants)
  // ===========================================================================

  /// معامل المنظور البؤري لمصفوفة Matrix4 (يعادل عدسة كاميرا قياس 35mm-50mm)
  static const double perspectiveCoefficient = 0.0008;

  /// إزاحة البارالاكس الرأسي المصاحبة لنغمة المصعد بالبكسل
  static const double elevationLiftOffset = 30.0;

  // ===========================================================================
  // 🚀 3. مولدات المحاكاة (Simulation Generators)
  // ===========================================================================

  /// يولد محاكاة حركية ناعمة وخالية من الاهتزاز للانتقال بين الغرف
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

  /// يولد محاكاة حركية لمصعد الطوابق في المحور Z
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
  // ✋ 4. حسابات الاحتكاك والمطاطية (Rubber-banding)
  // ===========================================================================

  /// تطبيق مقاومة مطاطية ناعمة عند محاولة السحب خارج حدود الطوابق والغرف
  static double applyRubberBanding({
    required double delta,
    required double limit,
    double stiffness = 0.55,
  }) {
    if (delta == 0) return 0.0;
    final absDelta = delta.abs();
    final rubberDelta =
        limit * (1.0 - (1.0 / ((absDelta * stiffness / limit) + 1.0)));
    return delta < 0 ? -rubberDelta : rubberDelta;
  }

  // ===========================================================================
  // 🌀 5. منحنيات التنعيم الفضائي (Spatial Hermite & Smootherstep Curves)
  // ===========================================================================

  /// دالة التنعيم الكلاسيكية (Cubic Hermite Curve): 3t² - 2t³
  static double smoothStep(double t) {
    final clamped = t.clamp(0.0, 1.0);
    return clamped * clamped * (3.0 - (2.0 * clamped));
  }

  /// دالة التنعيم المتصل خماسية الحدود (Ken Perlin's Smootherstep): 6t⁵ - 15t⁴ + 10t³
  /// C² Continuous لمنع أي رمشة بصرية أثناء انتقال الإضاءة والطبقات
  static double smootherStep(double t) {
    final clamped = t.clamp(0.0, 1.0);
    return clamped *
        clamped *
        clamped *
        (clamped * (clamped * 6.0 - 15.0) + 10.0);
  }

  // ===========================================================================
  // 👁️ 6. محرك الاستبعاد البصري والفحص المكاني (Spatial Culling Tests)
  // ===========================================================================

  /// فحص هل يتقاطع المستطيل الإحداثي للغرفة مع مجال الرؤية للشاشة حالياً
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