// lib/desktop/view/desktop_topology_view.dart
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/desktop/cubit/desktop_topology_cubit.dart';
import 'package:beacon_os/desktop/cubit/desktop_topology_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';
import 'package:local_vault_api/local_vault_api.dart';

extension on String {
  IconData get moduleIcon {
    switch (this) {
      case 'cockpit':
        return Icons.dashboard_rounded;
      case 'focus':
        return Icons.hourglass_top_rounded;
      case 'comms':
        return Icons.chat_bubble_outline_rounded;
      case 'vision':
        return Icons.visibility_rounded;
      case 'agenda':
        return Icons.calendar_today_rounded;
      default:
        return Icons.widgets_rounded;
    }
  }

  String get defaultTitle {
    switch (this) {
      case 'cockpit':
        return 'Today Cockpit';
      case 'focus':
        return 'Focus & Alarms';
      case 'comms':
        return 'Communications';
      case 'vision':
        return 'AI Vision Studio';
      case 'agenda':
        return 'Agenda & Tasks';
      default:
        return 'Custom Module';
    }
  }
}

class DesktopTopologyView extends StatelessWidget {
  const DesktopTopologyView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DesktopTopologyCubit(
        topologyRepository: context.read<TopologyRepository>(),
      ),
      child: const _DesktopTopologyContent(),
    );
  }
}

