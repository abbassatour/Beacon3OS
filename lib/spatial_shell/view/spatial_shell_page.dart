// lib/spatial_shell/view/spatial_shell_page.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:beacon_os/agenda/agenda.dart';
import 'package:beacon_os/cockpit/cockpit.dart';
import 'package:beacon_os/comms/comms.dart';
import 'package:beacon_os/core/audio/sound_controller.dart';
import 'package:beacon_os/core/haptics/haptic_manager.dart';
import 'package:beacon_os/core/physics/spatial_physics.dart';
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/core/topology/topology.dart';
import 'package:beacon_os/core/voice_bus/voice_bus.dart';
import 'package:beacon_os/focus/focus.dart';
import 'package:beacon_os/preferences/preferences.dart';
import 'package:beacon_os/spatial_shell/cubit/spatial_shell_cubit.dart';
import 'package:beacon_os/spatial_shell/cubit/spatial_shell_state.dart';
import 'package:beacon_os/spatial_shell/widgets/ambient_voice_overlay.dart';
import 'package:beacon_os/spatial_shell/widgets/corner_swipe_detector.dart';
import 'package:beacon_os/spatial_shell/widgets/spatial_compass_hud.dart';
import 'package:beacon_os/spatial_shell/widgets/spatial_floor_layout.dart';
import 'package:beacon_os/vision/vision.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';

class SpatialShellPage extends StatelessWidget {
  const SpatialShellPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(
      builder: (_) => const SpatialShellPage(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topology = context.read<SpatialTopology>();

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => SpatialShellCubit(
            assistantRepository: context.read<AssistantRepository>(),
            topology: topology,
          ),
        ),
        BlocProvider(
          create: (context) => SettingsCubit(
            settingsRepository: context.read<SettingsRepository>(),
            assistantRepository: context.read<AssistantRepository>(),
          ),
        ),
        BlocProvider(
          create: (context) => AmbientVoiceCubit(
            assistantRepository: context.read<AssistantRepository>(),
            voiceDispatcher: context.read<VoiceCommandDispatcher>(),
            taskRepository: context.read<TaskAgendaRepository>(),
            focusAlarmsRepository: context.read<FocusAlarmsRepository>(),
            settingsRepository: context.read<SettingsRepository>(),
            commsRepository: context.read<CommsRepository>(),
          ),
        ),
        BlocProvider(
          create: (context) => CockpitCubit(
            taskRepository: context.read<TaskAgendaRepository>(),
            focusAlarmsRepository: context.read<FocusAlarmsRepository>(),
            hardwareRepository: context.read<SystemHardwareRepository>(),
            assistantRepository: context.read<AssistantRepository>(),
          ),
        ),
        BlocProvider(
          create: (context) => FocusCubit(
            focusRepository: context.read<FocusAlarmsRepository>(),
            assistantRepository: context.read<AssistantRepository>(),
            settingsRepository: context.read<SettingsRepository>(),
          ),
        ),
        BlocProvider(
          create: (context) => CommsCubit(
            commsRepository: context.read<CommsRepository>(),
            hardwareRepository: context.read<SystemHardwareRepository>(),
            assistantRepository: context.read<AssistantRepository>(),
          ),
        ),
        BlocProvider(
          create: (context) => VisionCubit(
            assistantRepository: context.read<AssistantRepository>(),
            hardwareRepository: context.read<SystemHardwareRepository>(),
            settingsRepository: context.read<SettingsRepository>(),
            taskRepository: context.read<TaskAgendaRepository>(),
          ),
        ),
        BlocProvider(
          create: (context) => AgendaCubit(
            taskRepository: context.read<TaskAgendaRepository>(),
            assistantRepository: context.read<AssistantRepository>(),
            settingsRepository: context.read<SettingsRepository>(),
          ),
        ),
      ],
      child: const _SpatialShellBody(),
    );
  }
}

class _SpatialShellBody extends StatefulWidget {
  const _SpatialShellBody();

  @override
  State<_SpatialShellBody> createState() => _SpatialShellBodyState();
}

