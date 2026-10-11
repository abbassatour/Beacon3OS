// lib/spatial_shell/widgets/spatial_floor_layout.dart
import 'package:beacon_os/core/topology/topology.dart'; // 👈 تم التصحيح
import 'package:beacon_os/spatial_shell/cubit/spatial_shell_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// المخطط الفضائي الموحد لأي طابق في النظام (يدعم الطوابق: ... -1, 0, 1, 2 ...)
class SpatialFloorLayout extends StatelessWidget {
  const SpatialFloorLayout({
    required this.direction,
    required this.floorLevel,
    this.panOffset = Offset.zero,
    super.key,
  });

  final SpatialDirection direction;
  final int floorLevel;
  final Offset panOffset;

  @override
  Widget build(BuildContext context) {
    final topology = context.read<SpatialTopology>();
    final roomsOnFloor = topology.roomsOnFloor(floorLevel);
    final size = MediaQuery.of(context).size;

    return RepaintBoundary(
      child: Stack(
        clipBehavior: Clip.none,
        children: roomsOnFloor.entries.map((entry) {
          final roomDir = entry.key;
          final module = entry.value;

          final isActive = direction == roomDir;
          final isCenter = roomDir == SpatialDirection.center;
          final isProcessingAllowed = isActive || isCenter;

          final roomOffset = Offset(
            roomDir.translation.dx * size.width + panOffset.dx,
            roomDir.translation.dy * size.height + panOffset.dy,
          );

          return Transform.translate(
            key: ValueKey('floor_${floorLevel}_dir_${roomDir.name}'),
            offset: roomOffset,
            child: RepaintBoundary(
              child: TickerMode(
                enabled: isProcessingAllowed,
                child: IgnorePointer(
                  ignoring: !isActive,
                  child: ExcludeSemantics(
                    excluding: !isActive,
                    child: FocusScope(
                      canRequestFocus: isActive,
                      child: module.buildFloorView(context, floorLevel),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// 🛡️ أسماء توافقية لمنع انكسار الكود
typedef CoreFloorLayout = SpatialFloorLayout;
typedef SettingsFloorLayout = SpatialFloorLayout;
typedef CompassTransitionLayout = SpatialFloorLayout;