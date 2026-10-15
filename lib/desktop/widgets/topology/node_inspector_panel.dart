import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/core/topology/topology.dart';
import 'package:beacon_os/desktop/cubit/desktop_topology_cubit.dart';
import 'package:beacon_os/desktop/cubit/desktop_topology_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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

class NodeInspectorPanel extends StatefulWidget {
  const NodeInspectorPanel({required this.state, super.key});

  final DesktopTopologyState state;

  @override
  State<NodeInspectorPanel> createState() => _NodeInspectorPanelState();
}

class _NodeInspectorPanelState extends State<NodeInspectorPanel> {
  late TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.state.selectedNode?.customTitle ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant NodeInspectorPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.selectedNodeId != widget.state.selectedNodeId) {
      _titleController.text = widget.state.selectedNode?.customTitle ?? '';
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