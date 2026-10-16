// lib/mobile/vision/vision_module.dart
import 'package:beacon_os/core/audio/sound_cue.dart';
import 'package:beacon_os/core/topology/topology.dart';
import 'package:beacon_os/core/voice_bus/voice_bus.dart';
import 'package:beacon_os/mobile/vision/intents/vision_intents.dart'; // 👈 مصحح
import 'package:beacon_os/mobile/vision/view/vision_floor_0_view.dart'; // 👈 مصحح
import 'package:beacon_os/mobile/vision/view/vision_floor_1_view.dart'; // 👈 مصحح
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';

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
  SpatialCoordinate get defaultCoordinate =>
      const SpatialCoordinate(x: 1, y: 0, floor: 0);

  @override
  bool supportsFloor(int floorLevel) => floorLevel == 0 || floorLevel == 1;

  @override
  String getFloorTitle(int floorLevel) {
    if (floorLevel == 1) return 'AI VISION TUNING';
    return title;
  }

  @override
  Future<Map<String, dynamic>?> getVoiceContext(BuildContext context) async {
    try {
      final settingsRepo = context.read<SettingsRepository>();
      final settings = await settingsRepo.getSettings();
      return {
        'vision_inspection_detail': settings.visionInspectionDetail,
        'preferred_currency': settings.preferredCurrency,
        'auto_flashlight_in_dark': settings.autoFlashlightInDark,
      };
    } catch (_) {
      return null;
    }
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
    return const VisionFloor0StandaloneView(
      key: ValueKey('vision_floor_0_standalone_view'),
    );
  }
}
