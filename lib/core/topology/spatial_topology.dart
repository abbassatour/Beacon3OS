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

    // جلب عنوان الغرفة والموديول مباشرة من مصدر الحقيقة الموحد
    final roomTitle = topology.titleAtCoordinate(activeCoord);
    final module = topology.moduleAtCoordinate(activeCoord);

    final canAscend = topology.canAscendFrom(currentFloor);
    final canDescend = topology.canDescendFrom(currentFloor);

    final semanticLabel = isAtCenter
        ? 'Current location: $roomTitle. Floor $currentFloor.'
        : 'Current location: $roomTitle. Tap to return to Cockpit.';

    return Positioned(
      top: 10,
      left: 18,
      right: 18,
      child: Row(
        children: [
          // 1. بطاقة عنوان الغرفة الحالية المسترجعة من قاعدة البيانات
          Expanded(
            child: Semantics(
              label: semanticLabel,
              button: !isAtCenter,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: isAtCenter ? null : onCenterTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surface.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isElevated
                            ? colors.primary
                            : colors.outline.withValues(alpha: 0.8),
                        width: isElevated ? 1.6 : 1.2,
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
                      children: [
                        // أيقونة الغرفة البصرية بدلاً من النقاط المجهرية
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isElevated
                                ? colors.primary.withValues(alpha: 0.15)
                                : colors.primary.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            module?.icon ?? Icons.dashboard_rounded,
                            size: 16,
                            color: colors.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            roomTitle.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isElevated
                                  ? colors.primary
                                  : colors.onSurface,
                              fontSize: 12,
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
          ),
          const SizedBox(width: 8),

          // 2. زر مصعد الطوابق الأنيق الموحد (Floor Elevator Pill)
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onFloorToggle ??
                  (canAscend ? onAscend : (canDescend ? onDescend : null)),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isElevated
                      ? colors.primary
                      : colors.surface.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isElevated
                        ? colors.primary
                        : colors.outline.withValues(alpha: 0.8),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isElevated
                          ? Icons.arrow_downward_rounded
                          : Icons.arrow_upward_rounded,
                      size: 14,
                      color: isElevated ? colors.surface : colors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'FL $currentFloor',
                      style: TextStyle(
                        color: isElevated ? colors.surface : colors.onSurface,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. زر العودة السريعة للمركز (يظهر فقط إذا كان المستخدم خارج قمرة القيادة)
          if (!isAtCenter) ...[
            const SizedBox(width: 6),
            IconButton.filledTonal(
              style: IconButton.styleFrom(
                backgroundColor: colors.surface,
                foregroundColor: colors.onSurface,
                side: BorderSide(
                  color: colors.outline.withValues(alpha: 0.8),
                  width: 1.2,
                ),
                minimumSize: const Size(36, 36),
                padding: EdgeInsets.zero,
              ),
              icon: const Icon(Icons.close_fullscreen_rounded, size: 18),
              tooltip: 'Return to Cockpit Center',
              onPressed: onCenterTap,
            ),
          ],
        ],
      ),
    );
  }
}