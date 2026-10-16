// lib/mobile/perimeter/perimeter_module.dart
import 'package:beacon_os/core/audio/sound_cue.dart';
import 'package:beacon_os/core/topology/topology.dart';
import 'package:beacon_os/core/voice_bus/voice_bus.dart';
import 'package:beacon_os/mobile/perimeter/cubit/perimeter_cubit.dart';
import 'package:beacon_os/mobile/perimeter/intents/perimeter_intents.dart';
import 'package:beacon_os/mobile/perimeter/view/perimeter_floor_0_view.dart';
import 'package:beacon_os/mobile/perimeter/view/perimeter_floor_1_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';

class PerimeterModule extends SpatialModule {
  PerimeterModule._();
  static final PerimeterModule instance = PerimeterModule._();

  @override
  String get id => 'perimeter';

  @override
  String get title => 'SMART PERIMETER & RING';

  @override
  String get shortTitle => 'Perimeter';

  @override
  IconData get icon => Icons.camera_outdoor_rounded;

  @override
  SoundCue get sonicSignature => SoundCue.navMove;

  @override
  SpatialCoordinate get defaultCoordinate =>
      const SpatialCoordinate(x: 0, y: 2, floor: 0);

  @override
  bool supportsFloor(int floorLevel) => floorLevel == 0 || floorLevel == 1;

  @override
  String getFloorTitle(int floorLevel) {
    if (floorLevel == 1) return 'PERIMETER CAMERA TUNING';
    return title;
  }

  @override
  Future<Map<String, dynamic>?> getVoiceContext(BuildContext context) async {
    try {
      final ringRepo = context.read<LauncherRepository>().ring;
      final devices = await ringRepo.getAllDevices();
      return {
        'ring_cameras_count': devices.length,
        'camera_locations': devices.map((d) => d.location).toList(),
      };
    } catch (_) {
      return null;
    }
  }

  @override
  List<VoiceIntentHandler> get voiceIntents => [
        InspectCameraIntentHandler(),
        AnswerDoorbellIntentHandler(),
        SimulateRingScenarioIntentHandler(),
      ];

  @override
  Widget buildFloorView(BuildContext context, int floorLevel) {
    if (floorLevel == 1) {
      return BlocProvider(
        create: (context) => PerimeterCubit(
          ringRepository: context.read<LauncherRepository>().ring,
          assistantRepository: context.read<AssistantRepository>(),
        ),
        child: const PerimeterFloor1View(
          key: ValueKey('perimeter_floor_1_view'),
        ),
      );
    }
    return const PerimeterFloor0StandaloneView(
      key: ValueKey('perimeter_floor_0_standalone_view'),
    );
  }
}