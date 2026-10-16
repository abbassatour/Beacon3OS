// lib/desktop/cubit/desktop_topology_state.dart
import 'package:equatable/equatable.dart';
import 'package:local_vault_api/local_vault_api.dart';

enum TopologyStatus { initial, loading, success, error }

class DesktopTopologyState extends Equatable {
  const DesktopTopologyState({
    this.status = TopologyStatus.initial,
    this.nodes = const [],
    this.currentFloor = 0,
    this.selectedNodeId,
    this.errorMessage,
  });

  final TopologyStatus status;
  final List<SpatialNode> nodes;
  final int currentFloor;
  final String? selectedNodeId;
  final String? errorMessage;

  /// Ø§Ù„Ø¹ÙÙ‚Ø¯ Ø§Ù„Ù…ÙˆØ¬ÙˆØ¯Ø© ÙÙŠ Ø§Ù„Ø·Ø§Ø¨Ù‚ Ø§Ù„Ù†Ø´Ø· Ø­Ø§Ù„ÙŠØ§Ù‹
  List<SpatialNode> get currentFloorNodes =>
      nodes.where((n) => n.floorLevel == currentFloor).toList();

  /// Ø®Ø±ÙŠØ·Ø© Ø¨Ø±Ù…Ø¬ÙŠØ© Ø³Ø±ÙŠØ¹Ø© Ù„Ù„ÙˆØµÙˆÙ„ Ù„Ù„ØºØ±ÙØ© Ù…Ù† Ø¥Ø­Ø¯Ø§Ø«ÙŠØ§ØªÙ‡Ø§ "X,Y"
  Map<String, SpatialNode> get currentFloorNodeMap {
    final map = <String, SpatialNode>{};
    for (final node in currentFloorNodes) {
      map['${node.x},${node.y}'] = node;
    }
    return map;
  }

  /// Ø§Ù„ØºØ±ÙØ© Ø§Ù„Ù…Ø­Ø¯Ø¯Ø© Ø­Ø§Ù„ÙŠØ§Ù‹ ÙÙŠ Ù„ÙˆØ­Ø© Ø§Ù„ØªÙØªÙŠØ´
  SpatialNode? get selectedNode {
    if (selectedNodeId == null) return null;
    return nodes.where((n) => n.id == selectedNodeId).firstOrNull;
  }

  DesktopTopologyState copyWith({
    TopologyStatus? status,
    List<SpatialNode>? nodes,
    int? currentFloor,
    String? selectedNodeId,
    bool clearSelectedNode = false,
    String? errorMessage,
  }) {
    return DesktopTopologyState(
      status: status ?? this.status,
      nodes: nodes ?? this.nodes,
      currentFloor: currentFloor ?? this.currentFloor,
      selectedNodeId: clearSelectedNode
          ? null
          : (selectedNodeId ?? this.selectedNodeId),
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        nodes,
        currentFloor,
        selectedNodeId,
        errorMessage,
      ];
}
