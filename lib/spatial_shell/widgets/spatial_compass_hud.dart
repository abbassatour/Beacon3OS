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
    final activeCoord = currentCoordinate ?? SpatialCoordinate.origin;
    final isAtCenter = activeCoord.isOrigin;
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
                      // ⚡️ رادار ديناميكي يعكس التوزيع الفعلي للغرف في الطابق
                      _buildAdaptiveRadarPips(
                        context: context,
                        topology: topology,
                        currentFloor: currentFloor,
                        activeCoord: activeCoord,
                        isElevated: isElevated,
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          _getDynamicLabel(context, topology, activeCoord),
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

  /// 🛰️ رادار مصغر يعرض مواقع الغرف الحقيقية في مصفوفة الطابق لحظياً
  Widget _buildAdaptiveRadarPips({
    required BuildContext context,
    required SpatialTopology topology,
    required int currentFloor,
    required SpatialCoordinate activeCoord,
    required bool isElevated,
  }) {
    final colors = context.colors;
    final activeColor = isElevated ? colors.primary : colors.onSurface;
    final inactiveColor = colors.outline.withValues(alpha: 0.5);

    final occupiedNodes = topology.nodesOnFloor(currentFloor).keys.toSet();
    // التأكد من احتساب موقع المستخدم الحالي دائماً
    occupiedNodes.add(activeCoord);

    return SizedBox(
      width: 22,
      height: 22,
      child: Stack(
        alignment: Alignment.center,
        children: occupiedNodes.map((coord) {
          final isCurrent =
              coord.x == activeCoord.x && coord.y == activeCoord.y;

          // تحويل الإحداثيات الديكارتية (-2..+2) إلى بكسلات داخل صندوق 22x22
          // المركز عند (11, 11)، وكل وحدة إحداثية تقابل 4.5 بكسل
          final dotSize = isCurrent ? 5.0 : 3.0;
          final left = 11.0 + (coord.x * 4.5) - (dotSize / 2);
          final top = 11.0 - (coord.y * 4.5) - (dotSize / 2);

          return Positioned(
            left: left.clamp(0.0, 18.0),
            top: top.clamp(0.0, 18.0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCurrent ? activeColor : inactiveColor,
                boxShadow: [
                  if (isCurrent)
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.5),
                      blurRadius: 4,
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _getDynamicLabel(
    BuildContext context,
    SpatialTopology topology,
    SpatialCoordinate coord,
  ) {
    final module = topology.moduleAtCoordinate(coord);
    final prefix = currentFloor != 0 ? 'FL $currentFloor • ' : '';
    final roomName = module != null
        ? module.getFloorTitle(currentFloor)
        : 'ROOM ${coord.formattedCoordinate}';

    final coordSuffix = !coord.isOrigin ? ' ${coord.formattedCoordinate}' : '';
    return '$prefix$roomName$coordSuffix';
  }
}