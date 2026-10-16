// lib/spatial_shell/cubit/spatial_shell_cubit.dart
import 'dart:async';
import 'dart:developer';
import 'package:beacon_os/core/audio/sound_controller.dart';
import 'package:beacon_os/core/audio/sound_cue.dart';
import 'package:beacon_os/core/haptics/haptic_manager.dart';
import 'package:beacon_os/core/topology/topology.dart';
import 'package:beacon_os/mobile/shell/cubit/spatial_shell_state.dart';
import 'package:bloc/bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';
import 'package:local_vault_api/local_vault_api.dart'; // 👈 لضمان حل نوع SpatialNode

class SpatialShellCubit extends Cubit<SpatialShellState> {
  SpatialShellCubit({
    required AssistantRepository assistantRepository,
    required SpatialTopology topology,
    TopologyRepository? topologyRepository,
    HapticManager? hapticManager,
    SoundController? soundController,
  })  : _assistant = assistantRepository,
        _topology = topology,
        _topologyRepo = topologyRepository,
        _haptics = hapticManager ?? HapticManager.instance,
        _sound = soundController ?? SoundController.instance,
        super(const SpatialShellState()) {
    _initTopologyListener();
  }

  final AssistantRepository _assistant;
  final SpatialTopology _topology;
  final TopologyRepository? _topologyRepo;
  final HapticManager _haptics;
  final SoundController _sound;

  StreamSubscription<void>? _topologySub;
  StreamSubscription<List<SpatialNode>>? _nodesRepoSub;

  void _initTopologyListener() {
    // ⚡️ 1. الاستماع المباشر لبث كائن الطوبولوجيا الحي
    _topologySub = _topology.changes.listen((_) {
      _reconcileActivePosition();
    });

    // ⚡️ 2. استماع تكميلي من مستودع الخزنة المحلية
    if (_topologyRepo != null) {
      _nodesRepoSub = _topologyRepo.watchNodes().listen((nodes) {
        if (nodes.isNotEmpty) {
          _topology.updateFromNodes(nodes);
          _reconcileActivePosition();
        }
      });
    }
  }

  /// 🧠 محرك المحاذاة الذكي: يمنع الشاشة السوداء ويلاحق الغرفة في إحداثياتها الجديدة
  void _reconcileActivePosition() {
    final currentFloor = state.currentFloor;
    final activeId = state.activeModuleId;

    // 1. أين موقع الغرفة النشطة الآن على نفس الطابق؟
    final updatedCoord = _topology.coordinateOf(currentFloor, activeId);
    if (updatedCoord != null) {
      if (updatedCoord != state.currentCoordinate) {
        log('SpatialShellCubit: 🎯 Tracking moved room [$activeId] from ${state.currentCoordinate} -> $updatedCoord');
        emit(
          state.copyWith(
            previousCoordinate: state.currentCoordinate,
            currentCoordinate: updatedCoord,
          ),
        );
      }
      return;
    }

    // 2. إذا لم تعد الغرفة موجودة بالاسم، هل الإحداثي الحالي مأهول بغرفة جديدة بعد التبادل؟
    final moduleAtCurrent = _topology.moduleAtCoordinate(state.currentCoordinate);
    if (moduleAtCurrent != null) {
      log('SpatialShellCubit: 🔄 Room swap detected at ${state.currentCoordinate} -> New module: [${moduleAtCurrent.id}]');
      emit(state.copyWith(activeModuleId: moduleAtCurrent.id));
      return;
    }

    // 3. حماية حاسمة من الشاشة السوداء: الانجذاب لمركز الطابق
    final originCoord = SpatialCoordinate(x: 0, y: 0, floor: currentFloor);
    final originModule = _topology.moduleAtCoordinate(originCoord);
    if (originModule != null) {
      log('SpatialShellCubit: ⚠️ Current spot empty. Gravitating to origin (0, 0) [${originModule.id}]');
      emit(
        state.copyWith(
          previousCoordinate: state.currentCoordinate,
          currentCoordinate: originCoord,
          activeModuleId: originModule.id,
        ),
      );
      return;
    }

    // 4. الانجذاب لأول غرفة مأهولة متوفرة في الطابق
    final floorNodes = _topology.nodesOnFloor(currentFloor);
    if (floorNodes.isNotEmpty) {
      final fallbackCoord = floorNodes.keys.first;
      final fallbackModule = floorNodes[fallbackCoord]!;
      log('SpatialShellCubit: ⚠️ Origin empty. Gravitating to first occupied room: $fallbackCoord [${fallbackModule.id}]');
      emit(
        state.copyWith(
          previousCoordinate: state.currentCoordinate,
          currentCoordinate: fallbackCoord,
          activeModuleId: fallbackModule.id,
        ),
      );
    }
  }

  // ===========================================================================
  // 🏢 1. التحكم الرأسي متعدد الطوابق (Z-Axis Multi-Floor Elevator)
  // ===========================================================================

  Future<void> ascend() async {
    final nextFloor = state.currentFloor + 1;
    if (!_topology.hasFloor(nextFloor)) {
      await _sound.playBoundaryBump();
      _haptics.selectionClick();
      return;
    }
    await jumpToFloor(nextFloor);
  }

