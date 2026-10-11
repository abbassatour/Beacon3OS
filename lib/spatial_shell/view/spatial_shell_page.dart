import 'dart:async';

import 'package:beacon_os/agenda/agenda.dart';
import 'package:beacon_os/cockpit/cockpit.dart';
import 'package:beacon_os/comms/comms.dart';
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

  int _activePointers = 0;
  DateTime? _multiTouchStartTime;
  bool _hasTwoFingerMoved = false;

  int _tapCount = 0;
  DateTime? _lastTapTime;

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
    _panX.dispose();
    _panY.dispose();
    _floorZ.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event, AmbientVoiceCubit voiceCubit) {
    _activePointers++;
    _pointerDownPos = event.position;

    if (_activePointers == 2) {
      _holdToSpeakTimer?.cancel();
      if (_isHoldingToSpeak) {
        _isHoldingToSpeak = false;
        voiceCubit.closeSession();
      }
      _multiTouchStartTime = DateTime.now();
      _hasTwoFingerMoved = false;
      _tapCount = 0;
    } else if (_activePointers == 1) {
      final now = DateTime.now();
      if (_lastTapTime == null ||
          now.difference(_lastTapTime!).inMilliseconds > 450) {
        _tapCount = 1;
      } else {
        _tapCount++;
      }
      _lastTapTime = now;

      if (_tapCount == 3) {
        _holdToSpeakTimer?.cancel();
        _isHoldingToSpeak = false;
        _triggerTripleTapSos();
        _tapCount = 0;
        return;
      }

      _holdToSpeakTimer?.cancel();
      _holdToSpeakTimer = Timer(const Duration(milliseconds: 400), () {
        if (_activePointers == 1 &&
            !_isTwoFingerElevator &&
            !voiceCubit.state.isOpen) {
          _isHoldingToSpeak = true;
          voiceCubit.startSession();
        }
      });
    } else {
      _holdToSpeakTimer?.cancel();
      _isHoldingToSpeak = false;
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
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
    _holdToSpeakTimer?.cancel();

    if (_isHoldingToSpeak) {
      _isHoldingToSpeak = false;
      voiceCubit.stopAndExecute();
    } else if (_activePointers == 2 && _multiTouchStartTime != null) {
      final tapDuration = DateTime.now().difference(_multiTouchStartTime!);
      if (!_hasTwoFingerMoved && tapDuration.inMilliseconds < 300) {
        _multiTouchStartTime = null;
        cubit.announceCurrentLocation();
      }
    }

    _activePointers = (_activePointers - 1).clamp(0, 10);
    if (_activePointers == 0) {
      _hasTwoFingerMoved = false;
      _pointerDownPos = null;
    }
  }

  void _onPointerCancel(
    PointerCancelEvent event,
    AmbientVoiceCubit voiceCubit,
  ) {
    _holdToSpeakTimer?.cancel();
    if (_isHoldingToSpeak) {
      _isHoldingToSpeak = false;
      voiceCubit.closeSession();
    }
    _activePointers = (_activePointers - 1).clamp(0, 10);
    _pointerDownPos = null;
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
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (_isHoldingToSpeak) return;

    final state = context.read<SpatialShellCubit>().state;

    if (details.pointerCount >= 2) {
      _isTwoFingerElevator = true;

      final topology = context.read<SpatialTopology>();
      final minFloor = topology.minFloor.toDouble();
      final maxFloor = topology.maxFloor.toDouble();

      final scaleDelta = (details.scale - 1.0) * 1.5;
      final rawZ = _initialScale + scaleDelta;

      double computedZ;
      if (rawZ < minFloor) {
        computedZ = minFloor -
            SpatialPhysics.applyRubberBanding(
              delta: minFloor - rawZ,
              limit: 0.20,
            );
      } else if (rawZ > maxFloor) {
        computedZ = maxFloor +
            SpatialPhysics.applyRubberBanding(
              delta: rawZ - maxFloor,
              limit: 0.20,
            );
      } else {
        computedZ = rawZ;
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

    if (_isTwoFingerElevator && details.pointerCount < 2) {
      return;
    }

    final dx = details.focalPointDelta.dx;
    final dy = details.focalPointDelta.dy;

    _accumulatedDeltaX += dx;
    _accumulatedDeltaY += dy;

    const touchSlopThreshold = 6.0;
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

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    if (_lockedAxis == Axis.horizontal) {
      final rawVal = _startXAtGesture + _accumulatedDeltaX;
      var isWall = false;
      var wallLimit = 0.0;

      if (state.currentDirection == SpatialDirection.center) {
        if (rawVal > screenWidth) {
          isWall = true;
          wallLimit = screenWidth;
        } else if (rawVal < -screenWidth) {
          isWall = true;
          wallLimit = -screenWidth;
        }
      } else if (state.currentDirection == SpatialDirection.east) {
        if (rawVal < -screenWidth) {
          isWall = true;
          wallLimit = -screenWidth;
        } else if (rawVal > 0) {
          isWall = true;
          wallLimit = 0;
        }
      } else if (state.currentDirection == SpatialDirection.west) {
        if (rawVal > screenWidth) {
          isWall = true;
          wallLimit = screenWidth;
        } else if (rawVal < 0) {
          isWall = true;
          wallLimit = 0;
        }
      } else {
        isWall = true;
        wallLimit = 0.0;
      }

      if (isWall) {
        final excess = rawVal - wallLimit;
        _panX.value = wallLimit +
            SpatialPhysics.applyRubberBanding(
              delta: excess,
              limit: screenWidth,
            );
      } else {
        _panX.value = rawVal;
      }

      if (!isWall) {
        final dragDistance = (_panX.value - _startXAtGesture).abs();
        final hapticThreshold = screenWidth * 0.18;
        if (dragDistance > hapticThreshold) {
          if (!_hapticDetentFired) {
            HapticManager.instance.selectionClick();
            _hapticDetentFired = true;
          }
        } else {
          _hapticDetentFired = false;
        }
      }
    } else if (_lockedAxis == Axis.vertical) {
      final rawVal = _startYAtGesture + _accumulatedDeltaY;
      var isWall = false;
      var wallLimit = 0.0;

      if (state.currentDirection == SpatialDirection.center) {
        if (rawVal > screenHeight) {
          isWall = true;
          wallLimit = screenHeight;
        } else if (rawVal < -screenHeight) {
          isWall = true;
          wallLimit = -screenHeight;
        }
      } else if (state.currentDirection == SpatialDirection.north) {
        if (rawVal > screenHeight) {
          isWall = true;
          wallLimit = screenHeight;
        } else if (rawVal < 0) {
          isWall = true;
          wallLimit = 0;
        }
      } else if (state.currentDirection == SpatialDirection.south) {
        if (rawVal < -screenHeight) {
          isWall = true;
          wallLimit = -screenHeight;
        } else if (rawVal > 0) {
          isWall = true;
          wallLimit = 0;
        }
      } else {
        isWall = true;
        wallLimit = 0.0;
      }

      if (isWall) {
        final excess = rawVal - wallLimit;
        _panY.value = wallLimit +
            SpatialPhysics.applyRubberBanding(
              delta: excess,
              limit: screenHeight,
            );
      } else {
        _panY.value = rawVal;
      }

      if (!isWall) {
        final dragDistance = (_panY.value - _startYAtGesture).abs();
        final hapticThreshold = screenHeight * 0.18;
        if (dragDistance > hapticThreshold) {
          if (!_hapticDetentFired) {
            HapticManager.instance.selectionClick();
            _hapticDetentFired = true;
          }
        } else {
          _hapticDetentFired = false;
        }
      }
    }
  }

  void _onScaleEnd(ScaleEndDetails details, SpatialShellCubit cubit) {
    if (_isHoldingToSpeak) return;

    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    final state = cubit.state;

    if (_isTwoFingerElevator) {
      _isTwoFingerElevator = false;
      _isTransitioningViaGesture = true;

      final topology = context.read<SpatialTopology>();
      final minFloor = topology.minFloor;
      final maxFloor = topology.maxFloor;

      final scaleVel = details.scaleVelocity;
      final vz = (scaleVel * 1.5).clamp(-4.0, 4.0);
      final velocityBias = vz.clamp(-1.5, 1.5) * 0.35;
      final projectedZ = _floorZ.value + velocityBias;

      int targetFloor;
      final deltaFromInitial = _floorZ.value - _initialScale;

      if (deltaFromInitial > 0.30 || vz > 0.5) {
        targetFloor = (_initialScale + 1).round();
      } else if (deltaFromInitial < -0.30 || vz < -0.5) {
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

    const distanceThresholdPercent = 0.18;
    const velocityThreshold = 180.0;

    if (_lockedAxis == Axis.horizontal) {
      final vx = details.velocity.pixelsPerSecond.dx;
      var targetX = _panX.value;
      var targetDir = state.currentDirection;

      if (state.currentDirection == SpatialDirection.center) {
        if (_panX.value > screenW * distanceThresholdPercent ||
            vx > velocityThreshold) {
          targetX = screenW;
          targetDir = SpatialDirection.west;
        } else if (_panX.value < -screenW * distanceThresholdPercent ||
            vx < -velocityThreshold) {
          targetX = -screenW;
          targetDir = SpatialDirection.east;
        } else {
          targetX = 0.0;
        }
      } else if (state.currentDirection == SpatialDirection.east) {
        if (_panX.value > -screenW * (1.0 - distanceThresholdPercent) ||
            vx > velocityThreshold) {
          targetX = 0.0;
          targetDir = SpatialDirection.center;
        } else {
          targetX = -screenW;
          targetDir = SpatialDirection.east;
        }
      } else if (state.currentDirection == SpatialDirection.west) {
        if (_panX.value < screenW * (1.0 - distanceThresholdPercent) ||
            vx < -velocityThreshold) {
          targetX = 0.0;
          targetDir = SpatialDirection.center;
        } else {
          targetX = screenW;
          targetDir = SpatialDirection.west;
        }
      } else {
        _snapToCurrentState(state);
        return;
      }

      _panX.animateWith(
        SpatialPhysics.createPanSimulation(
          start: _panX.value,
          end: targetX,
          velocity: vx,
        ),
      );
      _panY.animateWith(
        SpatialPhysics.createPanSimulation(
          start: _panY.value,
          end: 0,
          velocity: 0,
        ),
      );
      if (targetDir != state.currentDirection) cubit.moveTo(targetDir);
    } else if (_lockedAxis == Axis.vertical) {
      final vy = details.velocity.pixelsPerSecond.dy;
      var targetY = _panY.value;
      var targetDir = state.currentDirection;

      if (state.currentDirection == SpatialDirection.center) {
        if (_panY.value > screenH * distanceThresholdPercent ||
            vy > velocityThreshold) {
          targetY = screenH;
          targetDir = SpatialDirection.north;
        } else if (_panY.value < -screenH * distanceThresholdPercent ||
            vy < -velocityThreshold) {
          targetY = -screenH;
          targetDir = SpatialDirection.south;
        } else {
          targetY = 0.0;
        }
      } else if (state.currentDirection == SpatialDirection.north) {
        if (_panY.value < screenH * (1.0 - distanceThresholdPercent) ||
            vy < -velocityThreshold) {
          targetY = 0.0;
          targetDir = SpatialDirection.center;
        } else {
          targetY = screenH;
          targetDir = SpatialDirection.north;
        }
      } else if (state.currentDirection == SpatialDirection.south) {
        if (_panY.value > -screenH * (1.0 - distanceThresholdPercent) ||
            vy > velocityThreshold) {
          targetY = 0.0;
          targetDir = SpatialDirection.center;
        } else {
          targetY = -screenH;
          targetDir = SpatialDirection.south;
        }
      } else {
        _snapToCurrentState(state);
        return;
      }

      _panY.animateWith(
        SpatialPhysics.createPanSimulation(
          start: _panY.value,
          end: targetY,
          velocity: vy,
        ),
      );
      _panX.animateWith(
        SpatialPhysics.createPanSimulation(
          start: _panX.value,
          end: 0,
          velocity: 0,
        ),
      );
      if (targetDir != state.currentDirection) cubit.moveTo(targetDir);
    } else {
      _snapToCurrentState(state);
    }

    _lockedAxis = null;
  }

  void _snapToCurrentState(SpatialShellState state) {
    if (!mounted) return;
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;
    var tx = 0.0;
    var ty = 0.0;

    switch (state.currentDirection) {
      case SpatialDirection.center:
        break;
      case SpatialDirection.east:
        tx = -w;
        break;
      case SpatialDirection.west:
        tx = w;
        break;
      case SpatialDirection.north:
        ty = h;
        break;
      case SpatialDirection.south:
        ty = -h;
        break;
    }

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
          previous.currentDirection != current.currentDirection ||
          previous.currentFloor != current.currentFloor,
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
              onPointerMove: _onPointerMove,
              onPointerUp: (e) =>
                  _onPointerUp(e, shellCubit, ambientVoiceCubit),
              onPointerCancel: (e) => _onPointerCancel(e, ambientVoiceCubit),
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
                                direction: state.currentDirection,
                                isActive: floor == activeFloor,
                              ),
                            SpatialCompassHud(
                              direction: state.currentDirection,
                              currentFloor: activeFloor,
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
    );
  }

  Widget _buildFloorTransform({
    required int floor,
    required double currentZ,
    required Offset panOffset,
    required SpatialDirection direction,
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
            direction: direction,
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