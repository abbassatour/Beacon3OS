// lib/desktop/topology/widgets/spatial_grid_canvas.dart
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/desktop/topology/cubit/desktop_topology_state.dart';
import 'package:beacon_os/desktop/topology/widgets/spatial_cell_slot.dart';
import 'package:flutter/material.dart';

class SpatialGridCanvas extends StatelessWidget {
  const SpatialGridCanvas({required this.state, super.key});

  final DesktopTopologyState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outline.withValues(alpha: 0.7)),
      ),
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              Text(
                'CARTESIAN MATRIX (X: -2..+2, Y: -2..+2)',
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _legendDot(colors.primary, 'Active Room'),
                  _legendDot(colors.secondary, 'Center (Origin)'),
                  _legendDot(colors.outline, 'Empty Slot'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const rows = 5;
                const cols = 5;
                const spacing = 8.0;

                // 🌟 حساب هندسي دقيق يخصم المسافات البينية (32px) لمنع انحراف النسبة والطفح
                final totalSpacingX = (cols - 1) * spacing;
                final totalSpacingY = (rows - 1) * spacing;

                final cellWidth = (constraints.maxWidth - totalSpacingX) / cols;
                final cellHeight = (constraints.maxHeight - totalSpacingY) / rows;
                final aspectRatio = (cellWidth / cellHeight).clamp(0.6, 2.5);

                return GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    childAspectRatio: aspectRatio,
                    crossAxisSpacing: spacing,
                    mainAxisSpacing: spacing,
                  ),
                  itemCount: rows * cols,
                  itemBuilder: (context, index) {
                    final row = index ~/ cols;
                    final col = index % cols;

                    final x = col - 2;
                    final y = 2 - row;

                    final node = state.currentFloorNodeMap['$x,$y'];
                    final isCenter = x == 0 && y == 0;

                    return SpatialCellSlot(
                      x: x,
                      y: y,
                      isCenter: isCenter,
                      node: node,
                      isSelected: state.selectedNodeId == node?.id,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}