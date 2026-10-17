// packages/launcher_repository/lib/src/models/spatial_node_entity.dart
import 'package:equatable/equatable.dart';

class SpatialNodeEntity extends Equatable {
  const SpatialNodeEntity({
    required this.id,
    required this.moduleId,
    this.floorLevel = 0,
    this.x = 0,
    this.y = 0,
    this.customTitle,
    this.configJson,
    this.isVisible = true,
  });

  final String id;
  final String moduleId;
  final int floorLevel;
  final int x;
  final int y;
  final String? customTitle;
  final String? configJson;
  final bool isVisible;

  @override
  List<Object?> get props => [
        id,
        moduleId,
        floorLevel,
        x,
        y,
        customTitle,
        configJson,
        isVisible,
      ];
}