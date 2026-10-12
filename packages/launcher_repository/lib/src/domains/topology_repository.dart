// packages/launcher_repository/lib/src/domains/topology_repository.dart
import 'dart:async';
import 'dart:developer';

import 'package:cloud_sync_api/cloud_sync_api.dart';
import 'package:drift/drift.dart';
import 'package:local_vault_api/local_vault_api.dart';

abstract class TopologyRepository {
  /// تدفق لحظي لجميع العقد الفضائية المسجلة محلياً
  Stream<List<SpatialNode>> watchNodes();

  /// جلب قائمة العقد الفضائية النشطة لمرة واحدة
  Future<List<SpatialNode>> getAllNodes();

  /// تحديث موقع غرفة معين في الفضاء (X, Y, Floor) محلياً وسحابياً
  Future<void> updateNodeCoordinates({
    required String id,
    required int x,
    required int y,
    required int floorLevel,
  });

  /// إضافة أو تخصيص عقدة فضائية بالكامل
  Future<void> upsertNode({
    required String id,
    required String moduleId,
    required int x,
    required int y,
    required int floorLevel,
    String? customTitle,
    String? configJson,
  });

  /// استعادة الخريطة وتوزيع الغرف من سحابة Supabase
  Future<void> restoreTopologyFromCloud();

  /// مزامنة أي تعديل على المواقع تم بدون إنترنت
  Future<void> syncPendingTopology();

  /// بدء الاستماع اللحظي لتغييرات الخريطة من الأجهزة الأخرى
  void initializeRealtimeSync();

  void dispose();
}

class TopologyRepositoryImpl implements TopologyRepository {
  TopologyRepositoryImpl({
    required AppDatabase database,
    required CloudSyncClient cloudSync,
  })  : _db = database,
        _cloud = cloudSync;

  final AppDatabase _db;
  final CloudSyncClient _cloud;

  StreamSubscription<dynamic>? _authSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _realtimeSubscription;

  @override
  Stream<List<SpatialNode>> watchNodes() => _db.watchAllSpatialNodes();

  @override
  Future<List<SpatialNode>> getAllNodes() => _db.getAllSpatialNodes();

  @override
  Future<void> updateNodeCoordinates({
    required String id,
    required int x,
    required int y,
    required int floorLevel,
  }) async {
    // 1. التحديث الفوري محلياً في Drift (Offline-First)
    await _db.updateNodeCoordinates(
      id: id,
      x: x,
      y: y,
      floorLevel: floorLevel,
    );

    // 2. المزامنة السحابية غير المعطلة
    final nodes = await _db.getAllSpatialNodes();
    final updatedNode = nodes.where((n) => n.id == id).firstOrNull;
    if (updatedNode != null) {
      _cloud
          .syncSpatialNode(
            id: updatedNode.id,
            moduleId: updatedNode.moduleId,
            floorLevel: updatedNode.floorLevel,
            x: updatedNode.x,
            y: updatedNode.y,
            customTitle: updatedNode.customTitle,
            configJson: updatedNode.configJson,
            isVisible: updatedNode.isVisible,
          )
          .catchError((Object error) {
        log('TopologyRepository: Cloud sync deferred for node [$id]: $error');
      });
    }
  }

  @override
  Future<void> upsertNode({
    required String id,
    required String moduleId,
    required int x,
    required int y,
    required int floorLevel,
    String? customTitle,
    String? configJson,
  }) async {
    await _db.upsertSpatialNode(
      SpatialNodesCompanion.insert(
        id: id,
        moduleId: moduleId,
        x: Value(x),
        y: Value(y),
        floorLevel: Value(floorLevel),
        customTitle: Value(customTitle),
        configJson: Value(configJson),
      ),
    );

    _cloud
        .syncSpatialNode(
          id: id,
          moduleId: moduleId,
          floorLevel: floorLevel,
          x: x,
          y: y,
          customTitle: customTitle,
          configJson: configJson,
        )
        .catchError((Object error) {
      log('TopologyRepository: Cloud upsert deferred for node [$id]: $error');
    });
  }

