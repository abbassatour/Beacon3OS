// lib/app/default_topology.dart
import 'package:beacon_os/core/topology/topology.dart';
import 'package:beacon_os/mobile/agenda/agenda.dart';
import 'package:beacon_os/mobile/cockpit/cockpit.dart';
import 'package:beacon_os/mobile/comms/comms.dart';
import 'package:beacon_os/mobile/focus/focus.dart';
import 'package:beacon_os/mobile/vision/vision.dart';

/// باني الطوبولوجيا الافتراضية لمنظومة BeaconOS
SpatialTopology createDefaultSpatialTopology() {
  final registry = SpatialModuleRegistry.instance;

  // 🌟 تسجيل الموديولات الأساسية الخمسة في السجل المركزي
  registry.registerAll([
    CockpitModule.instance,
    FocusModule.instance,
    CommsModule.instance,
    VisionModule.instance,
    AgendaModule.instance,
  ]);

  final topology = SpatialTopology();

  // 🏠 الطابق الأرضي (Floor 0): قمرة اليوم والغرف الأساسية
  topology.registerCoordinate(
    coordinate: const SpatialCoordinate(x: 0, y: 0, floor: 0),
    module: CockpitModule.instance,
    title: 'Today Cockpit',
    notify: false,
  );
  topology.registerCoordinate(
    coordinate: const SpatialCoordinate(x: 0, y: 1, floor: 0), // North
    module: FocusModule.instance,
    title: 'Focus & Alarms',
    notify: false,
  );
  topology.registerCoordinate(
    coordinate: const SpatialCoordinate(x: 0, y: -1, floor: 0), // South
    module: CommsModule.instance,
    title: 'Communications',
    notify: false,
  );
  topology.registerCoordinate(
    coordinate: const SpatialCoordinate(x: 1, y: 0, floor: 0), // East
    module: VisionModule.instance,
    title: 'AI Vision Studio',
    notify: false,
  );
  topology.registerCoordinate(
    coordinate: const SpatialCoordinate(x: -1, y: 0, floor: 0), // West
    module: AgendaModule.instance,
    title: 'Agenda & Tasks',
    notify: false,
  );

  // ⚙️ الطابق الأول (Floor 1): إعدادات ومحركات الغرف
  topology.registerCoordinate(
    coordinate: const SpatialCoordinate(x: 0, y: 0, floor: 1),
    module: CockpitModule.instance,
    title: 'Core Engine & Preferences',
    notify: false,
  );
  topology.registerCoordinate(
    coordinate: const SpatialCoordinate(x: 0, y: 1, floor: 1),
    module: FocusModule.instance,
    title: 'Focus & Alarm Tuning',
    notify: false,
  );
  topology.registerCoordinate(
    coordinate: const SpatialCoordinate(x: 0, y: -1, floor: 1),
    module: CommsModule.instance,
    title: 'Safety & SOS Preferences',
    notify: false,
  );
  topology.registerCoordinate(
    coordinate: const SpatialCoordinate(x: 1, y: 0, floor: 1),
    module: VisionModule.instance,
    title: 'AI Vision Tuning',
    notify: false,
  );
  topology.registerCoordinate(
    coordinate: const SpatialCoordinate(x: -1, y: 0, floor: 1),
    module: AgendaModule.instance,
    title: 'Agenda Preferences',
    notify: false,
  );

  return topology;
}