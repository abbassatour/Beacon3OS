// lib/app/default_topology.dart
import 'package:beacon_os/core/topology/topology.dart';
import 'package:beacon_os/mobile/agenda/agenda.dart';
import 'package:beacon_os/mobile/cockpit/cockpit.dart';
import 'package:beacon_os/mobile/comms/comms.dart';
import 'package:beacon_os/mobile/focus/focus.dart';
import 'package:beacon_os/mobile/perimeter/perimeter.dart';
import 'package:beacon_os/mobile/vision/vision.dart';

/// باني الطوبولوجيا الافتراضية لمنظومة BeaconOS
SpatialTopology createDefaultSpatialTopology() {
  final registry = SpatialModuleRegistry.instance;

  // 🌟 تسجيل الموديولات الأساسية الستة في السجل المركزي
  registry.registerAll([
    CockpitModule.instance,
    FocusModule.instance,
    PerimeterModule.instance,
    CommsModule.instance,
    VisionModule.instance,
    AgendaModule.instance,
  ]);

  final topology = SpatialTopology();

  // ===========================================================================
  // 🏠 الطابق الأرضي (Floor 0: Present & Operations)
  // ===========================================================================
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
    coordinate: const SpatialCoordinate(x: 0, y: 2, floor: 0), // Far North
    module: PerimeterModule.instance,
    title: 'Smart Perimeter & Ring',
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

  // ===========================================================================
  // ⚙️ الطابق الأول (Floor 1: Future & Tuning)
  // ===========================================================================
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
    coordinate: const SpatialCoordinate(x: 0, y: 2, floor: 1),
    module: PerimeterModule.instance,
    title: 'Perimeter Camera Tuning',
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

  // ===========================================================================
  // 🏛️ الطابق السفلي (Floor -1: Past, Vault & Infrastructure)
  // ===========================================================================
  topology.registerCoordinate(
    coordinate: const SpatialCoordinate(x: 0, y: 0, floor: -1),
    module: CockpitModule.instance,
    title: 'Mesh Hub & Connected Devices',
    notify: false,
  );
  topology.registerCoordinate(
    coordinate: const SpatialCoordinate(x: 0, y: 1, floor: -1),
    module: FocusModule.instance,
    title: 'Focus Analytics Archive',
    notify: false,
  );
  topology.registerCoordinate(
    coordinate: const SpatialCoordinate(x: 0, y: 2, floor: -1),
    module: PerimeterModule.instance,
    title: 'Perimeter Activity Archive',
    notify: false,
  );
  topology.registerCoordinate(
    coordinate: const SpatialCoordinate(x: 0, y: -1, floor: -1),
    module: CommsModule.instance,
    title: 'Arbitrum Sepolia SOS Ledger',
    notify: false,
  );
  topology.registerCoordinate(
    coordinate: const SpatialCoordinate(x: 1, y: 0, floor: -1),
    module: VisionModule.instance,
    title: 'Vision & OCR Archive',
    notify: false,
  );
  topology.registerCoordinate(
    coordinate: const SpatialCoordinate(x: -1, y: 0, floor: -1),
    module: AgendaModule.instance,
    title: 'Archived Tasks & Notes',
    notify: false,
  );

  return topology;
}