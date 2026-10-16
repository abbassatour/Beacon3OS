// lib/mobile/agenda/agenda_module.dart
import 'package:beacon_os/core/audio/sound_cue.dart';
import 'package:beacon_os/core/topology/topology.dart';
import 'package:beacon_os/core/voice_bus/voice_bus.dart';
import 'package:beacon_os/mobile/agenda/intents/agenda_intents.dart'; // 👈 مصحح
import 'package:beacon_os/mobile/agenda/view/agenda_floor_0_view.dart'; // 👈 مصحح
import 'package:beacon_os/mobile/agenda/view/agenda_floor_1_view.dart'; // 👈 مصحح
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';

class AgendaModule extends SpatialModule {
  AgendaModule._();
  static final AgendaModule instance = AgendaModule._();

  @override
  String get id => 'agenda';

  @override
  String get title => 'AGENDA & TASKS';

  @override
  String get shortTitle => 'Agenda';

  @override
  IconData get icon => Icons.calendar_today_rounded;

  @override
  SoundCue get sonicSignature => SoundCue.navWest;

  @override
  SpatialCoordinate get defaultCoordinate =>
      const SpatialCoordinate(x: -1, y: 0, floor: 0);

  @override
  bool supportsFloor(int floorLevel) => floorLevel == 0 || floorLevel == 1;

  @override
  String getFloorTitle(int floorLevel) {
    if (floorLevel == 1) return 'AGENDA PREFERENCES';
    return title;
  }

  @override
  Future<Map<String, dynamic>?> getVoiceContext(BuildContext context) async {
    try {
      final tasksRepo = context.read<TaskAgendaRepository>();
      final pending = await tasksRepo.getPendingTasks();
      return {
        'pending_tasks_count': pending.length,
        'top_pending_task': pending.isNotEmpty ? pending.first.title : null,
      };
    } catch (_) {
      return null;
    }
  }

  @override
  List<VoiceIntentHandler> get voiceIntents => [
        ReadTasksIntentHandler(),
        SaveTaskIntentHandler(),
        SaveMemoIntentHandler(),
        CompleteTaskIntentHandler(),
        DeleteTaskIntentHandler(),
        UpdateTaskIntentHandler(),
        DeleteMemoIntentHandler(),
      ];

  @override
  Widget buildFloorView(BuildContext context, int floorLevel) {
    if (floorLevel == 1) {
      return const AgendaFloor1View(
        key: ValueKey('agenda_floor_1_view'),
      );
    }
    return const AgendaFloor0StandaloneView(
      key: ValueKey('agenda_floor_0_standalone_view'),
    );
  }
}