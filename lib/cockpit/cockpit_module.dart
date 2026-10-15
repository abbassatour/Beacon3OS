// lib/cockpit/cockpit_module.dart
import 'package:beacon_os/cockpit/intents/cockpit_intents.dart';
import 'package:beacon_os/cockpit/view/cockpit_floor_0_view.dart';
import 'package:beacon_os/cockpit/view/cockpit_floor_1_view.dart';
import 'package:beacon_os/core/audio/sound_cue.dart';
import 'package:beacon_os/core/topology/topology.dart';
import 'package:beacon_os/core/voice_bus/voice_bus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';

class CockpitModule extends SpatialModule {
  CockpitModule._();
  static final CockpitModule instance = CockpitModule._();

  @override
  String get id => 'cockpit';

  @override
  String get title => 'TODAY COCKPIT';

  @override
  String get shortTitle => 'Cockpit';

  @override
  IconData get icon => Icons.dashboard_rounded;

  @override
  SoundCue get sonicSignature => SoundCue.navCenter;

  @override
  SpatialCoordinate get defaultCoordinate =>
      const SpatialCoordinate(x: 0, y: 0, floor: 0);

  @override
  bool supportsFloor(int floorLevel) => floorLevel == 0 || floorLevel == 1;

  @override
  String getFloorTitle(int floorLevel) {
    if (floorLevel == 1) return 'CORE ENGINE & PREFERENCES';
    return title;
  }

  @override
  Future<Map<String, dynamic>?> getVoiceContext(BuildContext context) async {
    try {
      final hw = context.read<SystemHardwareRepository>();
      final battery = await hw.getBatteryStatus();
      return {'battery_status': battery};
    } catch (_) {
      return null;
    }
  }

  @override
  List<VoiceIntentHandler> get voiceIntents => [
        BatteryStatusIntentHandler(),
        FlashlightIntentHandler(),
        LockScreenIntentHandler(),
        TimeDateIntentHandler(),
        DailyBriefingIntentHandler(),
        OpenAppIntentHandler(),
        UpdateSettingsIntentHandler(),
      ];

  @override
  Widget buildFloorView(BuildContext context, int floorLevel) {
    if (floorLevel == 1) {
      return const CockpitFloor1View(
        key: ValueKey('cockpit_floor_1_view'),
      );
    }
    return const CockpitFloor0StandaloneView(
      key: ValueKey('cockpit_floor_0_standalone_view'),
    );
  }
}