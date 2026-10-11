// lib/core/topology/spatial_topology.dart
import 'package:beacon_os/agenda/agenda.dart';
import 'package:beacon_os/cockpit/cockpit.dart';
import 'package:beacon_os/comms/comms.dart';
import 'package:beacon_os/core/topology/spatial_module.dart';
import 'package:beacon_os/focus/focus.dart';
import 'package:beacon_os/spatial_shell/spatial_shell.dart';
import 'package:beacon_os/vision/vision.dart';

/// خريطة الطوبولوجيا المكانية لنظام التشغيل (Spatial OS Grid)
class SpatialTopology {
  SpatialTopology();

  /// شبكة الطوابق والغرف: Floor -> (Direction -> Module)
  final Map<int, Map<SpatialDirection, SpatialModule>> _grid = {};

  /// الباني الافتراضي الموحد الذي يسجل موديولات النظام الخمسة عبر الطابقين 0 و 1
  factory SpatialTopology.defaultTopology() {
    final topology = SpatialTopology();

    // 🏠 الطابق الأرضي (Floor 0): قمرة اليوم والغرف الأساسية
    topology.register(
      floor: 0,
      direction: SpatialDirection.center,
      module: CockpitModule.instance,
    );
    topology.register(
      floor: 0,
      direction: SpatialDirection.north,
      module: FocusModule.instance,
    );
    topology.register(
      floor: 0,
      direction: SpatialDirection.south,
      module: CommsModule.instance,
    );
    topology.register(
      floor: 0,
      direction: SpatialDirection.east,
      module: VisionModule.instance,
    );
    topology.register(
      floor: 0,
      direction: SpatialDirection.west,
      module: AgendaModule.instance,
    );

    // ⚙️ الطابق الأول (Floor 1): إعدادات ومحركات الغرف
    topology.register(
      floor: 1,
      direction: SpatialDirection.center,
      module: CockpitModule.instance,
    );
    topology.register(
      floor: 1,
      direction: SpatialDirection.north,
      module: FocusModule.instance,
    );
    topology.register(
      floor: 1,
      direction: SpatialDirection.south,
      module: CommsModule.instance,
    );
    topology.register(
      floor: 1,
      direction: SpatialDirection.east,
      module: VisionModule.instance,
    );
    topology.register(
      floor: 1,
      direction: SpatialDirection.west,
      module: AgendaModule.instance,
    );

    return topology;
  }

  void register({
    required int floor,
    required SpatialDirection direction,
    required SpatialModule module,
  }) {
    _grid.putIfAbsent(floor, () => {});
    _grid[floor]![direction] = module;
  }

  SpatialModule? moduleAt(int floor, SpatialDirection direction) {
    return _grid[floor]?[direction];
  }

  Map<SpatialDirection, SpatialModule> roomsOnFloor(int floor) {
    return _grid[floor] ?? const {};
  }

  List<int> get availableFloors {
    final floors = _grid.keys.toList()..sort();
    return floors;
  }

  int get minFloor => availableFloors.isEmpty ? 0 : availableFloors.first;
  int get maxFloor => availableFloors.isEmpty ? 0 : availableFloors.last;

  bool hasFloor(int floor) => _grid.containsKey(floor);
  bool canAscendFrom(int floor) => floor < maxFloor && hasFloor(floor + 1);
  bool canDescendFrom(int floor) => floor > minFloor && hasFloor(floor - 1);

  SpatialDirection? directionOf(int floor, String moduleId) {
    final floorRooms = _grid[floor];
    if (floorRooms == null) return null;

    for (final entry in floorRooms.entries) {
      if (entry.value.id == moduleId) {
        return entry.key;
      }
    }
    return null;
  }

  List<SpatialModule> get allModules {
    final modules = <String, SpatialModule>{};
    for (final floorMap in _grid.values) {
      for (final module in floorMap.values) {
        modules[module.id] = module;
      }
    }
    return modules.values.toList();
  }
}