class _DesktopTopologyContent extends StatelessWidget {
  const _DesktopTopologyContent();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return BlocBuilder<DesktopTopologyCubit, DesktopTopologyState>(
      builder: (context, state) {
        if (state.status == TopologyStatus.loading && state.nodes.isEmpty) {
          return Center(
            child: CircularProgressIndicator(color: colors.primary),
          );
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. الشريط العلوي للأدوات وتبديل الطوابق
                _TopologyHeader(state: state),
                const SizedBox(height: 20),

                // 2. المحتوى الرئيسي: الكانفاس + لوحة التفتيش
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // شبكة الكانفاس الديكارتية
                      Expanded(
                        flex: 7,
                        child: _SpatialGridCanvas(state: state),
                      ),
                      const SizedBox(width: 20),

                      // لوحة التفتيش وتعديل خصائص الغرفة
                      Expanded(
                        flex: 3,
                        child: _NodeInspectorPanel(state: state),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TopologyHeader extends StatelessWidget {
  const _TopologyHeader({required this.state});

  final DesktopTopologyState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cubit = context.read<DesktopTopologyCubit>();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.grid_view_rounded, color: colors.primary, size: 26),
                const SizedBox(width: 10),
                Text(
                  'SPATIAL TOPOLOGY STUDIO',
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Drag rooms across the Cartesian grid to update spatial phone gestures in real-time.',
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
        Row(
          children: [
            // محدد الطوابق (Floor Selector)
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
                    label: 'Floor 0 • Today Canvas',
                    isSelected: state.currentFloor == 0,
                    onTap: () => cubit.selectFloor(0),
                  ),
                  const SizedBox(width: 4),
                  _FloorButton(
                    label: 'Floor 1 • Engine & Settings',
                    isSelected: state.currentFloor == 1,
                    onTap: () => cubit.selectFloor(1),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),

            // زر استعادة التوزيع الافتراضي
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
                'Reset Layout',
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

class _SpatialGridCanvas extends StatelessWidget {
  const _SpatialGridCanvas({required this.state});

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
              Row(
                children: [
                  _legendDot(colors.primary, 'Active Room'),
                  const SizedBox(width: 14),
                  _legendDot(colors.secondary, 'Center (Origin)'),
                  const SizedBox(width: 14),
                  _legendDot(colors.outline, 'Empty Slot'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // الشبكة 5×5
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

                    // تحويل الفهرس إلى إحداثيات ديكارتية
                    final x = col - 2;
                    final y = 2 - row;

                    final node = state.currentFloorNodeMap['$x,$y'];
                    final isCenter = x == 0 && y == 0;

                    return _SpatialCellSlot(
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

class _SpatialCellSlot extends StatefulWidget {
  const _SpatialCellSlot({
    required this.x,
    required this.y,
    required this.isCenter,
    required this.node,
    required this.isSelected,
  });

  final int x;
  final int y;
  final bool isCenter;
  final SpatialNode? node;
  final bool isSelected;

  @override
  State<_SpatialCellSlot> createState() => _SpatialCellSlotState();
}

class _SpatialCellSlotState extends State<_SpatialCellSlot> {
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
    if (widget.x == 0 && widget.y == 1) cardinalHint = 'NORTH ⬆️';
    if (widget.x == 0 && widget.y == -1) cardinalHint = 'SOUTH ⬇️';
    if (widget.x == 1 && widget.y == 0) cardinalHint = 'EAST ➡️';
    if (widget.x == -1 && widget.y == 0) cardinalHint = 'WEST ⬅️';

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

class _NodeInspectorPanel extends StatefulWidget {
  const _NodeInspectorPanel({required this.state});

  final DesktopTopologyState state;

  @override
  State<_NodeInspectorPanel> createState() => _NodeInspectorPanelState();
}

class _NodeInspectorPanelState extends State<_NodeInspectorPanel> {
  late TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.state.selectedNode?.customTitle ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant _NodeInspectorPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.selectedNodeId != widget.state.selectedNodeId) {
      _titleController.text =
          widget.state.selectedNode?.customTitle ?? '';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cubit = context.read<DesktopTopologyCubit>();
    final node = widget.state.selectedNode;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outline.withValues(alpha: 0.7)),
      ),
      child: node == null
          ? _buildEmptyInspector(context)
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // رأس اللوحة
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            node.moduleId.moduleIcon,
                            color: colors.primary,
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'ROOM INSPECTOR',
                            style: TextStyle(
                              color: colors.onSurface,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => cubit.selectNode(null),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // بطاقة الإحداثيات الحالية
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: context.scaffoldBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MODULE IDENTIFIER: ${node.moduleId.toUpperCase()}',
                          style: TextStyle(
                            color: colors.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Coordinates: X = ${node.x}, Y = ${node.y}',
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'Floor Level: Floor ${node.floorLevel}',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // لوحة أزرار التوجيه الدقيق (D-Pad Nudge)
                  Text(
                    'COORDINATE NUDGE',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: SizedBox(
                      width: 130,
                      height: 110,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned(
                            top: 0,
                            child: _nudgeBtn(
                              icon: Icons.keyboard_arrow_up_rounded,
                              onTap: () => cubit.nudgeNode(
                                nodeId: node.id,
                                deltaX: 0,
                                deltaY: 1,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            child: _nudgeBtn(
                              icon: Icons.keyboard_arrow_down_rounded,
                              onTap: () => cubit.nudgeNode(
                                nodeId: node.id,
                                deltaX: 0,
                                deltaY: -1,
                              ),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            child: _nudgeBtn(
                              icon: Icons.keyboard_arrow_left_rounded,
                              onTap: () => cubit.nudgeNode(
                                nodeId: node.id,
                                deltaX: -1,
                                deltaY: 0,
                              ),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            child: _nudgeBtn(
                              icon: Icons.keyboard_arrow_right_rounded,
                              onTap: () => cubit.nudgeNode(
                                nodeId: node.id,
                                deltaX: 1,
                                deltaY: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // تعديل اسم الغرفة
                  Text(
                    'CUSTOM ROOM TITLE',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      hintText: node.moduleId.defaultTitle,
                      filled: true,
                      fillColor: context.scaffoldBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: colors.outline),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      cubit.updateNodeTitle(
                        nodeId: node.id,
                        customTitle: _titleController.text,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Room title updated!'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    child: const Text('Save Title'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _nudgeBtn({required IconData icon, required VoidCallback onTap}) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colors.outline),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 20, color: colors.onSurface),
        ),
      ),
    );
  }

  Widget _buildEmptyInspector(BuildContext context) {
    final colors = context.colors;
    final cubit = context.read<DesktopTopologyCubit>();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.touch_app_rounded,
          color: colors.onSurfaceVariant.withValues(alpha: 0.5),
          size: 44,
        ),
        const SizedBox(height: 14),
        Text(
          'SELECT A ROOM',
          style: TextStyle(
            color: colors.onSurface,
            fontWeight: FontWeight.w900,
            fontSize: 14,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Click any room on the grid to inspect details, tweak coordinate offsets, or rename it.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 12),
        Text(
          'ROOMS ON THIS FLOOR (${widget.state.currentFloorNodes.length})',
          style: TextStyle(
            color: colors.onSurfaceVariant,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView(
            children: widget.state.currentFloorNodes.map((node) {
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(node.moduleId.moduleIcon, size: 18),
                title: Text(
                  node.customTitle ?? node.moduleId.defaultTitle,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                trailing: Text(
                  '(${node.x}, ${node.y})',
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
                onTap: () => cubit.selectNode(node.id),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}