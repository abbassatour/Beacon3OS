import 'package:beacon_os/core/topology/spatial_coordinate.dart';
import 'package:beacon_os/mobile/shell/models/spatial_direction.dart';
import 'package:beacon_os/mobile/shell/models/spatial_gestures.dart';
import 'package:equatable/equatable.dart';

export 'package:beacon_os/core/topology/spatial_coordinate.dart';
export 'package:beacon_os/mobile/shell/models/spatial_direction.dart';
export 'package:beacon_os/mobile/shell/models/spatial_gestures.dart';
class SpatialShellState extends Equatable {
  const SpatialShellState({
    this.currentCoordinate = SpatialCoordinate.origin,
    this.previousCoordinate = SpatialCoordinate.origin,
    this.isTransitioning = false,
    this.activeModuleId = 'cockpit', // 👈 معرّف الغرفة التي ينظر إليها المستخدم
  });

  /// الإحداثي الديكارتي ثلاثي الأبعاد الحالي للمستخدم في الفضاء
  final SpatialCoordinate currentCoordinate;

  /// الإحداثي الديكارتي السابق
  final SpatialCoordinate previousCoordinate;

  final bool isTransitioning;

  /// معرّف الموديول النشط حالياً على الشاشة
  final String activeModuleId;

  /// رقم الطابق مشتق مباشرة من المحور Z للإحداثي
  int get currentFloor => currentCoordinate.floor;

  /// هل المستخدم في مركز الطابق (0, 0)
  bool get isAtCenter => currentCoordinate.isOrigin;
  bool get isGroundFloor => currentCoordinate.floor == 0;
  bool get isSettingsFloor => currentCoordinate.floor == 1;

  /// 🛡️ توافق عكسي مع واجهات البوصلة والـ HUD القديمة
  SpatialDirection get currentDirection =>
      currentCoordinate.toCompassDirection();

  SpatialDirection get previousDirection =>
      previousCoordinate.toCompassDirection();

  SpatialShellState copyWith({
    SpatialCoordinate? currentCoordinate,
    SpatialCoordinate? previousCoordinate,
    bool? isTransitioning,
    int? currentFloor,
    SpatialDirection? currentDirection,
    SpatialDirection? previousDirection,
    String? activeModuleId,
  }) {
    final nextCoord = currentCoordinate ??
        (currentDirection != null
            ? SpatialCoordinate.fromDirection(
                currentDirection,
                floor: currentFloor ?? this.currentFloor,
              )
            : (currentFloor != null
                ? this.currentCoordinate.copyWith(floor: currentFloor)
                : this.currentCoordinate));

    final prevCoord = previousCoordinate ??
        (previousDirection != null
            ? SpatialCoordinate.fromDirection(
                previousDirection,
                floor: this.previousCoordinate.floor,
              )
            : this.previousCoordinate);

    return SpatialShellState(
      currentCoordinate: nextCoord,
      previousCoordinate: prevCoord,
      isTransitioning: isTransitioning ?? this.isTransitioning,
      activeModuleId: activeModuleId ?? this.activeModuleId,
    );
  }

  @override
  List<Object?> get props => [
        currentCoordinate,
        previousCoordinate,
        isTransitioning,
        activeModuleId,
      ];
}

// 🛡️ توافق كامل مع الكود السابق
typedef SpatialCompassState = SpatialShellState;