  Future<void> descend() async {
    final nextFloor = state.currentFloor - 1;
    if (!_topology.hasFloor(nextFloor)) {
      await _sound.playBoundaryBump();
      _haptics.selectionClick();
      return;
    }
    await jumpToFloor(nextFloor);
  }

  Future<void> jumpToFloor(int targetFloor) async {
    if (state.currentFloor == targetFloor) return;
    if (!_topology.hasFloor(targetFloor)) return;

    final isAscending = targetFloor > state.currentFloor;
    final cue = isAscending ? SoundCue.elevatorUp : SoundCue.elevatorDown;

    unawaited(_haptics.successNotification());
    unawaited(_sound.play(cue, floorLevel: targetFloor));

    var nextCoord = _topology.coordinateOf(targetFloor, state.activeModuleId) ??
        state.currentCoordinate.copyWith(floor: targetFloor);

    if (_topology.moduleAtCoordinate(nextCoord) == null) {
      final originCoord = SpatialCoordinate(x: 0, y: 0, floor: targetFloor);
      if (_topology.moduleAtCoordinate(originCoord) != null) {
        nextCoord = originCoord;
      } else {
        final floorNodes = _topology.nodesOnFloor(targetFloor).keys;
        if (floorNodes.isNotEmpty) {
          nextCoord = floorNodes.first;
        }
      }
    }

    final targetModule = _topology.moduleAtCoordinate(nextCoord);

    emit(
      state.copyWith(
        previousCoordinate: state.currentCoordinate,
        currentCoordinate: nextCoord,
        activeModuleId: targetModule?.id ?? state.activeModuleId,
      ),
    );
  }

  Future<void> goToSettingsFloor() => jumpToFloor(1);
  Future<void> returnToGroundFloor() => jumpToFloor(0);

  void toggleFloor() {
    if (_topology.canAscendFrom(state.currentFloor)) {
      ascend();
    } else {
      descend();
    }
  }

  // ===========================================================================
  // 🧭 2. التنقل الديكارتي والجاذبية المكانية
  // ===========================================================================

  Future<void> moveToCoordinate(SpatialCoordinate destination) async {
    if (state.currentCoordinate == destination) return;

    await _haptics.successNotification();

    final deltaX = destination.x - state.currentCoordinate.x;
    final deltaY = destination.y - state.currentCoordinate.y;

    CompassDirection compDir = CompassDirection.center;
    if (deltaX.abs() > deltaY.abs()) {
      compDir = deltaX > 0 ? CompassDirection.east : CompassDirection.west;
    } else if (deltaY != 0) {
      compDir = deltaY > 0 ? CompassDirection.north : CompassDirection.south;
    }

    await _sound.playCompassMove(
      direction: compDir,
      floorLevel: destination.floor,
    );

    final module = _topology.moduleAtCoordinate(destination);

    emit(
      state.copyWith(
        previousCoordinate: state.currentCoordinate,
        currentCoordinate: destination,
        activeModuleId: module?.id ?? state.activeModuleId,
        isTransitioning: false,
      ),
    );
  }

  Future<bool> navigateToward(SpatialDirection direction) async {
    if (direction == SpatialDirection.center) {
      await returnToCenter();
      return true;
    }

    final nextNode = _topology.findNextOccupiedInDirection(
      origin: state.currentCoordinate,
      direction: direction,
    );

    if (nextNode != null) {
      await moveToCoordinate(nextNode);
      return true;
    } else {
      await _sound.playBoundaryBump();
      _haptics.selectionClick();
      return false;
    }
  }

  Future<void> moveTo(SpatialDirection destination) async {
    await navigateToward(destination);
  }

  Future<void> returnToCenter() async {
    final targetCenter = SpatialCoordinate(x: 0, y: 0, floor: state.currentFloor);
    final targetNode = _topology.moduleAtCoordinate(targetCenter) != null
        ? targetCenter
        : (_topology.nodesOnFloor(state.currentFloor).keys.firstOrNull ?? targetCenter);

    await moveToCoordinate(targetNode);
  }

  // ===========================================================================
  // 🔊 3. النظام الصوتي الموجه للمكفوفين (متطابق 100% مع قاعدة البيانات)
  // ===========================================================================

  Future<void> announceCurrentLocation() async {
    // قراءة العنوان الحقيقي المخزن في قاعدة البيانات
    final roomTitle = _topology.titleAtCoordinate(state.currentCoordinate);
    final floorTitle = state.currentFloor == 0
        ? 'Ground Floor'
        : 'Floor ${state.currentFloor}';

    final announcement = '$roomTitle, $floorTitle.';

    await _assistant.stopSpeaking();
    await _assistant.speak(announcement);
    log('SpatialShell: Orientation Ping -> "$announcement"');
  }

  Future<void> whisperRoomScrubbing(SpatialDirection direction) async {
    final nextNode = _topology.findNextOccupiedInDirection(
      origin: state.currentCoordinate,
      direction: direction,
    );
    if (nextNode == null) return;

    // همس الاسم الحقيقي للغرفة القادمة أثناء السحب
    final hint = _topology.titleAtCoordinate(nextNode);
    await _assistant.stopSpeaking();
    await _assistant.speak(hint);
  }

  @override
  Future<void> close() {
    _topologySub?.cancel();
    _nodesRepoSub?.cancel();
    return super.close();
  }
}

typedef SpatialCompassCubit = SpatialShellCubit;