// lib/core/topology/spatial_coordinate.dart
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

  /// الإحداثي الأفقي (0 المركز، 1 اليمين، -1 اليسار)
  final int x;

  /// الإحداثي الرأسي الديكارتي (0 المركز، 1 الشمال/الأعلى، -1 الجنوب/الأسفل)
  final int y;

  /// رقم الطابق (المحور الرأسي في العمق Z)
  final int floor;

  /// نقطة الأصل الافتراضية
  static const origin = SpatialCoordinate(x: 0, y: 0, floor: 0);

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

  /// محاذاة الإحداثي مع اتجاه بوصلة كلاسيكي إن وجد (للتوافق مع الـ HUD والنطق الصوتي)
  SpatialDirection? toCompassDirection() {
    if (x == 0 && y == 0) return SpatialDirection.center;
    if (x == 0 && y == 1) return SpatialDirection.north;
    if (x == 0 && y == -1) return SpatialDirection.south;
    if (x == 1 && y == 0) return SpatialDirection.east;
    if (x == -1 && y == 0) return SpatialDirection.west;
    return null;
  }

  /// إزاحة الشاشة البصرية بالبكسل بالنسبة للشاشة (مع مراعاة أن Y على الشاشة ينعكس لأسفل)
  Offset get screenTranslation => Offset(x.toDouble(), -y.toDouble());

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