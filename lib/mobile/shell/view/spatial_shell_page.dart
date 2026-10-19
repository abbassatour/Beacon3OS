// lib/mobile/shell/view/spatial_shell_page.dart
import 'dart:async';

import 'package:beacon_os/core/haptics/haptic_manager.dart';
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/core/topology/topology.dart';
import 'package:beacon_os/core/voice_bus/voice_bus.dart';
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

  @override
  void initState() {
    super.initState();
    _cameraController = SpatialCameraController(vsync: this);

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
        // 🔒 حماية الكاميرا: عدم مقاطعة النابض إذا كان المستخدم يسحب أو النابض ينزلق
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
            onCornerSwipe: voiceCubit.startSession,
            child: TactileMultiTouchDetector(
              // 🚨 استغاثة الطوارئ: 3 نقرات سريعة
              onTripleTapSos: () => _triggerTripleTapSos(context),
              // 🧭 إعلان الموقع للكفيف: نقرتان بإصبعين
              onOrientationPing: shellCubit.announceCurrentLocation,
              // 🎙️ المساعد الصوتي الحسي: ضغط مطول بإصبع واحد
              onHoldToSpeakStart: voiceCubit.startSession,
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

                        // 📐 ترتيب ذكي: الطابق النشط يُرسم دوماً في قمة الـ Stack لمنع الحجب
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

                            // 👈 أضف هذا السطر هنا:
                            const MouseSpatialController(),
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


/// 🛠️ تحكم مؤقت بالفأرة لاختبار التنقل على الحاسوب والمحاكي
class MouseSpatialController extends StatelessWidget {
  const MouseSpatialController({super.key});

  @override
  Widget build(BuildContext context) {
    final shellCubit = context.read<SpatialShellCubit>();
    final colors = Theme.of(context).colorScheme;

    return Positioned(
      bottom: 90,
      right: 20,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colors.primary, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // زر الصعود للطابق العلوي
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _btn(
                    icon: Icons.keyboard_double_arrow_up_rounded,
                    tooltip: 'Ascend Floor (Z+)',
                    color: colors.secondary,
                    onTap: shellCubit.ascend,
                  ),
                  const SizedBox(width: 4),
                  _btn(
                    icon: Icons.keyboard_double_arrow_down_rounded,
                    tooltip: 'Descend Floor (Z-)',
                    color: colors.secondary,
                    onTap: shellCubit.descend,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // سهم الشمال (Focus / Perimeter)
              _btn(
                icon: Icons.arrow_upward_rounded,
                tooltip: 'North (Focus / Alarms)',
                color: colors.primary,
                onTap: () => shellCubit.navigateToward(SpatialDirection.north),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // سهم الغرب (Agenda)
                  _btn(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'West (Agenda & Tasks)',
                    color: colors.primary,
                    onTap: () => shellCubit.navigateToward(SpatialDirection.west),
                  ),
                  const SizedBox(width: 4),
                  // زر المركز (Cockpit)
                  _btn(
                    icon: Icons.home_rounded,
                    tooltip: 'Origin (Cockpit)',
                    color: colors.onSurface,
                    onTap: shellCubit.returnToCenter,
                  ),
                  const SizedBox(width: 4),
                  // سهم الشرق (Vision)
                  _btn(
                    icon: Icons.arrow_forward_rounded,
                    tooltip: 'East (AI Vision)',
                    color: colors.primary,
                    onTap: () => shellCubit.navigateToward(SpatialDirection.east),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // سهم الجنوب (Communications)
              _btn(
                icon: Icons.arrow_downward_rounded,
                tooltip: 'South (Communications)',
                color: colors.primary,
                onTap: () => shellCubit.navigateToward(SpatialDirection.south),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _btn({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onTap,
  }) {
    return IconButton(
      icon: Icon(icon, color: color, size: 22),
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      onPressed: onTap,
    );
  }
}