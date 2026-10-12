// lib/spatial_shell/widgets/spatial_compass_hud.dart
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/core/topology/topology.dart';
import 'package:beacon_os/spatial_shell/cubit/spatial_shell_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SpatialCompassHud extends StatelessWidget {
  const SpatialCompassHud({
    required this.direction,
    required this.currentFloor,
    required this.onCenterTap,
    this.currentCoordinate,
    this.onFloorToggle,
    this.onAscend,
    this.onDescend,
    this.isSettingsFloor = false,
    super.key,
  });

  final SpatialDirection direction;
  final int currentFloor;
  final SpatialCoordinate? currentCoordinate;
  final bool isSettingsFloor;
  final VoidCallback onCenterTap;
  final VoidCallback? onFloorToggle;
  final VoidCallback? onAscend;
  final VoidCallback? onDescend;

  @override
  Widget build(BuildContext context) {
    final isAtCenter = currentCoordinate?.isOrigin ?? (direction == SpatialDirection.center);
    final isElevated = currentFloor != 0;
    final colors = context.colors;
    final topology = context.read<SpatialTopology>();

    final canAscend = topology.canAscendFrom(currentFloor);
    final canDescend = topology.canDescendFrom(currentFloor);

    return Positioned(
      top: 10,
      left: 18,
      right: 18,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Semantics(
              label:
                  'Spatial compass HUD. Tap to return to cockpit. Double tap to toggle floor.',
              button: true,
              child: GestureDetector(
                onTap: isAtCenter ? null : onCenterTap,
                onDoubleTap: onFloorToggle,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: colors.surface.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isElevated ? colors.primary : colors.outline,
                      width: isElevated ? 1.5 : 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colors.onSurface.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildMiniCompassCross(context, direction, isElevated),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _getDynamicLabel(context, topology),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isElevated ? colors.primary : colors.onSurface,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (canDescend) ...[
                IconButton.filledTonal(
                  style: IconButton.styleFrom(
                    backgroundColor: colors.surface,
                    foregroundColor: colors.onSurface,
                    side: BorderSide(color: colors.outline, width: 1.2),
                    minimumSize: const Size(36, 36),
                    padding: EdgeInsets.zero,
                  ),
                  icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                  tooltip: 'Descend to Floor ${currentFloor - 1}',
                  onPressed: onDescend ?? onFloorToggle,
                ),
                if (canAscend) const SizedBox(width: 5),
              ],
              if (canAscend)
                IconButton.filledTonal(
                  style: IconButton.styleFrom(
                    backgroundColor:
                        isElevated ? colors.surface : colors.primary,
                    foregroundColor:
                        isElevated ? colors.onSurface : colors.onPrimary,
                    side: BorderSide(
                      color: isElevated ? colors.outline : colors.primary,
                      width: 1.2,
                    ),
                    minimumSize: const Size(36, 36),
                    padding: EdgeInsets.zero,
                  ),
                  icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                  tooltip: 'Ascend to Floor ${currentFloor + 1}',
                  onPressed: onAscend ?? onFloorToggle,
                ),
              if (!isAtCenter) ...[
                const SizedBox(width: 6),
                IconButton.filledTonal(
                  style: IconButton.styleFrom(
                    backgroundColor: colors.surface,
                    foregroundColor: colors.onSurface,
                    side: BorderSide(color: colors.outline, width: 1.2),
                    minimumSize: const Size(36, 36),
                    padding: EdgeInsets.zero,
                  ),
                  icon: const Icon(Icons.close_fullscreen_rounded, size: 18),
                  tooltip: 'Return to Center',
                  onPressed: onCenterTap,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniCompassCross(
    BuildContext context,
    SpatialDirection activeDir,
    bool isElevated,
  ) {
    final colors = context.colors;
    final activeColor = isElevated ? colors.primary : colors.onSurface;
    final inactiveColor = colors.outline;

    return SizedBox(
      width: 18,
      height: 18,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 0,
            child: _dot(
              activeDir == SpatialDirection.north,
              activeColor,
              inactiveColor,
            ),
          ),
          Positioned(
            bottom: 0,
            child: _dot(
              activeDir == SpatialDirection.south,
              activeColor,
              inactiveColor,
            ),
          ),
          Positioned(
            right: 0,
            child: _dot(
              activeDir == SpatialDirection.east,
              activeColor,
              inactiveColor,
            ),
          ),
          Positioned(
            left: 0,
            child: _dot(
              activeDir == SpatialDirection.west,
              activeColor,
              inactiveColor,
            ),
          ),
          Positioned(
            child: _dot(
              activeDir == SpatialDirection.center,
              activeColor,
              inactiveColor,
              isCenter: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(
    bool isActive,
    Color activeColor,
    Color inactiveColor, {
    bool isCenter = false,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      width: isActive ? (isCenter ? 5 : 4) : 3,
      height: isActive ? (isCenter ? 5 : 4) : 3,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? activeColor : inactiveColor,
      ),
    );
  }

  String _getDynamicLabel(BuildContext context, SpatialTopology topology) {
    final coord = currentCoordinate;
    final module = coord != null
        ? topology.moduleAtCoordinate(coord)
        : topology.moduleAt(currentFloor, direction);

    final prefix = currentFloor != 0 ? 'FL $currentFloor • ' : '';
    if (module != null) {
      return '$prefix${module.getFloorTitle(currentFloor)}';
    }
    if (coord != null) {
      return '${prefix}ROOM (${coord.x}, ${coord.y})';
    }
    return '$prefix${direction.name.toUpperCase()}';
  }
}