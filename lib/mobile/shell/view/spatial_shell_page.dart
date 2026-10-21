// lib/mobile/shell/view/spatial_shell_page.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:beacon_os/core/audio/sound_controller.dart';
import 'package:beacon_os/core/audio/sound_cue.dart';
import 'package:beacon_os/core/haptics/haptic_manager.dart';
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/core/topology/topology.dart';
import 'package:beacon_os/core/voice_bus/voice_bus.dart';
import 'package:beacon_os/mobile/agenda/agenda.dart';
import 'package:beacon_os/mobile/cockpit/cockpit.dart';
import 'package:beacon_os/mobile/comms/comms.dart';
import 'package:beacon_os/mobile/focus/focus.dart';
import 'package:beacon_os/mobile/perimeter/perimeter.dart';
import 'package:beacon_os/mobile/preferences/preferences.dart';
import 'package:beacon_os/mobile/shell/controllers/spatial_camera_controller.dart';
import 'package:beacon_os/mobile/shell/cubit/spatial_shell_cubit.dart';
import 'package:beacon_os/mobile/shell/cubit/spatial_shell_state.dart';
import 'package:beacon_os/mobile/shell/widgets/ambient_voice_overlay.dart';
import 'package:beacon_os/mobile/shell/widgets/corner_swipe_detector.dart';
import 'package:beacon_os/mobile/shell/widgets/spatial_compass_hud.dart';
import 'package:beacon_os/mobile/shell/widgets/spatial_floor_layout.dart';
import 'package:beacon_os/mobile/shell/widgets/spatial_portal_transform.dart';
import 'package:beacon_os/mobile/shell/widgets/tactile_multi_touch_detector.dart';
import 'package:beacon_os/mobile/shell/widgets/two_finger_gesture_detector.dart';
import 'package:beacon_os/mobile/vision/vision.dart';
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
        // 1. التحكم بالملاحة الفضائية والصوت والإعدادات العامة
        BlocProvider(
          create: (context) => SpatialShellCubit(
            assistantRepository: context.read<AssistantRepository>(),
            topology: topology,
            topologyRepository: context.read<TopologyRepository>(),
          ),
        ),
        BlocProvider(
          create: (context) => PreferencesCubit(
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

        // 🚀 2. رفع الـ Cubits الستة للغرف الفضائية للأعلى (Lift State Up)
        // يتم إنشاؤها مرة واحدة وتظل حية في الذاكرة لمنع إعادة الجلب وتصفير الحالة عند السحب
        BlocProvider(
          create: (context) => CockpitCubit(
            taskRepository: context.read<TaskAgendaRepository>(),
            focusAlarmsRepository: context.read<FocusAlarmsRepository>(),
            hardwareRepository: context.read<SystemHardwareRepository>(),
            assistantRepository: context.read<AssistantRepository>(),
          ),
        ),
        BlocProvider(
          create: (context) => AgendaCubit(
            taskRepository: context.read<TaskAgendaRepository>(),
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
          create: (context) => FocusCubit(
            focusRepository: context.read<FocusAlarmsRepository>(),
            assistantRepository: context.read<AssistantRepository>(),
            settingsRepository: context.read<SettingsRepository>(),
          ),
        ),
        BlocProvider(
          create: (context) => PerimeterCubit(
            ringRepository: context.read<RingRepository>(),
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
  StreamSubscription<RemoteActionEvent>? _remoteActionsSubscription;

  @override
  void initState() {
    super.initState();
    _cameraController = SpatialCameraController(vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final shellCubit = context.read<SpatialShellCubit>();
      final state = shellCubit.state;
      final screenSize = MediaQuery.sizeOf(context);
      _cameraController.snapToCoordinate(state.currentCoordinate, screenSize);
      _cameraController.animateToFloor(state.currentFloor);

      // 🛰️ الاستماع المباشر لأوامر تبديل الطوابق القادمة من أليكسا أو شاشات المنزل
      final commsRepo = context.read<CommsRepository>();
      _remoteActionsSubscription = commsRepo.remoteActionEvents.listen((event) {
        if (event.actionType == RemoteActionType.navigateFloor) {
          final targetFloor = (event.payload['target_floor'] as num?)?.toInt() ?? 0;
          shellCubit.jumpToFloor(targetFloor);
        }
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _topologySubscription ??=
        context.read<SpatialTopology>().changes.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _remoteActionsSubscription?.cancel();
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
          _cameraController.snapToCoordinate(
            state.currentCoordinate,
            screenSize,
          );
          _cameraController.animateToFloor(state.currentFloor);
        }
      },
      child: Scaffold(
        backgroundColor: context.scaffoldBg,
        body: SafeArea(
          child: CornerSwipeDetector(
            onCornerSwipe: () => voiceCubit.startSession(context),
            child: TactileMultiTouchDetector(
              onTripleTapSos: () => _triggerTripleTapSos(context),
              onOrientationPing: shellCubit.announceCurrentLocation,
              onHoldToSpeakStart: () => voiceCubit.startSession(context),
              onHoldToSpeakEnd: () =>
                  voiceCubit.stopAndExecute(context: context),
              onHoldToSpeakCancel: voiceCubit.closeSession,
              child: TwoFingerGestureDetector(
                behavior: HitTestBehavior.translucent,
                onScaleStart: (details) => _cameraController.onScaleStart(
                  details,
                  floorLevel: shellCubit.state.currentFloor,
                ),
                onScaleUpdate: (details) {
                  final isWhisper = context
                      .read<PreferencesCubit>()
                      .state
                      .spatialWhisperEnabled;

                  _cameraController.onScaleUpdate(
                    details: details,
                    state: shellCubit.state,
                    topology: topology,
                    screenSize: screenSize,
                    onWhisperDirection: shellCubit.whisperRoomScrubbing,
                    isWhisperEnabled: isWhisper,
                  );
                },
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

                        final lowerFloor =
                            currentZ.floor().clamp(minF, maxF);
                        final upperFloor =
                            currentZ.ceil().clamp(minF, maxF);

                        final activeFloor =
                            currentZ.round().clamp(minF, maxF);

                        final visibleFloors = <int>{lowerFloor, upperFloor}
                            .where(topology.hasFloor)
                            .toList()
                          ..sort((a, b) => (a == activeFloor ? 1 : 0)
                              .compareTo(b == activeFloor ? 1 : 0));

                        return Stack(
                          children: [
                            for (final floor in visibleFloors)
                              SpatialPortalTransform(
                                floor: floor,
                                currentZ: currentZ,
                                isActive: floor == activeFloor,
                                child: SpatialFloorLayout(
                                  key: ValueKey(
                                    'spatial_floor_layout_$floor',
                                  ),
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

                            // 🔮 كرة التوجيه والمصعد الفضائي
                            const SpatialNavigationOrb(),
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

/// 🔮 كرة التوجيه الفضائية التفاعلية (Spatial Gyro Orb)
class SpatialNavigationOrb extends StatefulWidget {
  const SpatialNavigationOrb({super.key});

  @override
  State<SpatialNavigationOrb> createState() => _SpatialNavigationOrbState();
}

class _SpatialNavigationOrbState extends State<SpatialNavigationOrb>
    with SingleTickerProviderStateMixin {
  Offset _dragOffset = Offset.zero;
  bool _isMenuOpen = false;
  static const double _maxDragRadius = 26.0;
  static const double _triggerThreshold = 18.0;

  @override
  Widget build(BuildContext context) {
    final shellCubit = context.watch<SpatialShellCubit>();
    final currentFloor = shellCubit.state.currentFloor;
    final colors = context.colors;

    return Positioned(
      bottom: 84,
      right: 20,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 🏢 قائمة مصعد الطوابق الثلاثة المنبثقة بحركة سلسة
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: animation,
                  alignment: Alignment.bottomRight,
                  child: child,
                ),
              );
            },
            child: _isMenuOpen
                ? _buildFloorElevatorMenu(context, currentFloor, shellCubit, colors)
                : const SizedBox.shrink(),
          ),
          if (_isMenuOpen) const SizedBox(height: 10),

          // 🔮 الكرة الفضائية
          GestureDetector(
            onTap: () {
              HapticManager.instance.selectionClick();
              SoundController.instance.play(SoundCue.navCenter);
              setState(() => _isMenuOpen = !_isMenuOpen);
            },
            onLongPress: () {
              HapticManager.instance.successNotification();
              SoundController.instance.play(SoundCue.navReturn);
              shellCubit.returnToCenter();
              if (_isMenuOpen) setState(() => _isMenuOpen = false);
            },
            onPanStart: (_) {
              if (_isMenuOpen) setState(() => _isMenuOpen = false);
            },
            onPanUpdate: (details) {
              final newOffset = _dragOffset + details.delta;
              final distance = newOffset.distance;

              if (distance <= _maxDragRadius) {
                setState(() => _dragOffset = newOffset);
              } else {
                final angle = math.atan2(newOffset.dy, newOffset.dx);
                setState(() {
                  _dragOffset = Offset(
                    math.cos(angle) * _maxDragRadius,
                    math.sin(angle) * _maxDragRadius,
                  );
                });
              }
            },
            onPanEnd: (_) {
              final distance = _dragOffset.distance;
              if (distance >= _triggerThreshold) {
                _resolveDirectionAndNavigate(shellCubit);
              }
              setState(() => _dragOffset = Offset.zero);
            },
            child: _buildOrbBody(colors, currentFloor),
          ),
        ],
      ),
    );
  }

  void _resolveDirectionAndNavigate(SpatialShellCubit cubit) {
    final dx = _dragOffset.dx;
    final dy = _dragOffset.dy;

    HapticManager.instance.selectionClick();

    if (dx.abs() > dy.abs()) {
      if (dx > 0) {
        cubit.navigateToward(SpatialDirection.east);
      } else {
        cubit.navigateToward(SpatialDirection.west);
      }
    } else {
      if (dy < 0) {
        cubit.navigateToward(SpatialDirection.north);
      } else {
        cubit.navigateToward(SpatialDirection.south);
      }
    }
  }

  Widget _buildOrbBody(ColorScheme colors, int currentFloor) {
    final hasOffset = _dragOffset != Offset.zero;

    return Container(
      width: 66,
      height: 66,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.surface.withValues(alpha: 0.78),
        border: Border.all(
          color: _isMenuOpen
              ? colors.secondary
              : (currentFloor < 0 ? colors.secondary : colors.primary.withValues(alpha: 0.8)),
          width: 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: (_isMenuOpen ? colors.secondary : colors.primary)
                .withValues(alpha: 0.28),
            blurRadius: 18,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 44,
            height: 1,
            color: colors.outline.withValues(alpha: 0.35),
          ),
          Container(
            width: 1,
            height: 44,
            color: colors.outline.withValues(alpha: 0.35),
          ),
          Positioned(
            top: 4,
            child: Icon(Icons.keyboard_arrow_up_rounded,
                size: 13, color: colors.onSurfaceVariant.withValues(alpha: 0.6)),
          ),
          Positioned(
            bottom: 4,
            child: Icon(Icons.keyboard_arrow_down_rounded,
                size: 13, color: colors.onSurfaceVariant.withValues(alpha: 0.6)),
          ),
          Positioned(
            left: 4,
            child: Icon(Icons.keyboard_arrow_left_rounded,
                size: 13, color: colors.onSurfaceVariant.withValues(alpha: 0.6)),
          ),
          Positioned(
            right: 4,
            child: Icon(Icons.keyboard_arrow_right_rounded,
                size: 13, color: colors.onSurfaceVariant.withValues(alpha: 0.6)),
          ),
          Transform.translate(
            offset: _dragOffset,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.surface,
                border: Border.all(
                  color: hasOffset
                      ? colors.secondary
                      : (currentFloor < 0 ? colors.secondary : colors.primary),
                  width: 2.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (hasOffset ? colors.secondary : colors.primary)
                        .withValues(alpha: 0.4),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  'F$currentFloor',
                  style: TextStyle(
                    color: hasOffset
                        ? colors.secondary
                        : (currentFloor < 0 ? colors.secondary : colors.primary),
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloorElevatorMenu(
    BuildContext context,
    int currentFloor,
    SpatialShellCubit cubit,
    ColorScheme colors,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outline.withValues(alpha: 0.8), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _floorItem(
            label: 'Floor 1 • Engine & Tuning',
            floor: 1,
            isSelected: currentFloor == 1,
            icon: Icons.tune_rounded,
            colors: colors,
            onTap: () {
              cubit.jumpToFloor(1);
              setState(() => _isMenuOpen = false);
            },
          ),
          const SizedBox(height: 6),
          _floorItem(
            label: 'Floor 0 • Cockpit & Operations',
            floor: 0,
            isSelected: currentFloor == 0,
            icon: Icons.dashboard_rounded,
            colors: colors,
            onTap: () {
              cubit.jumpToFloor(0);
              setState(() => _isMenuOpen = false);
            },
          ),
          const SizedBox(height: 6),
          _floorItem(
            label: 'Floor -1 • Vault & Mesh Hub',
            floor: -1,
            isSelected: currentFloor == -1,
            icon: Icons.hub_rounded,
            colors: colors,
            onTap: () {
              cubit.jumpToFloor(-1);
              setState(() => _isMenuOpen = false);
            },
          ),
        ],
      ),
    );
  }

  Widget _floorItem({
    required String label,
    required int floor,
    required bool isSelected,
    required IconData icon,
    required ColorScheme colors,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.primary.withValues(alpha: 0.16)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isSelected
              ? Border.all(color: colors.primary.withValues(alpha: 0.6))
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? colors.primary : colors.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? colors.primary : colors.onSurface,
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}