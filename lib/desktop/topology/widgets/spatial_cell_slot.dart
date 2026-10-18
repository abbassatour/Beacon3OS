// lib/desktop/topology/widgets/spatial_cell_slot.dart
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/core/topology/topology.dart';
import 'package:beacon_os/desktop/topology/cubit/desktop_topology_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';

extension on String {
  IconData get moduleIcon {
    final module = SpatialModuleRegistry.instance.get(this);
    return module?.icon ?? Icons.widgets_rounded;
  }

  String get defaultTitle {
    final module = SpatialModuleRegistry.instance.get(this);
    return module?.title ?? 'Custom Module';
  }
}

class SpatialCellSlot extends StatefulWidget {
  const SpatialCellSlot({
    required this.x,
    required this.y,
    required this.isCenter,
    required this.node,
    required this.isSelected,
    super.key,
  });

  final int x;
  final int y;
  final bool isCenter;
  final SpatialNodeEntity? node;
  final bool isSelected;

  @override
  State<SpatialCellSlot> createState() => _SpatialCellSlotState();
}

class _SpatialCellSlotState extends State<SpatialCellSlot> {
  bool _isHoveredOver = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cubit = context.read<DesktopTopologyCubit>();

    return DragTarget<SpatialNodeEntity>(
      onWillAcceptWithDetails: (details) => details.data.id != widget.node?.id,
      onAcceptWithDetails: (details) {
        cubit.moveNode(
          nodeId: details.data.id,
          newX: widget.x,
          newY: widget.y,
        );
        setState(() => _isHoveredOver = false);
      },
      onMove: (_) => setState(() => _isHoveredOver = true),
      onLeave: (_) => setState(() => _isHoveredOver = false),
      builder: (context, candidateData, rejectedData) {
        final hasNode = widget.node != null;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: _isHoveredOver
                ? colors.primary.withValues(alpha: 0.12)
                : (widget.isCenter
                    ? colors.secondary.withValues(alpha: 0.05)
                    : context.scaffoldBg.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isHoveredOver
                  ? colors.primary
                  : (widget.isSelected
                      ? colors.primary
                      : (widget.isCenter
                          ? colors.secondary.withValues(alpha: 0.5)
                          : colors.outline.withValues(alpha: 0.4))),
              width: (widget.isSelected || _isHoveredOver) ? 2.0 : 1.0,
            ),
          ),
          child: hasNode
              ? _buildDraggableRoomCard(context, widget.node!)
              : _buildEmptySlot(context),
        );
      },
    );
  }

  Widget _buildEmptySlot(BuildContext context) {
    final colors = context.colors;

    String? cardinalHint;
    if (widget.isCenter) cardinalHint = 'ORIGIN';
    if (widget.x == 0 && widget.y == 1) cardinalHint = 'NORTH';
    if (widget.x == 0 && widget.y == -1) cardinalHint = 'SOUTH';
    if (widget.x == 1 && widget.y == 0) cardinalHint = 'EAST';
    if (widget.x == -1 && widget.y == 0) cardinalHint = 'WEST';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '(${widget.x}, ${widget.y})',
              style: TextStyle(
                color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                fontSize: 8.5,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (cardinalHint != null) ...[
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  cardinalHint,
                  maxLines: 1,
                  style: TextStyle(
                    color: widget.isCenter
                        ? colors.secondary
                        : colors.onSurfaceVariant,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDraggableRoomCard(BuildContext context, SpatialNodeEntity node) {
    final colors = context.colors;
    final cubit = context.read<DesktopTopologyCubit>();
    final icon = node.moduleId.moduleIcon;
    final title = node.customTitle ?? node.moduleId.defaultTitle;

    return Draggable<SpatialNodeEntity>(
      data: node,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: 120,
          height: 80,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.primary, width: 2),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: colors.primary, size: 20),
              const SizedBox(height: 4),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _buildRoomCardContent(context, node, icon, title),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => cubit.selectNode(node.id),
        child: _buildRoomCardContent(context, node, icon, title),
      ),
    );
  }

  Widget _buildRoomCardContent(
    BuildContext context,
    SpatialNodeEntity node,
    IconData icon,
    String title,
  ) {
    final colors = context.colors;

    // 🌟 حواشٍ مدروسة وتغليف مرن ينهي طفح الـ 5.2 و 6.2 و 8.9 بيكسل نهائياً
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: colors.primary, size: 13),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    '${node.x},${node.y}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.primary,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: Center(
              child: Text(
                title,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
            ),
          ),
          Icon(
            Icons.drag_indicator_rounded,
            size: 11,
            color: colors.onSurfaceVariant.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }
}