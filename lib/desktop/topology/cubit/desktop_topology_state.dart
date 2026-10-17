// lib/desktop/topology/cubit/desktop_topology_state.dart
import 'package:equatable/equatable.dart';
import 'package:launcher_repository/launcher_repository.dart';

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
  final List<SpatialNodeEntity> nodes;
  final int currentFloor;
  final String? selectedNodeId;
  final String? errorMessage;

  /// العُقد الموجودة في الطابق النشط حالياً
  List<SpatialNodeEntity> get currentFloorNodes =>
      nodes.where((n) => n.floorLevel == currentFloor).toList();

  /// خريطة برمجية سريعة للوصول للغرفة من إحداثياتها "X,Y"
  Map<String, SpatialNodeEntity> get currentFloorNodeMap {
    final map = <String, SpatialNodeEntity>{};
    for (final node in currentFloorNodes) {
      map['${node.x},${node.y}'] = node;
    }
    return map;
  }

  /// الغرفة المحددة حالياً في لوحة التفتيش
  SpatialNodeEntity? get selectedNode {
    if (selectedNodeId == null) return null;
    return nodes.where((n) => n.id == selectedNodeId).firstOrNull;
  }

  DesktopTopologyState copyWith({
    TopologyStatus? status,
    List<SpatialNodeEntity>? nodes,
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