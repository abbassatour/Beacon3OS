// packages/local_vault_api/lib/src/daos/spatial_nodes_dao.dart
import 'package:drift/drift.dart';
import 'package:local_vault_api/src/app_database.dart';

class SpatialNodesDao extends DatabaseAccessor<AppDatabase> {
  SpatialNodesDao(super.db);

  Stream<List<SpatialNode>> watchAllSpatialNodes() =>
      (select(attachedDatabase.spatialNodes)
            ..where((n) => n.deletedAt.isNull() & n.isVisible.equals(true))
            ..orderBy([
              (n) => OrderingTerm.asc(n.floorLevel),
              (n) => OrderingTerm.asc(n.id),
            ]))
          .watch();

  Future<List<SpatialNode>> getAllSpatialNodes() =>
      (select(attachedDatabase.spatialNodes)
            ..where((n) => n.deletedAt.isNull() & n.isVisible.equals(true)))
          .get();

  Future<void> updateNodeCoordinates({
    required String id,
    required int x,
    required int y,
    required int floorLevel,
  }) {
    return (update(attachedDatabase.spatialNodes)..where((n) => n.id.equals(id)))
        .write(
      SpatialNodesCompanion(
        x: Value(x),
        y: Value(y),
        floorLevel: Value(floorLevel),
        updatedAt: Value(DateTime.now()),
        isSynced: const Value(false),
      ),
    );
  }

  Future<void> upsertSpatialNode(SpatialNodesCompanion node) {
    return into(attachedDatabase.spatialNodes).insert(
      node.copyWith(
        updatedAt: Value(DateTime.now()),
        isSynced: const Value(false),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<void> softDeleteSpatialNode(String id) {
    return (update(attachedDatabase.spatialNodes)..where((n) => n.id.equals(id)))
        .write(
      SpatialNodesCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
        isSynced: const Value(false),
      ),
    );
  }

  Future<int> deleteSpatialNode(String id) =>
      (delete(attachedDatabase.spatialNodes)..where((n) => n.id.equals(id))).go();
}