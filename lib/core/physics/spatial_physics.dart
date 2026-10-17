// lib/core/physics/spatial_physics.dart
import 'dart:math' as math;
import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// محرك الفيزياء الحركية الفضائية (Spatial Motion Physics Engine)
class SpatialPhysics {
  SpatialPhysics._();

  // ===========================================================================
  // 📐 1. تكوينات النوابض اللارنينية المضبوطة بدقة للسرعة والخفة
  // ===========================================================================

  /// 🎯 نابض الانتقال الأفقي والرأسي (XY-Axis Pan) للغرف
  /// تم تخفيف الكتلة وزيادة القساوة مع تخميد انسيابي لمنع الشعور بالثقل
  static const SpringDescription panSpring = SpringDescription(
    mass: 0.8,
    stiffness: 420.0,
    damping: 28.0,
  );

  /// 🏢 نابض الانتقال الرأسي في العمق (Z-Axis Multi-Floor Elevator)
  static const SpringDescription zAxisSpring = SpringDescription(
    mass: 1.0,
    stiffness: 256.0,
    damping: 32.0,
  );

  /// دالة تحقق رياضية من نسبة التخميد
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