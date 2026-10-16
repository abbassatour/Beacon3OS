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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outline.withValues(alpha: 0.7)),
      ),
      child: Column(
        children: [
          // 👈 استخدام Wrap مرن يمنع تجاوز الـ 20 بيكسل على مختلف أحجام الشاشات
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
                spacing: 12,
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
          const SizedBox(height: 14),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const rows = 5;
                const cols = 5;
                final cellWidth = constraints.maxWidth / cols;
                final cellHeight = constraints.maxHeight / rows;

                return GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    childAspectRatio: cellWidth / cellHeight,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
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
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}