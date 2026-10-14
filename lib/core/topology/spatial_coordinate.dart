// lib/core/topology/spatial_coordinate.dart
import 'dart:math' as math;
import 'package:beacon_os/spatial_shell/models/spatial_direction.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

/// يمثل نقطة إحداثية ثلاثية الأبعاد (X, Y, Z) في فضاء BeaconOS
class SpatialCoordinate extends Equatable {
  const SpatialCoordinate({
    required this.x,
    required this.y,
    this.floor = 0,
  });

  /// الإحداثي الأفقي (0 المركز، موجب لليمين، سالب لليسار)
  final int x;

  /// الإحداثي الرأسي الديكارتي (0 المركز، موجب للشمال/الأعلى، سالب للجنوب/الأسفل)
  final int y;

  /// رقم الطابق (المحور الرأسي في العمق Z)
  final int floor;

  /// نقطة الأصل الافتراضية
  static const origin = SpatialCoordinate(x: 0, y: 0, floor: 0);

  /// هل تقع هذه النقطة في مركز الطابق؟
  bool get isOrigin => x == 0 && y == 0;

  /// المسافة الإقليدية (Euclidean Distance) عن إحداثي آخر
  double distanceTo(SpatialCoordinate other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// مسافة مانهاتن (عدد الخطوات الشبكية)
  int manhattanDistanceTo(SpatialCoordinate other) {
    return (x - other.x).abs() + (y - other.y).abs();
  }

  /// تحويل اتجاه البوصلة الكلاسيكي إلى إحداثي رياضي مباشر
  factory SpatialCoordinate.fromDirection(SpatialDirection direction, {int floor = 0}) {
    switch (direction) {
      case SpatialDirection.center:
        return SpatialCoordinate(x: 0, y: 0, floor: floor);
      case SpatialDirection.north:
        return SpatialCoordinate(x: 0, y: 1, floor: floor);
      case SpatialDirection.south:
        return SpatialCoordinate(x: 0, y: -1, floor: floor);
      case SpatialDirection.east:
        return SpatialCoordinate(x: 1, y: 0, floor: floor);
      case SpatialDirection.west:
        return SpatialCoordinate(x: -1, y: 0, floor: floor);
    }
  }

  /// 🧭 حساب الاتجاه الكاردينالي الحقيقي والنسبي لأي نقطة في المصفوفة الديكارتية (5x5)
  /// يضمن عدم إرجاع null إطلاقاً لأي غرفة منقولة
  SpatialDirection toCompassDirection() {
    if (x == 0 && y == 0) return SpatialDirection.center;

    // حساب المحور المهيمن وفق الزاوية النسبية
    if (x.abs() > y.abs()) {
      return x > 0 ? SpatialDirection.east : SpatialDirection.west;
    } else {
      return y > 0 ? SpatialDirection.north : SpatialDirection.south;
    }
  }

  /// إزاحة الشاشة البصرية بالبكسل بالنسبة للشاشة (مع مراعاة أن Y على الشاشة ينعكس لأسفل)
  Offset get screenTranslation => Offset(x.toDouble(), -y.toDouble());

  /// نص الإحداثي بصيغة (X, Y)
  String get formattedCoordinate => '($x, $y)';

  SpatialCoordinate copyWith({int? x, int? y, int? floor}) {
    return SpatialCoordinate(
      x: x ?? this.x,
      y: y ?? this.y,
      floor: floor ?? this.floor,
    );
  }

  @override
  List<Object?> get props => [x, y, floor];

  @override
  String toString() => 'SpatialCoordinate(x: $x, y: $y, floor: $floor)';
}