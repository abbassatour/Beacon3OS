// lib/desktop/topology/cubit/desktop_topology_cubit.dart
import 'dart:async';
import 'dart:developer';

import 'package:beacon_os/desktop/topology/cubit/desktop_topology_state.dart';
import 'package:bloc/bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';

class DesktopTopologyCubit extends Cubit<DesktopTopologyState> {
  DesktopTopologyCubit({
    required TopologyRepository topologyRepository,
    required CommsRepository commsRepository,
  })  : _repository = topologyRepository,
        _commsRepo = commsRepository,
        super(const DesktopTopologyState()) {
    _initStream();
  }

  final TopologyRepository _repository;
  final CommsRepository _commsRepo;
  StreamSubscription<List<SpatialNodeEntity>>? _subscription;
  Timer? _p2pSyncDebounceTimer;

  void _initStream() {
    emit(state.copyWith(status: TopologyStatus.loading));
    _subscription = _repository.watchNodes().listen(
      (nodeList) {
        emit(
          state.copyWith(
            status: TopologyStatus.success,
            nodes: nodeList,
            errorMessage: null,
          ),
        );
      },
      onError: (Object error) {
        log('DesktopTopologyCubit: Error watching nodes: $error');
        emit(
          state.copyWith(
            status: TopologyStatus.error,
            errorMessage: error.toString(),
          ),
        );
      },
    );
  }

  /// بث تحديثات الفضاء للأجهزة المقترنة على الشبكة مع حماية Debounce
  void _notifyPeersOfTopologyChange({bool immediate = false}) {
    _p2pSyncDebounceTimer?.cancel();
    if (immediate) {
      unawaited(_commsRepo.sendVaultDeltaToPeers());
    } else {
      _p2pSyncDebounceTimer = Timer(const Duration(milliseconds: 120), () {
        unawaited(_commsRepo.sendVaultDeltaToPeers());
      });
    }
  }

  /// تبديل الطابق المعروض (Floor 0 مقابل Floor 1 أو -1)
  void selectFloor(int floor) {
    if (state.currentFloor == floor) return;
    emit(
      state.copyWith(
        currentFloor: floor,
        clearSelectedNode: true,
      ),
    );
  }

  /// تحديد غرفة للمعاينة والتعديل
  void selectNode(String? nodeId) {
    emit(
      state.copyWith(
        selectedNodeId: nodeId,
        clearSelectedNode: nodeId == null,
      ),
    );
  }

  /// نقل غرفة إلى موقع ديكارتي جديد (مع معالجة التبادل Swap إن كانت الخلية مشغولة)
  Future<void> moveNode({
    required String nodeId,
    required int newX,
    required int newY,
  }) async {
    final currentNode = state.nodes.where((n) => n.id == nodeId).firstOrNull;
    if (currentNode == null) return;
    if (currentNode.x == newX && currentNode.y == newY) return;

    final targetOccupant = state.currentFloorNodes.where(
      (n) => n.x == newX && n.y == newY && n.id != nodeId,
    ).firstOrNull;

    try {
      if (targetOccupant != null) {
        // تبادل المواقع بسلاسة بين الغرفتين
        await _repository.updateNodeCoordinates(
          id: targetOccupant.id,
          x: currentNode.x,
          y: currentNode.y,
          floorLevel: state.currentFloor,
        );
      }

      await _repository.updateNodeCoordinates(
        id: currentNode.id,
        x: newX,
        y: newY,
        floorLevel: state.currentFloor,
      );

      // ⚡️ بث تحديث الغرف للأجهزة المقترنة فوراً
      _notifyPeersOfTopologyChange();
    } catch (e) {
      log('DesktopTopologyCubit: Failed to move node: $e');
      emit(state.copyWith(errorMessage: 'Failed to update coordinates: $e'));
    }
  }

  /// تحريك الغرفة بمقدار خطوة واحدة عبر مفاتيح الأسهم
  Future<void> nudgeNode({
    required String nodeId,
    required int deltaX,
    required int deltaY,
  }) async {
    final node = state.nodes.where((n) => n.id == nodeId).firstOrNull;
    if (node == null) return;

    final newX = (node.x + deltaX).clamp(-2, 2);
    final newY = (node.y + deltaY).clamp(-2, 2);

    await moveNode(nodeId: nodeId, newX: newX, newY: newY);
  }

  /// تحديث الاسم المخصص للغرفة
  Future<void> updateNodeTitle({
    required String nodeId,
    required String? customTitle,
  }) async {
    final node = state.nodes.where((n) => n.id == nodeId).firstOrNull;
    if (node == null) return;

    final cleanedTitle =
        customTitle?.trim().isEmpty == true ? null : customTitle?.trim();

    await _repository.upsertNode(
      id: node.id,
      moduleId: node.moduleId,
      x: node.x,
      y: node.y,
      floorLevel: node.floorLevel,
      customTitle: cleanedTitle,
      configJson: node.configJson,
    );

    // ⚡️ بث فوري لتحديث العنوان
    _notifyPeersOfTopologyChange(immediate: true);
  }

  /// استعادة التوزيع القياسي الافتراضي للغرف في الطابق النشط
  Future<void> resetFloorToDefaults() async {
    const defaultCoords = {
      'cockpit': (x: 0, y: 0),
      'focus': (x: 0, y: 1),
      'perimeter': (x: 0, y: 2),
      'comms': (x: 0, y: -1),
      'vision': (x: 1, y: 0),
      'agenda': (x: -1, y: 0),
    };

    final currentNodes = state.currentFloorNodes;
    for (final entry in defaultCoords.entries) {
      final node =
          currentNodes.where((n) => n.moduleId == entry.key).firstOrNull;
      if (node != null) {
        await _repository.updateNodeCoordinates(
          id: node.id,
          x: entry.value.x,
          y: entry.value.y,
          floorLevel: state.currentFloor,
        );
      }
    }

    // ⚡️ بث فوري لاستعادة الإعدادات الأصلية
    _notifyPeersOfTopologyChange(immediate: true);
  }

  @override
  Future<void> close() {
    _p2pSyncDebounceTimer?.cancel();
    _subscription?.cancel();
    return super.close();
  }
}