  @override
  void initializeRealtimeSync() {
    _authSubscription?.cancel();
    _authSubscription = _cloud.authStateChanges?.listen((_) {
      if (_cloud.isAuthenticated) {
        _subscribeToRealtimeNodes();
      } else {
        _realtimeSubscription?.cancel();
        _realtimeSubscription = null;
      }
    });

    if (_cloud.isAuthenticated) {
      _subscribeToRealtimeNodes();
    }
  }

  void _subscribeToRealtimeNodes() {
    _realtimeSubscription?.cancel();
    final stream = _cloud.streamSpatialNodes();
    if (stream != null) {
      _realtimeSubscription = stream.listen((cloudNodes) async {
        if (cloudNodes.isEmpty) return;
        try {
          await _db.batch((batch) {
            for (final item in cloudNodes) {
              final id = item['id'] as String?;
              if (id == null) continue;

              final deletedAt = item['deleted_at'] != null
                  ? DateTime.tryParse(item['deleted_at'] as String)
                  : null;

              if (deletedAt != null) {
                batch.delete(
                  _db.spatialNodes,
                  SpatialNodesCompanion(id: Value(id)),
                );
              } else {
                batch.insert(
                  _db.spatialNodes,
                  SpatialNodesCompanion.insert(
                    id: id,
                    moduleId: item['module_id'] as String,
                    floorLevel: Value(item['floor_level'] as int? ?? 0),
                    x: Value(item['x'] as int? ?? 0),
                    y: Value(item['y'] as int? ?? 0),
                    customTitle: Value(item['custom_title'] as String?),
                    configJson: Value(item['config_json'] as String?),
                    isVisible: Value(item['is_visible'] as bool? ?? true),
                    isSynced: const Value(true),
                  ),
                  mode: InsertMode.insertOrReplace,
                );
              }
            }
          });
          log('TopologyRepository: ⚡ Realtime topology synced (${cloudNodes.length} nodes).');
        } catch (e) {
          log('TopologyRepository: Error handling realtime nodes: $e');
        }
      });
    }
  }

  @override
  Future<void> restoreTopologyFromCloud() async {
    if (!_cloud.isAuthenticated) return;
    try {
      final cloudNodes = await _cloud.fetchSpatialNodes();
      if (cloudNodes.isEmpty) return;

      await _db.batch((batch) {
        for (final item in cloudNodes) {
          batch.insert(
            _db.spatialNodes,
            SpatialNodesCompanion.insert(
              id: item['id'] as String,
              moduleId: item['module_id'] as String,
              floorLevel: Value(item['floor_level'] as int? ?? 0),
              x: Value(item['x'] as int? ?? 0),
              y: Value(item['y'] as int? ?? 0),
              customTitle: Value(item['custom_title'] as String?),
              configJson: Value(item['config_json'] as String?),
              isVisible: Value(item['is_visible'] as bool? ?? true),
              isSynced: const Value(true),
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
      });
      log('TopologyRepository: Restored ${cloudNodes.length} nodes from cloud.');
    } catch (e) {
      log('TopologyRepository: Restore cloud topology error: $e');
    }
  }

  @override
  Future<void> syncPendingTopology() async {
    if (!_cloud.isAuthenticated) return;
    try {
      final pending = await (_db.select(_db.spatialNodes)
            ..where((n) => n.isSynced.equals(false)))
          .get();
      for (final n in pending) {
        await _cloud.syncSpatialNode(
          id: n.id,
          moduleId: n.moduleId,
          floorLevel: n.floorLevel,
          x: n.x,
          y: n.y,
          customTitle: n.customTitle,
          configJson: n.configJson,
          isVisible: n.isVisible,
          deletedAt: n.deletedAt,
        );
        await (_db.update(_db.spatialNodes)..where((tbl) => tbl.id.equals(n.id)))
            .write(const SpatialNodesCompanion(isSynced: Value(true)));
      }
    } catch (e) {
      log('TopologyRepository: Pending topology sync error: $e');
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _realtimeSubscription?.cancel();
  }
}