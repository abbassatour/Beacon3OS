// lib/focus/focus_module.dart
import 'package:beacon_os/core/audio/sound_cue.dart';
import 'package:beacon_os/core/topology/topology.dart';
import 'package:beacon_os/core/voice_bus/voice_bus.dart';
import 'package:beacon_os/focus/intents/focus_intents.dart';
import 'package:beacon_os/focus/view/focus_floor_0_view.dart';
import 'package:beacon_os/focus/view/focus_floor_1_view.dart';
import 'package:flutter/material.dart';

class FocusModule extends SpatialModule {
  FocusModule._();
  static final FocusModule instance = FocusModule._();

  @override
  String get id => 'focus';

  @override
  String get title => 'FOCUS & ALARMS';

  @override
  String get shortTitle => 'Focus';

  @override
  IconData get icon => Icons.hourglass_top_rounded;

  @override
  SoundCue get sonicSignature => SoundCue.navNorth;

  @override
  SpatialCoordinate get defaultCoordinate =>
      const SpatialCoordinate(x: 0, y: 1, floor: 0);

  @override
  bool supportsFloor(int floorLevel) => floorLevel == 0 || floorLevel == 1;

  @override
  String getFloorTitle(int floorLevel) {
    if (floorLevel == 1) return 'FOCUS & ALARMS TUNING';
    return title;
  }

  @override
  List<VoiceIntentHandler> get voiceIntents => [
        SetAlarmIntentHandler(),
        ToggleAlarmIntentHandler(),
        DeleteAlarmIntentHandler(),
      ];

  @override
  Widget buildFloorView(BuildContext context, int floorLevel) {
    if (floorLevel == 1) {
      return const FocusFloor1View(
        key: ValueKey('focus_floor_1_view'),
      );
    }
    // 🌟 الحل الجذري: إرجاع الواجهة المستقلة التي تحقن FocusCubit تلقائياً
    return const FocusFloor0StandaloneView(
      key: ValueKey('focus_floor_0_standalone_view'),
    );
  }
}

typedef FocusAlarmsModule = FocusModule;