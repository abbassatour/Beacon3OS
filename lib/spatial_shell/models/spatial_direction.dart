// lib/spatial_shell/models/spatial_direction.dart
import 'package:flutter/widgets.dart';

/// الاتجاهات المكانية للمركز الملاحي
enum SpatialDirection {
  center, // المركز: قمرة اليوم
  north,  // الأعلى: المذاكرة والمنبهات
  south,  // الأسفل: الرسائل والتواصل
  east,   // اليمين: استوديو الرؤية والذكاء
  west,   // اليسار: الأجندة والمهام
}

// 🛡️ اسم توافقي كامل لمنع انكسار الكود في أي مكان بالنظام
typedef CompassDirection = SpatialDirection;

extension SpatialDirectionX on SpatialDirection {
  /// الإزاحة المكانية لكل غرفة بالنسبة للمركز داخل مصفوفة التحويلات
  Offset get translation {
    switch (this) {
      case SpatialDirection.center:
        return Offset.zero;
      case SpatialDirection.north:
        return const Offset(0, -1);
      case SpatialDirection.south:
        return const Offset(0, 1);
      case SpatialDirection.east:
        return const Offset(1, 0);
      case SpatialDirection.west:
        return const Offset(-1, 0);
    }
  }

  /// رمز السهم التعبيري الدال على الاتجاه
  String get arrowSymbol {
    switch (this) {
      case SpatialDirection.center:
        return '⏺️';
      case SpatialDirection.north:
        return '⬆️';
      case SpatialDirection.south:
        return '⬇️';
      case SpatialDirection.east:
        return '➡️';
      case SpatialDirection.west:
        return '⬅️';
    }
  }

  /// 🎯 التلميح الحركي المستقر للعودة للمركز دون إملاء اتجاه سحب متضارب
  String get returnGestureHint {
    switch (this) {
      case SpatialDirection.center:
        return 'At Center';
      case SpatialDirection.north:
      case SpatialDirection.south:
      case SpatialDirection.east:
      case SpatialDirection.west:
        return 'Use HUD';
    }
  }
}