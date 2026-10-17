// packages/launcher_repository/lib/src/mappers/topology_mapper.dart
import 'package:local_vault_api/local_vault_api.dart' as db;
import '../models/spatial_node_entity.dart';

extension SpatialNodeDataToEntity on db.SpatialNode {
  SpatialNodeEntity toEntity() {
    return SpatialNodeEntity(
      id: id,
      moduleId: moduleId,
      floorLevel: floorLevel,
      x: x,
      y: y,
      customTitle: customTitle,
      configJson: configJson,
      isVisible: isVisible,
    );
  }
}