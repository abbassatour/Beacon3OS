// lib/mobile/comms/comms_module.dart
import 'package:beacon_os/core/audio/sound_cue.dart';
import 'package:beacon_os/core/topology/topology.dart';
import 'package:beacon_os/core/voice_bus/voice_bus.dart';
import 'package:beacon_os/mobile/comms/intents/comms_intents.dart'; // 👈 مصحح
import 'package:beacon_os/mobile/comms/view/comms_floor_0_view.dart'; // 👈 مصحح
import 'package:beacon_os/mobile/comms/view/comms_floor_1_view.dart'; // 👈 مصحح
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';

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
  SpatialCoordinate get defaultCoordinate =>
      const SpatialCoordinate(x: 0, y: -1, floor: 0);

  @override
  bool supportsFloor(int floorLevel) => floorLevel == 0 || floorLevel == 1;

  @override
  String getFloorTitle(int floorLevel) {
    if (floorLevel == 1) return 'SAFETY & SOS RADAR PREFERENCES';
    return title;
  }

  @override
  Future<Map<String, dynamic>?> getVoiceContext(BuildContext context) async {
    try {
      final commsRepo = context.read<CommsRepository>();
      final emergency = await commsRepo.getEmergencyContacts();
      final isLinked = await commsRepo.isDeviceLinked();

      return {
        'emergency_contacts_count': emergency.length,
        'primary_emergency_contact':
            emergency.isNotEmpty ? emergency.first.name : null,
        'is_device_linked': isLinked,
      };
    } catch (_) {
      return null;
    }
  }

  @override
  List<VoiceIntentHandler> get voiceIntents => [
        EmergencySosIntentHandler(),
        CallContactIntentHandler(),
        SaveContactIntentHandler(),
        DeleteContactIntentHandler(),
        SyncContactsIntentHandler(),
        PairDeviceIntentHandler(),
      ];

  @override
  Widget buildFloorView(BuildContext context, int floorLevel) {
    if (floorLevel == 1) {
      return const CommsFloor1View(
        key: ValueKey('comms_floor_1_view'),
      );
    }
    return const CommsFloor0StandaloneView(
      key: ValueKey('comms_floor_0_standalone_view'),
    );
  }
}
