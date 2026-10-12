// lib/spatial_shell/cubit/spatial_shell_cubit.dart
import 'dart:async';
import 'dart:developer';
import 'package:beacon_os/core/audio/sound_controller.dart';
import 'package:beacon_os/core/audio/sound_cue.dart';
import 'package:beacon_os/core/haptics/haptic_manager.dart';
import 'package:beacon_os/core/topology/topology.dart';
import 'package:beacon_os/spatial_shell/cubit/spatial_shell_state.dart';
import 'package:bloc/bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';

class SpatialShellCubit extends Cubit<SpatialShellState> {
  SpatialShellCubit({
    required AssistantRepository assistantRepository,
    required SpatialTopology topology,
    HapticManager? hapticManager,
    SoundController? soundController,
  })  : _assistant = assistantRepository,
        _topology = topology,
        _haptics = hapticManager ?? HapticManager.instance,
        _sound = soundController ?? SoundController.instance,
        super(const SpatialShellState());

  final AssistantRepository _assistant;
  final SpatialTopology _topology;
  final HapticManager _haptics;
  final SoundController _sound;

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

    // الانتقال لنفس الإحداثي على الطابق الجديد، أو لأقرب غرفة مأهولة إن كان الإحداثي فارغاً
    var nextCoord = state.currentCoordinate.copyWith(floor: targetFloor);
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

    emit(
      state.copyWith(
        previousCoordinate: state.currentCoordinate,
        currentCoordinate: nextCoord,
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
  // 🧭 2. التنقل الديكارتي والجاذبية المكانية (Smart Spatial Navigation)
  // ===========================================================================

  /// الانتقال مباشرة إلى إحداثي ديكارتي معين مع حساب التجسيم الصوتي النسبي
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

    emit(
      state.copyWith(
        previousCoordinate: state.currentCoordinate,
        currentCoordinate: destination,
        isTransitioning: false,
      ),
    );
  }

  /// التنقل الذكي في اتجاه معين نحو الغرفة المأهولة التالية في المسار
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

  /// توافق كامل مع الكود القديم
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
  // 🔊 3. النظام الصوتي الموجه للمكفوفين (Contextual TTS Engine)
  // ===========================================================================

  /// إعلان الموقع الصريح الحقيقي من قاعدة البيانات
  Future<void> announceCurrentLocation() async {
    final module = _topology.moduleAtCoordinate(state.currentCoordinate);
    final roomTitle = module?.getFloorTitle(state.currentFloor) ??
        module?.title ??
        'Room (${state.currentCoordinate.x}, ${state.currentCoordinate.y})';
    final floorTitle = state.currentFloor == 0
        ? 'Ground Floor'
        : 'Floor ${state.currentFloor}';

    final announcement = '$roomTitle, $floorTitle.';

    await _assistant.stopSpeaking();
    await _assistant.speak(announcement);
    log('SpatialShell: Orientation Ping -> "$announcement"');
  }

  /// همس استكشاف الغرفة المأهولة الحقيقية في المسار قبل الانتقال
  Future<void> whisperRoomScrubbing(SpatialDirection direction) async {
    final nextNode = _topology.findNextOccupiedInDirection(
      origin: state.currentCoordinate,
      direction: direction,
    );
    if (nextNode == null) return;

    final module = _topology.moduleAtCoordinate(nextNode);
    if (module == null) return;

    final hint = module.shortTitle;
    await _assistant.stopSpeaking();
    await _assistant.speak(hint);
    log('SpatialShell: Finger Scrubbing Whisper -> "$hint"');
  }
}

// 🛡️ توافق كامل مع الكود السابق
typedef SpatialCompassCubit = SpatialShellCubit;