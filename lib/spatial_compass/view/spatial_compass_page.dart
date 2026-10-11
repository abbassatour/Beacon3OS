// lib/spatial_compass/view/spatial_compass_page.dart
import 'dart:async';

import 'package:beacon_os/agenda/cubit/agenda_cubit.dart';
import 'package:beacon_os/cockpit_dashboard/cubit/cockpit_dashboard_cubit.dart';
import 'package:beacon_os/communications/cubit/communications_cubit.dart';
import 'package:beacon_os/core/haptics/haptic_manager.dart';
import 'package:beacon_os/core/physics/spatial_physics.dart';
import 'package:beacon_os/core/spatial_kernel/ambient_voice/cubit/ambient_voice_cubit.dart';
import 'package:beacon_os/core/spatial_kernel/spatial_topology.dart';
import 'package:beacon_os/core/spatial_kernel/voice_command_dispatcher.dart';
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/focus_alarms/cubit/focus_alarms_cubit.dart';
import 'package:beacon_os/settings/cubit/settings_cubit.dart';
import 'package:beacon_os/spatial_compass/cubit/spatial_compass_cubit.dart';
import 'package:beacon_os/spatial_compass/cubit/spatial_compass_state.dart';
import 'package:beacon_os/spatial_compass/widgets/ambient_voice_sheet.dart';
import 'package:beacon_os/spatial_compass/widgets/corner_swipe_detector.dart';
import 'package:beacon_os/spatial_compass/widgets/floor_layouts.dart';
import 'package:beacon_os/spatial_compass/widgets/spatial_compass_hud.dart';
import 'package:beacon_os/spatial_vision/cubit/spatial_vision_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';

class SpatialCompassPage extends StatelessWidget {
  const SpatialCompassPage({super.key});

  @override
  Widget build(BuildContext context) {
    final topology = context.read<SpatialTopology>();

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => SpatialCompassCubit(
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
          create: (context) => CockpitDashboardCubit(
            taskRepository: context.read<TaskAgendaRepository>(),
            focusAlarmsRepository: context.read<FocusAlarmsRepository>(),
            hardwareRepository: context.read<SystemHardwareRepository>(),
            assistantRepository: context.read<AssistantRepository>(),
          ),
        ),
        BlocProvider(
          create: (context) => FocusAlarmsCubit(
            focusRepository: context.read<FocusAlarmsRepository>(),
            assistantRepository: context.read<AssistantRepository>(),
            settingsRepository: context.read<SettingsRepository>(),
          ),
        ),
        BlocProvider(
          create: (context) => CommunicationsCubit(
            commsRepository: context.read<CommsRepository>(),
            hardwareRepository: context.read<SystemHardwareRepository>(),
            assistantRepository: context.read<AssistantRepository>(),
          ),
        ),
        BlocProvider(
          create: (context) => SpatialVisionCubit(
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
      child: const _SpatialCompassBody(),
    );
  }
}

class _SpatialCompassBody extends StatefulWidget {
  const _SpatialCompassBody();

  @override
  State<_SpatialCompassBody> createState() => _SpatialCompassBodyState();
}

class _SpatialCompassBodyState extends State<_SpatialCompassBody>
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

    // 🛡️ فور نزول إصبع ثانٍ، نلغي أي مؤقت أو جلسة صوتية لمصلحة إيماءة المصعد
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
    SpatialCompassCubit cubit,
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

    final state = context.read<SpatialCompassCubit>().state;

    // 🌟 1. معالجة المصعد الرأسي بدقة طالما الإصبعان على الشاشة
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

      // نبض لمسي ذكي بنظام Hysteresis دقيق عند منتصف أي طابقين متتاليين
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

    // 🛡️ حماية حاسمة: إذا رفع المستخدم إصبعاً واحداً أثناء حركة المصعد، نتجاهل تحديث scale
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

