// lib/mobile/focus/focus_module.dart
import 'package:beacon_os/core/audio/sound_cue.dart';
import 'package:beacon_os/core/topology/topology.dart';
import 'package:beacon_os/core/voice_bus/voice_bus.dart';
import 'package:beacon_os/mobile/focus/intents/focus_intents.dart';
import 'package:beacon_os/mobile/focus/view/focus_floor_0_view.dart';
import 'package:beacon_os/mobile/focus/view/focus_floor_1_view.dart';
import 'package:beacon_os/mobile/focus/view/focus_floor_neg1_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';

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
  bool get isVerticallyScrollable => true;

  @override
  bool supportsFloor(int floorLevel) =>
      floorLevel == -1 || floorLevel == 0 || floorLevel == 1;

  @override
  String getFloorTitle(int floorLevel) {
    if (floorLevel == 1) return 'FOCUS & ALARMS TUNING';
    if (floorLevel == -1) return 'FOCUS ANALYTICS ARCHIVE';
    return title;
  }

  @override
  Future<Map<String, dynamic>?> getVoiceContext(BuildContext context) async {
    try {
      final focusRepo = context.read<FocusAlarmsRepository>();
      final alarms = await focusRepo.watchAlarms().first;
      final activeAlarms = alarms.where((a) => a.isActive).toList();
      return {
        'active_alarms_count': activeAlarms.length,
        'next_alarm': activeAlarms.isNotEmpty
            ? '${activeAlarms.first.hour}:${activeAlarms.first.minute.toString().padLeft(2, '0')}'
            : null,
      };
    } catch (_) {
      return null;
    }
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
    if (floorLevel == -1) {
      return const FocusFloorNeg1View(
        key: ValueKey('focus_floor_neg1_view'),
      );
    }
    // ⚡ العرض المباشر مستفيداً من FocusCubit المرفوع بأعلى الـ Shell دون إعادة بناء
    return const FocusFloor0View(
      key: ValueKey('focus_floor_0_view'),
    );
  }
}