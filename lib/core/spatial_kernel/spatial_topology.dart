// lib/core/spatial_kernel/spatial_topology.dart
import 'package:beacon_os/agenda/agenda_module.dart';
import 'package:beacon_os/cockpit_dashboard/cockpit_module.dart';
import 'package:beacon_os/communications/communications_module.dart';
import 'package:beacon_os/core/spatial_kernel/spatial_module.dart';
import 'package:beacon_os/focus_alarms/focus_alarms_module.dart';
import 'package:beacon_os/spatial_compass/cubit/spatial_compass_state.dart';
import 'package:beacon_os/spatial_vision/spatial_vision_module.dart';

/// خريطة الطوبولوجيا المكانية لنظام التشغيل (Spatial OS Grid)
class SpatialTopology {
  SpatialTopology();

  /// شبكة الطوابق والغرف: Floor -> (Direction -> Module)
  final Map<int, Map<CompassDirection, SpatialModule>> _grid = {};

  /// الباني الافتراضي الموحد الذي يسجل موديولات النظام الخمسة عبر الطابقين 0 و 1
  factory SpatialTopology.defaultTopology() {
    final topology = SpatialTopology();

    // 🏠 الطابق الأرضي (Floor 0): قمرة اليوم والغرف الأساسية
    topology.register(
      floor: 0,
      direction: CompassDirection.center,
      module: CockpitModule.instance,
    );
    topology.register(
      floor: 0,
      direction: CompassDirection.north,
      module: FocusAlarmsModule.instance,
    );
    topology.register(
      floor: 0,
      direction: CompassDirection.south,
      module: CommunicationsModule.instance,
    );
    topology.register(
      floor: 0,
      direction: CompassDirection.east,
      module: SpatialVisionModule.instance,
    );
    topology.register(
      floor: 0,
      direction: CompassDirection.west,
      module: AgendaModule.instance,
    );

    // ⚙️ الطابق الثاني (Floor 1): إعدادات ومحركات الغرف
    topology.register(
      floor: 1,
      direction: CompassDirection.center,
      module: CockpitModule.instance,
    );
    topology.register(
      floor: 1,
      direction: CompassDirection.north,
      module: FocusAlarmsModule.instance,
    );
    topology.register(
      floor: 1,
      direction: CompassDirection.south,
      module: CommunicationsModule.instance,
    );
    topology.register(
      floor: 1,
      direction: CompassDirection.east,
      module: SpatialVisionModule.instance,
    );
    topology.register(
      floor: 1,
      direction: CompassDirection.west,
      module: AgendaModule.instance,
    );

    return topology;
  }

  /// تسجيل موديول في طابق واتجاه محدد
  void register({
    required int floor,
    required CompassDirection direction,
    required SpatialModule module,
  }) {
    _grid.putIfAbsent(floor, () => {});
    _grid[floor]![direction] = module;
  }

  /// استرجاع الموديول الموجود في إحداثيات محددة
  SpatialModule? moduleAt(int floor, CompassDirection direction) {
    return _grid[floor]?[direction];
  }

  /// استرجاع جميع الموديولات المسجلة في طابق معين
  Map<CompassDirection, SpatialModule> roomsOnFloor(int floor) {
    return _grid[floor] ?? const {};
  }

  /// قائمة الطوابق المسجلة مرتبة تصاعدياً (مثل: [0, 1] أو [-1, 0, 1, 2])
  List<int> get availableFloors {
    final floors = _grid.keys.toList()..sort();
    return floors;
  }

  /// أدنى رقم طابق مسجل في النظام (Floor Boundary Minimum)
  int get minFloor => availableFloors.isEmpty ? 0 : availableFloors.first;

  /// أعلى رقم طابق مسجل في النظام (Floor Boundary Maximum)
  int get maxFloor => availableFloors.isEmpty ? 0 : availableFloors.last;

  /// فحص هل الطابق المعطى مسجل بالفعل في خريطة النظام
  bool hasFloor(int floor) => _grid.containsKey(floor);

  /// فحص إمكانية صعود المصعد طابقاً إضافياً من الطابق الحالي
  bool canAscendFrom(int floor) => floor < maxFloor && hasFloor(floor + 1);

  /// فحص إمكانية هبوط المصعد طابقاً للأسفل من الطابق الحالي
  bool canDescendFrom(int floor) => floor > minFloor && hasFloor(floor - 1);

  /// استرجاع اتجاه موديول معين داخل طابق
  CompassDirection? directionOf(int floor, String moduleId) {
    final floorRooms = _grid[floor];
    if (floorRooms == null) return null;

    for (final entry in floorRooms.entries) {
      if (entry.value.id == moduleId) {
        return entry.key;
      }
    }
    return null;
  }

  /// استرجاع قائمة بجميع الموديولات الفريدة المسجلة عبر النظام
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