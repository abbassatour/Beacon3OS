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
    return const FocusFloor0View(
      key: ValueKey('focus_floor_0_view'),
    );
  }
}

// 🛡️ اسم توافقي لموديول التركيز
typedef FocusAlarmsModule = FocusModule;