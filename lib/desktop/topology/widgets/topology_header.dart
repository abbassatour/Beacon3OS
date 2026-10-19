// lib/desktop/topology/widgets/topology_header.dart
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/desktop/topology/cubit/desktop_topology_cubit.dart';
import 'package:beacon_os/desktop/topology/cubit/desktop_topology_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TopologyHeader extends StatelessWidget {
  const TopologyHeader({required this.state, super.key});

  final DesktopTopologyState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cubit = context.read<DesktopTopologyCubit>();

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.grid_view_rounded, color: colors.primary, size: 26),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'SPATIAL TOPOLOGY STUDIO',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Drag rooms across the Cartesian grid to update spatial phone gestures in real-time.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.outline.withValues(alpha: 0.7)),
              ),
              child: Row(
                children: [
                  _FloorButton(
                    label: 'Floor -1 - Vault',
                    isSelected: state.currentFloor == -1,
                    onTap: () => cubit.selectFloor(-1),
                  ),
                  const SizedBox(width: 4),
                  _FloorButton(
                    label: 'Floor 0 - Canvas',
                    isSelected: state.currentFloor == 0,
                    onTap: () => cubit.selectFloor(0),
                  ),
                  const SizedBox(width: 4),
                  _FloorButton(
                    label: 'Floor 1 - Engine',
                    isSelected: state.currentFloor == 1,
                    onTap: () => cubit.selectFloor(1),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                backgroundColor: colors.surface,
                foregroundColor: colors.onSurface,
                side: BorderSide(color: colors.outline),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              icon: const Icon(Icons.restart_alt_rounded, size: 18),
              label: const Text(
                'Reset',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              onPressed: () => cubit.resetFloorToDefaults(),
            ),
          ],
        ),
      ],
    );
  }
}

class _FloorButton extends StatelessWidget {
  const _FloorButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      color: isSelected
          ? colors.primary.withValues(alpha: 0.15)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? colors.primary : colors.onSurfaceVariant,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}