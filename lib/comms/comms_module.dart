// lib/comms/comms_module.dart
import 'package:beacon_os/comms/intents/comms_intents.dart';
import 'package:beacon_os/comms/view/comms_floor_0_view.dart';
import 'package:beacon_os/comms/view/comms_floor_1_view.dart';
import 'package:beacon_os/core/audio/sound_cue.dart';
import 'package:beacon_os/core/topology/topology.dart';
import 'package:beacon_os/core/voice_bus/voice_bus.dart';
import 'package:flutter/material.dart';

class CommsModule extends SpatialModule {
  CommsModule._();
  static final CommsModule instance = CommsModule._();

  @override
  String get id => 'comms';

  @override
  String get title => 'COMMUNICATIONS';

  @override
  String get shortTitle => 'Comms';

  @override
  IconData get icon => Icons.chat_bubble_outline_rounded;

  @override
  SoundCue get sonicSignature => SoundCue.navSouth;

  @override
  bool supportsFloor(int floorLevel) => floorLevel == 0 || floorLevel == 1;

  @override
  String getFloorTitle(int floorLevel) {
    if (floorLevel == 1) return 'SAFETY & SOS RADAR PREFERENCES';
    return title;
  }

  @override
  List<VoiceIntentHandler> get voiceIntents => [
        EmergencySosIntentHandler(),
        CallContactIntentHandler(),
        SaveContactIntentHandler(),
        DeleteContactIntentHandler(),
        SyncContactsIntentHandler(),
      ];

  @override
  Widget buildFloorView(BuildContext context, int floorLevel) {
    if (floorLevel == 1) {
      return const CommsFloor1View(
        key: ValueKey('comms_floor_1_view'),
      );
    }
    return const CommsFloor0View(
      key: ValueKey('comms_floor_0_view'),
    );
  }
}

// 🛡️ توافق عكسي مع الكود القديم
typedef CommunicationsModule = CommsModule;