      if (state.currentDirection == CompassDirection.center) {
        if (rawVal > screenWidth) {
          isWall = true;
          wallLimit = screenWidth;
        } else if (rawVal < -screenWidth) {
          isWall = true;
          wallLimit = -screenWidth;
        }
      } else if (state.currentDirection == CompassDirection.east) {
        if (rawVal < -screenWidth) {
          isWall = true;
          wallLimit = -screenWidth;
        } else if (rawVal > 0) {
          isWall = true;
          wallLimit = 0;
        }
      } else if (state.currentDirection == CompassDirection.west) {
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

      if (state.currentDirection == CompassDirection.center) {
        if (rawVal > screenHeight) {
          isWall = true;
          wallLimit = screenHeight;
        } else if (rawVal < -screenHeight) {
          isWall = true;
          wallLimit = -screenHeight;
        }
      } else if (state.currentDirection == CompassDirection.north) {
        if (rawVal > screenHeight) {
          isWall = true;
          wallLimit = screenHeight;
        } else if (rawVal < 0) {
          isWall = true;
          wallLimit = 0;
        }
      } else if (state.currentDirection == CompassDirection.south) {
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

  void _onScaleEnd(ScaleEndDetails details, SpatialCompassCubit cubit) {
    if (_isHoldingToSpeak) return;

    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    final state = cubit.state;

    // 🌟 2. معالجة انتهاء إيماءة المصعد الرأسي بخوارزمية العزم المستمر لأي طابق N
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

      if (state.currentDirection == CompassDirection.center) {
        if (_panX.value > screenW * distanceThresholdPercent ||
            vx > velocityThreshold) {
          targetX = screenW;
          targetDir = CompassDirection.west;
        } else if (_panX.value < -screenW * distanceThresholdPercent ||
            vx < -velocityThreshold) {
          targetX = -screenW;
          targetDir = CompassDirection.east;
        } else {
          targetX = 0.0;
        }
      } else if (state.currentDirection == CompassDirection.east) {
        if (_panX.value > -screenW * (1.0 - distanceThresholdPercent) ||
            vx > velocityThreshold) {
          targetX = 0.0;
          targetDir = CompassDirection.center;
        } else {
          targetX = -screenW;
          targetDir = CompassDirection.east;
        }
      } else if (state.currentDirection == CompassDirection.west) {
        if (_panX.value < screenW * (1.0 - distanceThresholdPercent) ||
            vx < -velocityThreshold) {
          targetX = 0.0;
          targetDir = CompassDirection.center;
        } else {
          targetX = screenW;
          targetDir = CompassDirection.west;
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

      if (state.currentDirection == CompassDirection.center) {
        if (_panY.value > screenH * distanceThresholdPercent ||
            vy > velocityThreshold) {
          targetY = screenH;
          targetDir = CompassDirection.north;
        } else if (_panY.value < -screenH * distanceThresholdPercent ||
            vy < -velocityThreshold) {
          targetY = -screenH;
          targetDir = CompassDirection.south;
        } else {
          targetY = 0.0;
        }
      } else if (state.currentDirection == CompassDirection.north) {
        if (_panY.value < screenH * (1.0 - distanceThresholdPercent) ||
            vy < -velocityThreshold) {
          targetY = 0.0;
          targetDir = CompassDirection.center;
        } else {
          targetY = screenH;
          targetDir = CompassDirection.north;
        }
      } else if (state.currentDirection == CompassDirection.south) {
        if (_panY.value > -screenH * (1.0 - distanceThresholdPercent) ||
            vy > velocityThreshold) {
          targetY = 0.0;
          targetDir = CompassDirection.center;
        } else {
          targetY = -screenH;
          targetDir = CompassDirection.south;
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

  void _snapToCurrentState(SpatialCompassState state) {
    if (!mounted) return;
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;
    var tx = 0.0;
    var ty = 0.0;

    switch (state.currentDirection) {
      case CompassDirection.center:
        break;
      case CompassDirection.east:
        tx = -w;
        break;
      case CompassDirection.west:
        tx = w;
        break;
      case CompassDirection.north:
        ty = h;
        break;
      case CompassDirection.south:
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
    final compassCubit = context.read<SpatialCompassCubit>();
    final ambientVoiceCubit = context.read<AmbientVoiceCubit>();
    final topology = context.read<SpatialTopology>();

    return BlocListener<SpatialCompassCubit, SpatialCompassState>(
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
                  _onPointerUp(e, compassCubit, ambientVoiceCubit),
              onPointerCancel: (e) => _onPointerCancel(e, ambientVoiceCubit),
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onScaleStart: _onScaleStart,
                onScaleUpdate: _onScaleUpdate,
                onScaleEnd: (d) => _onScaleEnd(d, compassCubit),
                child: BlocBuilder<SpatialCompassCubit, SpatialCompassState>(
                  builder: (context, state) {
                    return AnimatedBuilder(
                      animation: Listenable.merge([_panX, _panY, _floorZ]),
                      builder: (context, child) {
                        final minF = topology.minFloor;
                        final maxF = topology.maxFloor;
                        final currentZ = _floorZ.value;
                        final panOffset = Offset(_panX.value, _panY.value);

                        // 🔍 1. استخراج الطوابق المرئية لحظياً (فقط الطابقان المحيطان بموضع المصعد)
                        final lowerFloor = currentZ.floor().clamp(minF, maxF);
                        final upperFloor = currentZ.ceil().clamp(minF, maxF);

                        final visibleFloors = <int>{lowerFloor, upperFloor}
                            .where((f) => topology.hasFloor(f))
                            .toList()
                          // 📐 ترتيب الرسم (Z-Order): رسم الطوابق الأعمق/الأعلى أولاً لتكون الطوابق الأقرب في المقدمة
                          ..sort((a, b) => b.compareTo(a));

                        final activeFloor = currentZ.round().clamp(minF, maxF);

                        return Stack(
                          children: [
                            // 🌟 2. المُصيّر ثلاثي الأبعاد الديناميكي (Dynamic Virtualized Viewport)
                            for (final floor in visibleFloors)
                              _buildFloorTransform(
                                floor: floor,
                                currentZ: currentZ,
                                panOffset: panOffset,
                                direction: state.currentDirection,
                                isActive: floor == activeFloor,
                              ),

                            // 🗺️ 3. شريط الـ HUD الملاحي المتزامن مع الطابق النشط
                            // 🗺️ 3. شريط الـ HUD الملاحي المتزامن مع الطابق النشط
                            SpatialCompassHud(
                              direction: state.currentDirection,
                              currentFloor: activeFloor,
                              onCenterTap: compassCubit.returnToCenter,
                              onFloorToggle: compassCubit.toggleFloor,
                              onAscend: compassCubit.ascend,
                              onDescend: compassCubit.descend,
                            ),

                            // 🎙️ 4. لوحة المساعد الصوتي العائمة
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

  /// 📐 معادلة المنظور ثلاثي الأبعاد الموحدة لأي طابق مهما كان رقمه
  Widget _buildFloorTransform({
    required int floor,
    required double currentZ,
    required Offset panOffset,
    required CompassDirection direction,
    required bool isActive,
  }) {
    final relativeDistance = floor - currentZ;
    final distanceAbs = relativeDistance.abs();

    if (distanceAbs >= 1.0) return const SizedBox.shrink();

    // 🌀 1. التلاشي المنحني المتصل خماسي الحدود (Perlin's Smootherstep)
    final opacity = SpatialPhysics.smootherStep(
      (1.0 - distanceAbs).clamp(0.0, 1.0),
    );

    // 🔍 2. التكبير والتصغير المنظوري للعمق
    final double scale;
    if (relativeDistance >= 0) {
      // الطابق أعلى منا (في العمق البصري)
      scale = 1.0 - (relativeDistance * 0.12);
    } else {
      // الطابق أسفل منا (يتسع للأمام نحو الكاميرا)
      scale = 1.0 - (relativeDistance * 0.10);
    }

    // 🛗 3. إزاحة البارالاكس الرأسي المتزامن مع نغمة المصعد
    final translateY = -relativeDistance * SpatialPhysics.elevationLiftOffset;

    // 📐 4. زاوية الميلان ثلاثية الأبعاد السينمائية (3D Pitch Angle)
    final tiltX = relativeDistance * 0.04;

    // 🎥 5. بناء مصفوفة التحويلات الفضائية Matrix4
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