class _SpatialShellBodyState extends State<_SpatialShellBody>
    with TickerProviderStateMixin {
  late final AnimationController _panX;
  late final AnimationController _panY;
  late final AnimationController _floorZ;

  bool _isTwoFingerElevator = false;
  bool _isTransitioningViaGesture = false;
  Axis? _lockedAxis;

  double _initialScale = 0.0;
  double _startXAtGesture = 0.0;
  double _startYAtGesture = 0.0;

  double _accumulatedDeltaX = 0.0;
  double _accumulatedDeltaY = 0.0;

  bool _hapticDetentFired = false;
  bool _boundaryBumpFired = false;

  bool _isInnerListScrolling = false;
  bool _isEdgeSwipe = false;

  final Map<int, double> _threeFingerStartPointers = {};
  bool _threeFingerActionFired = false;

  Timer? _scrubbingDebounceTimer;
  SpatialDirection? _lastScrubbedDirection;

  int _activePointers = 0;
  DateTime? _twoFingerTapStartTime;
  int _twoFingerTapCount = 0;
  DateTime? _lastTwoFingerTapTime;
  bool _hasTwoFingerMoved = false;

  int _singleTapCount = 0;
  DateTime? _lastSingleTapTime;

  Timer? _holdToSpeakTimer;
  bool _isHoldingToSpeak = false;
  Offset? _pointerDownPos;

  @override
  void initState() {
    super.initState();
    _panX = AnimationController.unbounded(vsync: this);
    _panY = AnimationController.unbounded(vsync: this);
    _floorZ = AnimationController.unbounded(vsync: this, value: 0.0);
  }

  @override
  void dispose() {
    _holdToSpeakTimer?.cancel();
    _scrubbingDebounceTimer?.cancel();
    _panX.dispose();
    _panY.dispose();
    _floorZ.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event, AmbientVoiceCubit voiceCubit) {
    _activePointers++;
    _pointerDownPos = event.position;

    if (_activePointers <= 3) {
      _threeFingerStartPointers[event.pointer] = event.position.dy;
    }

    if (_activePointers == 3) {
      _holdToSpeakTimer?.cancel();
      _scrubbingDebounceTimer?.cancel();
      SoundController.instance.stopSpatialRadar();
      _threeFingerActionFired = false;
    } else if (_activePointers == 2) {
      _holdToSpeakTimer?.cancel();
      _scrubbingDebounceTimer?.cancel();
      if (_isHoldingToSpeak) {
        _isHoldingToSpeak = false;
        voiceCubit.closeSession();
      }
      _twoFingerTapStartTime = DateTime.now();
      _hasTwoFingerMoved = false;
    } else if (_activePointers == 1) {
      final now = DateTime.now();
      if (_lastSingleTapTime == null ||
          now.difference(_lastSingleTapTime!).inMilliseconds > 450) {
        _singleTapCount = 1;
      } else {
        _singleTapCount++;
      }
      _lastSingleTapTime = now;

      if (_singleTapCount == 3) {
        _holdToSpeakTimer?.cancel();
        _scrubbingDebounceTimer?.cancel();
        _isHoldingToSpeak = false;
        SoundController.instance.stopSpatialRadar();
        _triggerTripleTapSos();
        _singleTapCount = 0;
        return;
      }

      _holdToSpeakTimer?.cancel();
      _holdToSpeakTimer = Timer(const Duration(milliseconds: 400), () {
        if (_activePointers == 1 &&
            !_isTwoFingerElevator &&
            !voiceCubit.state.isOpen) {
          _isHoldingToSpeak = true;
          _scrubbingDebounceTimer?.cancel();
          SoundController.instance.stopSpatialRadar();
          voiceCubit.startSession();
        }
      });
    } else {
      _holdToSpeakTimer?.cancel();
      _isHoldingToSpeak = false;
    }
  }

  void _onPointerMove(PointerMoveEvent event, SpatialShellCubit shellCubit) {
    if (_activePointers == 3 && !_threeFingerActionFired) {
      final startY = _threeFingerStartPointers[event.pointer];
      if (startY != null) {
        final deltaY = event.position.dy - startY;
        if (deltaY < -75.0) {
          _threeFingerActionFired = true;
          shellCubit.ascend();
          return;
        } else if (deltaY > 75.0) {
          _threeFingerActionFired = true;
          shellCubit.descend();
          return;
        }
      }
    }

    if (_activePointers >= 2 && event.delta.distance > 2.5) {
      _hasTwoFingerMoved = true;
    }

    if (!_isHoldingToSpeak && _pointerDownPos != null) {
      final moved = (event.position - _pointerDownPos!).distance;
      if (moved > 14.0) {
        _holdToSpeakTimer?.cancel();
      }
    }
  }

  void _onPointerUp(
    PointerUpEvent event,
    SpatialShellCubit cubit,
    AmbientVoiceCubit voiceCubit,
  ) {
    _threeFingerStartPointers.remove(event.pointer);
    _holdToSpeakTimer?.cancel();

    if (_isHoldingToSpeak) {
      _isHoldingToSpeak = false;
      voiceCubit.stopAndExecute();
    } else if (_activePointers == 2 && _twoFingerTapStartTime != null) {
      final tapDuration = DateTime.now().difference(_twoFingerTapStartTime!);
      if (!_hasTwoFingerMoved && tapDuration.inMilliseconds < 350) {
        final now = DateTime.now();
        if (_lastTwoFingerTapTime == null ||
            now.difference(_lastTwoFingerTapTime!).inMilliseconds > 450) {
          _twoFingerTapCount = 1;
        } else {
          _twoFingerTapCount++;
        }
        _lastTwoFingerTapTime = now;

        if (_twoFingerTapCount == 2) {
          _twoFingerTapCount = 0;
          cubit.announceCurrentLocation();
        }
      }
    }

    _activePointers = (_activePointers - 1).clamp(0, 10);
    if (_activePointers == 0) {
      _hasTwoFingerMoved = false;
      _pointerDownPos = null;
      _threeFingerActionFired = false;
      _threeFingerStartPointers.clear();
      _scrubbingDebounceTimer?.cancel();
      _lastScrubbedDirection = null;
      SoundController.instance.stopSpatialRadar();
    }
  }

  void _onPointerCancel(
    PointerCancelEvent event,
    AmbientVoiceCubit voiceCubit,
  ) {
    _holdToSpeakTimer?.cancel();
    _scrubbingDebounceTimer?.cancel();
    if (_isHoldingToSpeak) {
      _isHoldingToSpeak = false;
      voiceCubit.closeSession();
    }
    _activePointers = (_activePointers - 1).clamp(0, 10);
    _pointerDownPos = null;
    _threeFingerActionFired = false;
    _threeFingerStartPointers.clear();
    _lastScrubbedDirection = null;
    SoundController.instance.stopSpatialRadar();
  }

  Future<void> _triggerTripleTapSos() async {
    await HapticManager.instance.emergencyAlarmPulse();
    if (!mounted) return;
    try {
      final commsRepo = context.read<CommsRepository>();
      await commsRepo.triggerEmergencySos();
    } catch (_) {}
  }

  void _onScaleStart(ScaleStartDetails details) {
    if (details.pointerCount >= 2) {
      _holdToSpeakTimer?.cancel();
      _scrubbingDebounceTimer?.cancel();
      if (_isHoldingToSpeak) {
        _isHoldingToSpeak = false;
        context.read<AmbientVoiceCubit>().closeSession();
      }
    } else if (_isHoldingToSpeak) {
      return;
    }

    _panX.stop();
    _panY.stop();
    _floorZ.stop();

    _isTwoFingerElevator = details.pointerCount >= 2;
    _lockedAxis = null;
    _initialScale = _floorZ.value;
    _startXAtGesture = _panX.value;
    _startYAtGesture = _panY.value;
    _accumulatedDeltaX = 0.0;
    _accumulatedDeltaY = 0.0;
    _hapticDetentFired = false;
    _boundaryBumpFired = false;
    _lastScrubbedDirection = null;

    final screenHeight = MediaQuery.of(context).size.height;
    if (_pointerDownPos != null) {
      _isEdgeSwipe = _pointerDownPos!.dy < 110.0 ||
          _pointerDownPos!.dy > (screenHeight - 110.0);
    } else {
      _isEdgeSwipe = false;
    }

    if (!_isHoldingToSpeak && !_isTwoFingerElevator && _activePointers < 3) {
      final currentFloor = context.read<SpatialShellCubit>().state.currentFloor;
      SoundController.instance.startSpatialRadar(floorLevel: currentFloor);
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_isHoldingToSpeak || _activePointers >= 3) return;

    final shellCubit = context.read<SpatialShellCubit>();
    final state = shellCubit.state;
    final topology = context.read<SpatialTopology>();
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // 1. التحكم بمصعد الطوابق (Z-Axis)
    if (details.pointerCount >= 2) {
      _isTwoFingerElevator = true;

      final minFloor = topology.minFloor.toDouble();
      final maxFloor = topology.maxFloor.toDouble();

      final scaleDelta = (details.scale - 1.0) * 1.5;
      final rawZ = _initialScale + scaleDelta;

      double computedZ;
      if (rawZ < minFloor) {
        final excess = minFloor - rawZ;
        computedZ = minFloor -
            SpatialPhysics.applyRubberBanding(
              delta: excess,
              limit: 0.20,
            );
        if (excess > 0.05 && !_boundaryBumpFired) {
          _boundaryBumpFired = true;
          SoundController.instance.playBoundaryBump();
          HapticManager.instance.selectionClick();
        }
      } else if (rawZ > maxFloor) {
        final excess = rawZ - maxFloor;
        computedZ = maxFloor +
            SpatialPhysics.applyRubberBanding(
              delta: excess,
              limit: 0.20,
            );
        if (excess > 0.05 && !_boundaryBumpFired) {
          _boundaryBumpFired = true;
          SoundController.instance.playBoundaryBump();
          HapticManager.instance.selectionClick();
        }
      } else {
        computedZ = rawZ;
        _boundaryBumpFired = false;
      }

      _floorZ.value = computedZ;

      final currentBaseFloor = _floorZ.value.floorToDouble();
      final midPoint = currentBaseFloor + 0.50;

      if ((_floorZ.value >= midPoint && _initialScale < midPoint) ||
          (_floorZ.value <= midPoint && _initialScale >= midPoint)) {
        if (!_hapticDetentFired) {
          HapticManager.instance.selectionClick();
          _hapticDetentFired = true;
        }
      } else if ((_floorZ.value < midPoint - 0.15 && _initialScale < midPoint) ||
          (_floorZ.value > midPoint + 0.15 && _initialScale >= midPoint)) {
        _hapticDetentFired = false;
      }
      return;
    }

    if (_isTwoFingerElevator && details.pointerCount < 2) return;

    // 2. الملاحة الأفقية وفك تعارض القوائم
    final dx = details.focalPointDelta.dx;
    final dy = details.focalPointDelta.dy;

    _accumulatedDeltaX += dx;
    _accumulatedDeltaY += dy;

    const touchSlopThreshold = 8.0;
    if (_lockedAxis == null) {
      if (_accumulatedDeltaX.abs() > touchSlopThreshold ||
          _accumulatedDeltaY.abs() > touchSlopThreshold) {
        _lockedAxis = _accumulatedDeltaX.abs() > _accumulatedDeltaY.abs()
            ? Axis.horizontal
            : Axis.vertical;
      } else {
        return;
      }
    }

    if (state.currentCoordinate.isOrigin &&
        _lockedAxis == Axis.vertical &&
        _isInnerListScrolling &&
        !_isEdgeSwipe) {
      return;
    }

    // 📐 حساب الحدود الديناميكية للغرف المأهولة المسجلة في الطوبولوجيا
    if (_lockedAxis == Axis.horizontal) {
      final rawVal = _startXAtGesture + _accumulatedDeltaX;
      final currentTargetX = -state.currentCoordinate.x * screenWidth;

      final eastNeighbor = topology.findNextOccupiedInDirection(
        origin: state.currentCoordinate,
        direction: SpatialDirection.east,
      );
      final westNeighbor = topology.findNextOccupiedInDirection(
        origin: state.currentCoordinate,
        direction: SpatialDirection.west,
      );

      final minLimitX = eastNeighbor != null
          ? -eastNeighbor.x * screenWidth
          : currentTargetX;
      final maxLimitX = westNeighbor != null
          ? -westNeighbor.x * screenWidth
          : currentTargetX;

      final lowerBound = math.min(minLimitX, maxLimitX);
      final upperBound = math.max(minLimitX, maxLimitX);

      var isWall = false;
      var wallLimit = 0.0;

      if (rawVal < lowerBound) {
        isWall = true;
        wallLimit = lowerBound;
      } else if (rawVal > upperBound) {
        isWall = true;
        wallLimit = upperBound;
      }

      if (isWall) {
        final excess = rawVal - wallLimit;
        _panX.value = wallLimit +
            SpatialPhysics.applyRubberBanding(
              delta: excess,
              limit: screenWidth,
            );

        if (excess.abs() > 14.0 && !_boundaryBumpFired) {
          _boundaryBumpFired = true;
          SoundController.instance.playBoundaryBump();
          HapticManager.instance.selectionClick();
        }
      } else {
        _panX.value = rawVal;
        _boundaryBumpFired = false;
      }

      // نبضة العتبة اللمسية عند 50%
      final dragDistance = (_panX.value - _startXAtGesture).abs();
      final hapticThreshold = screenWidth * 0.50;
      if (dragDistance >= hapticThreshold) {
        if (!_hapticDetentFired) {
          HapticManager.instance.selectionClick();
          _hapticDetentFired = true;
        }
      } else if (dragDistance < hapticThreshold * 0.85) {
        _hapticDetentFired = false;
      }
    } else if (_lockedAxis == Axis.vertical) {
      final rawVal = _startYAtGesture + _accumulatedDeltaY;
      final currentTargetY = state.currentCoordinate.y * screenHeight;

      final northNeighbor = topology.findNextOccupiedInDirection(
        origin: state.currentCoordinate,
        direction: SpatialDirection.north,
      );
      final southNeighbor = topology.findNextOccupiedInDirection(
        origin: state.currentCoordinate,
        direction: SpatialDirection.south,
      );

      final maxLimitY = northNeighbor != null
          ? northNeighbor.y * screenHeight
          : currentTargetY;
      final minLimitY = southNeighbor != null
          ? southNeighbor.y * screenHeight
          : currentTargetY;

      final lowerBound = math.min(minLimitY, maxLimitY);
      final upperBound = math.max(minLimitY, maxLimitY);

      var isWall = false;
      var wallLimit = 0.0;

      if (rawVal < lowerBound) {
        isWall = true;
        wallLimit = lowerBound;
      } else if (rawVal > upperBound) {
        isWall = true;
        wallLimit = upperBound;
      }

      if (isWall) {
        final excess = rawVal - wallLimit;
        _panY.value = wallLimit +
            SpatialPhysics.applyRubberBanding(
              delta: excess,
              limit: screenHeight,
            );

        if (excess.abs() > 14.0 && !_boundaryBumpFired) {
          _boundaryBumpFired = true;
          SoundController.instance.playBoundaryBump();
          HapticManager.instance.selectionClick();
        }
      } else {
        _panY.value = rawVal;
        _boundaryBumpFired = false;
      }

      final dragDistance = (_panY.value - _startYAtGesture).abs();
      final hapticThreshold = screenHeight * 0.50;
      if (dragDistance >= hapticThreshold) {
        if (!_hapticDetentFired) {
          HapticManager.instance.selectionClick();
          _hapticDetentFired = true;
        }
      } else if (dragDistance < hapticThreshold * 0.85) {
        _hapticDetentFired = false;
      }
    }

    // 3. تحديث الرادار الصوتي والهمس الاستكشافي
    final currentTargetX = -state.currentCoordinate.x * screenWidth;
    final currentTargetY = state.currentCoordinate.y * screenHeight;
    final normalizedX = -((_panX.value - currentTargetX) / screenWidth);
    final normalizedY = ((_panY.value - currentTargetY) / screenHeight);

    SoundController.instance.updateSpatialRadar(
      normalizedX: normalizedX,
      normalizedY: normalizedY,
      floorLevel: state.currentFloor,
    );

    SpatialDirection? targetDirection;
    if (normalizedX > 0.35) {
      targetDirection = SpatialDirection.east;
    } else if (normalizedX < -0.35) {
      targetDirection = SpatialDirection.west;
    } else if (normalizedY > 0.35) {
      targetDirection = SpatialDirection.north;
    } else if (normalizedY < -0.35) {
      targetDirection = SpatialDirection.south;
    }

    if (targetDirection != null && targetDirection != _lastScrubbedDirection) {
      _lastScrubbedDirection = targetDirection;
      _scrubbingDebounceTimer?.cancel();
      _scrubbingDebounceTimer = Timer(const Duration(milliseconds: 200), () {
        shellCubit.whisperRoomScrubbing(targetDirection!);
      });
    } else if (targetDirection == null) {
      _lastScrubbedDirection = null;
      _scrubbingDebounceTimer?.cancel();
    }
  }

  void _onScaleEnd(ScaleEndDetails details, SpatialShellCubit cubit) {
    if (_isHoldingToSpeak || _activePointers >= 3) return;

    SoundController.instance.stopSpatialRadar();
    _scrubbingDebounceTimer?.cancel();
    _lastScrubbedDirection = null;

    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    final state = cubit.state;
    final topology = context.read<SpatialTopology>();

    if (_isTwoFingerElevator) {
      _isTwoFingerElevator = false;
      _isTransitioningViaGesture = true;

      final minFloor = topology.minFloor;
      final maxFloor = topology.maxFloor;

      final scaleVel = details.scaleVelocity;
      final vz = (scaleVel * 1.5).clamp(-4.0, 4.0);
      final velocityBias = vz.clamp(-1.5, 1.5) * 0.35;
      final projectedZ = _floorZ.value + velocityBias;

      int targetFloor;
      final deltaFromInitial = _floorZ.value - _initialScale;

      if (deltaFromInitial > 0.40 || vz > 0.5) {
        targetFloor = (_initialScale + 1).round();
      } else if (deltaFromInitial < -0.40 || vz < -0.5) {
        targetFloor = (_initialScale - 1).round();
      } else {
        targetFloor = projectedZ.round();
      }

      targetFloor = targetFloor.clamp(minFloor, maxFloor);
      final targetZ = targetFloor.toDouble();

      _floorZ
          .animateWith(
        SpatialPhysics.createZAxisSimulation(
          start: _floorZ.value,
          end: targetZ,
          velocity: vz,
        ),
      )
          .whenComplete(() {
        if (mounted) {
          setState(() {
            _isTransitioningViaGesture = false;
          });
        }
      });

      if (targetFloor != cubit.state.currentFloor) {
        cubit.jumpToFloor(targetFloor);
      }
      return;
    }

    // 🎯 الجاذبية المكانية الذكية: القفز للغرفة المأهولة التالية في المسار
    const distanceThresholdPercent = 0.50;
    const velocityThreshold = 220.0;

    if (_lockedAxis == Axis.horizontal) {
      final vx = details.velocity.pixelsPerSecond.dx;
      final currentTargetX = -state.currentCoordinate.x * screenW;
      final deltaFromTarget = _panX.value - currentTargetX;

      SpatialCoordinate? targetCoord;

      if (deltaFromTarget < -screenW * distanceThresholdPercent ||
          vx < -velocityThreshold) {
        // سحب لليسار -> التوجه للشرق (+X)
        targetCoord = topology.findNextOccupiedInDirection(
          origin: state.currentCoordinate,
          direction: SpatialDirection.east,
        );
      } else if (deltaFromTarget > screenW * distanceThresholdPercent ||
          vx > velocityThreshold) {
        // سحب لليمين -> التوجه للغرب (-X)
        targetCoord = topology.findNextOccupiedInDirection(
          origin: state.currentCoordinate,
          direction: SpatialDirection.west,
        );
      }

      final destination = targetCoord ?? state.currentCoordinate;
      final finalX = -destination.x * screenW;
      final finalY = destination.y * screenH;

      _panX.animateWith(
        SpatialPhysics.createPanSimulation(
          start: _panX.value,
          end: finalX,
          velocity: vx,
        ),
      );
      _panY.animateWith(
        SpatialPhysics.createPanSimulation(
          start: _panY.value,
          end: finalY,
          velocity: 0,
        ),
      );

      if (destination != state.currentCoordinate) {
        cubit.moveToCoordinate(destination);
      } else if (targetCoord == null &&
          (deltaFromTarget.abs() > screenW * 0.25 || vx.abs() > 180)) {
        SoundController.instance.playBoundaryBump();
      }
    } else if (_lockedAxis == Axis.vertical) {
      final vy = details.velocity.pixelsPerSecond.dy;
      final currentTargetY = state.currentCoordinate.y * screenH;
      final deltaFromTarget = _panY.value - currentTargetY;

      SpatialCoordinate? targetCoord;

      if (deltaFromTarget > screenH * distanceThresholdPercent ||
          vy > velocityThreshold) {
        // سحب للأسفل -> التوجه للشمال (+Y)
        targetCoord = topology.findNextOccupiedInDirection(
          origin: state.currentCoordinate,
          direction: SpatialDirection.north,
        );
      } else if (deltaFromTarget < -screenH * distanceThresholdPercent ||
          vy < -velocityThreshold) {
        // سحب للأعلى -> التوجه للجنوب (-Y)
        targetCoord = topology.findNextOccupiedInDirection(
          origin: state.currentCoordinate,
          direction: SpatialDirection.south,
        );
      }

      final destination = targetCoord ?? state.currentCoordinate;
      final finalX = -destination.x * screenW;
      final finalY = destination.y * screenH;

      _panY.animateWith(
        SpatialPhysics.createPanSimulation(
          start: _panY.value,
          end: finalY,
          velocity: vy,
        ),
      );
      _panX.animateWith(
        SpatialPhysics.createPanSimulation(
          start: _panX.value,
          end: finalX,
          velocity: 0,
        ),
      );

      if (destination != state.currentCoordinate) {
        cubit.moveToCoordinate(destination);
      } else if (targetCoord == null &&
          (deltaFromTarget.abs() > screenH * 0.25 || vy.abs() > 180)) {
        SoundController.instance.playBoundaryBump();
      }
    } else {
      _snapToCurrentState(state);
    }

    _lockedAxis = null;
  }

  /// 📐 معادلة الكانفاس اللانهائية الشاملة: تموضع الكاميرا الديكارتي بدقة
  void _snapToCurrentState(SpatialShellState state) {
    if (!mounted) return;
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;

    final tx = -state.currentCoordinate.x * w;
    final ty = state.currentCoordinate.y * h;

    _panX.animateWith(
      SpatialPhysics.createPanSimulation(
        start: _panX.value,
        end: tx,
        velocity: 0,
      ),
    );
    _panY.animateWith(
      SpatialPhysics.createPanSimulation(
        start: _panY.value,
        end: ty,
        velocity: 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shellCubit = context.read<SpatialShellCubit>();
    final ambientVoiceCubit = context.read<AmbientVoiceCubit>();
    final topology = context.read<SpatialTopology>();

    return BlocListener<SpatialShellCubit, SpatialShellState>(
      listenWhen: (previous, current) =>
          previous.currentCoordinate != current.currentCoordinate,
      listener: (context, state) {
        if (_lockedAxis == null && !_isTwoFingerElevator) {
          _snapToCurrentState(state);
        }

        final targetZ = state.currentFloor.toDouble();
        if (!_isTransitioningViaGesture &&
            (_floorZ.value - targetZ).abs() > 0.001) {
          _floorZ.animateWith(
            SpatialPhysics.createZAxisSimulation(
              start: _floorZ.value,
              end: targetZ,
              velocity: 0,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: context.scaffoldBg,
        body: SafeArea(
          child: CornerSwipeDetector(
            onCornerSwipe: () => ambientVoiceCubit.startSession(),
            child: Listener(
              onPointerDown: (e) => _onPointerDown(e, ambientVoiceCubit),
              onPointerMove: (e) => _onPointerMove(e, shellCubit),
              onPointerUp: (e) =>
                  _onPointerUp(e, shellCubit, ambientVoiceCubit),
              onPointerCancel: (e) => _onPointerCancel(e, ambientVoiceCubit),
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollStartNotification) {
                    _isInnerListScrolling = true;
                  } else if (notification is ScrollEndNotification) {
                    _isInnerListScrolling = false;
                  }
                  return false;
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onScaleStart: _onScaleStart,
                  onScaleUpdate: _onScaleUpdate,
                  onScaleEnd: (d) => _onScaleEnd(d, shellCubit),
                  child: BlocBuilder<SpatialShellCubit, SpatialShellState>(
                    builder: (context, state) {
                      return AnimatedBuilder(
                        animation: Listenable.merge([_panX, _panY, _floorZ]),
                        builder: (context, child) {
                          final minF = topology.minFloor;
                          final maxF = topology.maxFloor;
                          final currentZ = _floorZ.value;
                          final panOffset = Offset(_panX.value, _panY.value);

                          final lowerFloor = currentZ.floor().clamp(minF, maxF);
                          final upperFloor = currentZ.ceil().clamp(minF, maxF);

                          final visibleFloors = <int>{lowerFloor, upperFloor}
                              .where((f) => topology.hasFloor(f))
                              .toList()
                            ..sort((a, b) => b.compareTo(a));

                          final activeFloor = currentZ.round().clamp(minF, maxF);

                          return Stack(
                            children: [
                              for (final floor in visibleFloors)
                                _buildFloorTransform(
                                  floor: floor,
                                  currentZ: currentZ,
                                  panOffset: panOffset,
                                  coordinate: state.currentCoordinate,
                                  isActive: floor == activeFloor,
                                ),
                              SpatialCompassHud(
                                direction: state.currentDirection,
                                currentFloor: activeFloor,
                                currentCoordinate: state.currentCoordinate,
                                onCenterTap: shellCubit.returnToCenter,
                                onFloorToggle: shellCubit.toggleFloor,
                                onAscend: shellCubit.ascend,
                                onDescend: shellCubit.descend,
                              ),
                              const AmbientVoiceOverlay(),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloorTransform({
    required int floor,
    required double currentZ,
    required Offset panOffset,
    required SpatialCoordinate coordinate,
    required bool isActive,
  }) {
    final relativeDistance = floor - currentZ;
    final distanceAbs = relativeDistance.abs();

    if (distanceAbs >= 1.0) return const SizedBox.shrink();

    final opacity = SpatialPhysics.smootherStep(
      (1.0 - distanceAbs).clamp(0.0, 1.0),
    );

    final double scale;
    if (relativeDistance >= 0) {
      scale = 1.0 - (relativeDistance * 0.12);
    } else {
      scale = 1.0 - (relativeDistance * 0.10);
    }

    final translateY = -relativeDistance * SpatialPhysics.elevationLiftOffset;
    final tiltX = relativeDistance * 0.04;

    final matrix = Matrix4.identity()
      ..setEntry(3, 2, SpatialPhysics.perspectiveCoefficient)
      ..translate(0.0, translateY)
      ..scale(scale, scale)
      ..rotateX(tiltX);

    return Transform(
      key: ValueKey('spatial_floor_transform_$floor'),
      alignment: Alignment.center,
      transform: matrix,
      child: Opacity(
        opacity: opacity,
        child: IgnorePointer(
          ignoring: !isActive,
          child: SpatialFloorLayout(
            key: ValueKey('spatial_floor_layout_$floor'),
            currentCoordinate: coordinate,
            floorLevel: floor,
            panOffset: panOffset,
          ),
        ),
      ),
    );
  }
}

// 🛡️ توافق كامل مع الكود السابق
typedef SpatialCompassPage = SpatialShellPage;