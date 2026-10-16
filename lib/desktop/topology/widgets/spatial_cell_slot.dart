import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/core/topology/topology.dart';
import 'package:beacon_os/desktop/topology/cubit/desktop_topology_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:local_vault_api/local_vault_api.dart';

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
  final SpatialNode? node;
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

    return DragTarget<SpatialNode>(
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
            borderRadius: BorderRadius.circular(14),
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
    if (widget.x == 0 && widget.y == 1) cardinalHint = 'NORTH [UP]';
    if (widget.x == 0 && widget.y == -1) cardinalHint = 'SOUTH [DOWN]';
    if (widget.x == 1 && widget.y == 0) cardinalHint = 'EAST [RIGHT]';
    if (widget.x == -1 && widget.y == 0) cardinalHint = 'WEST [LEFT]';

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '(${widget.x}, ${widget.y})',
            style: TextStyle(
              color: colors.onSurfaceVariant.withValues(alpha: 0.6),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (cardinalHint != null) ...[
            const SizedBox(height: 2),
            Text(
              cardinalHint,
              style: TextStyle(
                color: widget.isCenter ? colors.secondary : colors.onSurfaceVariant,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDraggableRoomCard(BuildContext context, SpatialNode node) {
    final colors = context.colors;
    final cubit = context.read<DesktopTopologyCubit>();
    final icon = node.moduleId.moduleIcon;
    final title = node.customTitle ?? node.moduleId.defaultTitle;

    return Draggable<SpatialNode>(
      data: node,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: 130,
          height: 90,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.primary, width: 2),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withValues(alpha: 0.3),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: colors.primary, size: 24),
              const SizedBox(height: 4),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 11,
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
        borderRadius: BorderRadius.circular(14),
        onTap: () => cubit.selectNode(node.id),
        child: _buildRoomCardContent(context, node, icon, title),
      ),
    );
  }

  Widget _buildRoomCardContent(
    BuildContext context,
    SpatialNode node,
    IconData icon,
    String title,
  ) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: colors.primary, size: 18),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${node.x},${node.y}',
                  style: TextStyle(
                    color: colors.primary,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          Text(
            title,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          Icon(
            Icons.drag_indicator_rounded,
            size: 14,
            color: colors.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ],
      ),
    );
  }
}
