// lib/spatial_shell/cubit/spatial_shell_state.dart
import 'package:beacon_os/spatial_shell/models/spatial_direction.dart';
import 'package:beacon_os/spatial_shell/models/spatial_gestures.dart';
import 'package:equatable/equatable.dart';

export 'package:beacon_os/spatial_shell/models/spatial_direction.dart';
export 'package:beacon_os/spatial_shell/models/spatial_gestures.dart';

class SpatialShellState extends Equatable {
  const SpatialShellState({
    this.currentDirection = SpatialDirection.center,
    this.previousDirection = SpatialDirection.center,
    this.isTransitioning = false,
    this.currentFloor = 0,
  });

  final SpatialDirection currentDirection;
  final SpatialDirection previousDirection;
  final bool isTransitioning;
  final int currentFloor;

  bool get isAtCenter => currentDirection == SpatialDirection.center;
  bool get isGroundFloor => currentFloor == 0;
  bool get isSettingsFloor => currentFloor == 1;

  SpatialShellState copyWith({
    SpatialDirection? currentDirection,
    SpatialDirection? previousDirection,
    bool? isTransitioning,
    int? currentFloor,
  }) {
    return SpatialShellState(
      currentDirection: currentDirection ?? this.currentDirection,
      previousDirection: previousDirection ?? this.previousDirection,
      isTransitioning: isTransitioning ?? this.isTransitioning,
      currentFloor: currentFloor ?? this.currentFloor,
    );
  }

  @override
  List<Object?> get props => [
        currentDirection,
        previousDirection,
        isTransitioning,
        currentFloor,
      ];
}

// 🛡️ توافق كامل مع الكود السابق
typedef SpatialCompassState = SpatialShellState;