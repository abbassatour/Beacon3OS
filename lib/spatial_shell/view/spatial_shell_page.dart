// lib/spatial_shell/view/spatial_shell_page.dart
import 'dart:async';

import 'package:beacon_os/agenda/agenda.dart';
import 'package:beacon_os/cockpit/cockpit.dart';
import 'package:beacon_os/comms/comms.dart';
import 'package:beacon_os/core/haptics/haptic_manager.dart';
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/core/topology/topology.dart';
import 'package:beacon_os/core/voice_bus/voice_bus.dart';
import 'package:beacon_os/focus/focus.dart';
import 'package:beacon_os/preferences/preferences.dart';
import 'package:beacon_os/spatial_shell/controllers/spatial_camera_controller.dart';
import 'package:beacon_os/spatial_shell/cubit/spatial_shell_cubit.dart';
import 'package:beacon_os/spatial_shell/cubit/spatial_shell_state.dart';
import 'package:beacon_os/spatial_shell/widgets/ambient_voice_overlay.dart';
import 'package:beacon_os/spatial_shell/widgets/corner_swipe_detector.dart';
import 'package:beacon_os/spatial_shell/widgets/spatial_compass_hud.dart';
import 'package:beacon_os/spatial_shell/widgets/spatial_floor_layout.dart';
import 'package:beacon_os/spatial_shell/widgets/spatial_portal_transform.dart';
import 'package:beacon_os/spatial_shell/widgets/tactile_multi_touch_detector.dart';
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
            topologyRepository: context.read<TopologyRepository>(), // ⚡️ حقن مستودع الطوبولوجيا للمزامنة اللحظية
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
  late final SpatialCameraController _cameraController;
  StreamSubscription<void>? _topologySubscription;
  bool _isInnerListScrolling = false;

  @override
  void initState() {
    super.initState();
    _cameraController = SpatialCameraController(vsync: this);

    // 🎯 محاذاة الكاميرا فورياً مع الإحداثي المحفوظ عند تشغيل الشاشة لمنع أي وميض أو قفزة غير مرغوبة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = context.read<SpatialShellCubit>().state;
      final screenSize = MediaQuery.sizeOf(context);
      _cameraController.snapToCoordinate(state.currentCoordinate, screenSize);
      _cameraController.animateToFloor(state.currentFloor);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ⚡️ الاستماع لتحديثات شبكة الغرف لإعادة رسم الكانفاس فورياً عند تحريك أي غرفة في الخلفية
    _topologySubscription ??=
        context.read<SpatialTopology>().changes.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _topologySubscription?.cancel();
    _cameraController.dispose();
    super.dispose();
  }

  Future<void> _triggerTripleTapSos(BuildContext context) async {
    await HapticManager.instance.emergencyAlarmPulse();
    if (!context.mounted) return;
    try {
      final commsRepo = context.read<CommsRepository>();
      await commsRepo.triggerEmergencySos();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final shellCubit = context.read<SpatialShellCubit>();
    final voiceCubit = context.read<AmbientVoiceCubit>();
    final topology = context.read<SpatialTopology>();
    final screenSize = MediaQuery.sizeOf(context);

    return BlocListener<SpatialShellCubit, SpatialShellState>(
      listenWhen: (previous, current) =>
          previous.currentCoordinate != current.currentCoordinate ||
          previous.currentFloor != current.currentFloor,
      listener: (context, state) {
        if (!_cameraController.isGestureActive) {
          _cameraController.snapToCoordinate(state.currentCoordinate, screenSize);
          _cameraController.animateToFloor(state.currentFloor);
        }
      },
      child: Scaffold(
        backgroundColor: context.scaffoldBg,
        body: SafeArea(
          child: CornerSwipeDetector(
            onCornerSwipe: voiceCubit.startSession,
            child: TactileMultiTouchDetector(
              onTripleTapSos: () => _triggerTripleTapSos(context),
              onOrientationPing: shellCubit.announceCurrentLocation,
              onThreeFingerSwipeUp: shellCubit.ascend,
              onThreeFingerSwipeDown: shellCubit.descend,
              onHoldToSpeakStart: voiceCubit.startSession,
              onHoldToSpeakEnd: voiceCubit.stopAndExecute,
              onHoldToSpeakCancel: voiceCubit.closeSession,
              onInnerScrollChanged: (isScrolling) {
                _isInnerListScrolling = isScrolling;
              },
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onScaleStart: (details) => _cameraController.onScaleStart(
                  details,
                  floorLevel: shellCubit.state.currentFloor,
                ),
                onScaleUpdate: (details) => _cameraController.onScaleUpdate(
                  details: details,
                  state: shellCubit.state,
                  topology: topology,
                  screenSize: screenSize,
                  isInnerListScrolling: _isInnerListScrolling,
                  onWhisperDirection: shellCubit.whisperRoomScrubbing,
                ),
                onScaleEnd: (details) => _cameraController.onScaleEnd(
                  details: details,
                  state: shellCubit.state,
                  topology: topology,
                  screenSize: screenSize,
                  onTargetCoordinateSelected: shellCubit.moveToCoordinate,
                  onTargetFloorSelected: shellCubit.jumpToFloor,
                ),
                child: BlocBuilder<SpatialShellCubit, SpatialShellState>(
                  builder: (context, state) {
                    return ListenableBuilder(
                      listenable: _cameraController,
                      builder: (context, child) {
                        final minF = topology.minFloor;
                        final maxF = topology.maxFloor;
                        final currentZ = _cameraController.currentZ;

                        final lowerFloor = currentZ.floor().clamp(minF, maxF);
                        final upperFloor = currentZ.ceil().clamp(minF, maxF);

                        final visibleFloors = <int>{lowerFloor, upperFloor}
                            .where(topology.hasFloor)
                            .toList()
                          ..sort((a, b) => b.compareTo(a));

                        final activeFloor = currentZ.round().clamp(minF, maxF);

                        return Stack(
                          children: [
                            for (final floor in visibleFloors)
                              SpatialPortalTransform(
                                floor: floor,
                                currentZ: currentZ,
                                isActive: floor == activeFloor,
                                child: SpatialFloorLayout(
                                  key: ValueKey('spatial_floor_layout_$floor'),
                                  currentCoordinate: state.currentCoordinate,
                                  floorLevel: floor,
                                  panOffset: _cameraController.panOffset,
                                ),
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
    );
  }
}

// 🛡️ توافق كامل مع الكود السابق
typedef SpatialCompassPage = SpatialShellPage;