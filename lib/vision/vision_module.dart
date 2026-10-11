// lib/vision/vision_module.dart
import 'package:beacon_os/core/audio/sound_cue.dart';
import 'package:beacon_os/core/topology/topology.dart';
import 'package:beacon_os/core/voice_bus/voice_bus.dart';
import 'package:beacon_os/vision/intents/vision_intents.dart';
import 'package:beacon_os/vision/view/vision_floor_0_view.dart';
import 'package:beacon_os/vision/view/vision_floor_1_view.dart';
import 'package:flutter/material.dart';

class VisionModule extends SpatialModule {
  VisionModule._();
  static final VisionModule instance = VisionModule._();

  @override
  String get id => 'vision';

  @override
  String get title => 'AI VISION';

  @override
  String get shortTitle => 'Vision';

  @override
  IconData get icon => Icons.visibility_rounded;

  @override
  SoundCue get sonicSignature => SoundCue.navEast;

  @override
  bool supportsFloor(int floorLevel) => floorLevel == 0 || floorLevel == 1;

  @override
  String getFloorTitle(int floorLevel) {
    if (floorLevel == 1) return 'AI VISION TUNING';
    return title;
  }

  @override
  List<VoiceIntentHandler> get voiceIntents => [
        DescribeSceneIntentHandler(),
        ReadTextVisionIntentHandler(),
        IdentifyCurrencyIntentHandler(),
      ];

  @override
  Widget buildFloorView(BuildContext context, int floorLevel) {
    if (floorLevel == 1) {
      return const VisionFloor1View(
        key: ValueKey('vision_floor_1_view'),
      );
    }
    return const VisionFloor0View(
      key: ValueKey('vision_floor_0_view'),
    );
  }
}

// 🛡️ توافق عكسي مع الكود القديم
typedef SpatialVisionModule = VisionModule;