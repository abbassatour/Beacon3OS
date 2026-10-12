// lib/core/topology/spatial_topology.dart
import 'dart:math' as math;
import 'package:beacon_os/agenda/agenda.dart';
import 'package:beacon_os/cockpit/cockpit.dart';
import 'package:beacon_os/comms/comms.dart';
import 'package:beacon_os/core/topology/spatial_coordinate.dart';
import 'package:beacon_os/core/topology/spatial_module.dart';
import 'package:beacon_os/focus/focus.dart';
import 'package:beacon_os/spatial_shell/spatial_shell.dart';
import 'package:beacon_os/vision/vision.dart';

/// خريطة الطوبولوجيا المكانية الديناميكية لنظام التشغيل (Spatial OS Coordinate Grid)
class SpatialTopology {
  SpatialTopology();

  /// شبكة الإحداثيات ثلاثية الأبعاد: SpatialCoordinate -> SpatialModule
  final Map<SpatialCoordinate, SpatialModule> _coordinateGrid = {};

  /// الباني الافتراضي الموحد الذي يسجل موديولات النظام الخمسة عبر الطوابق بإحداثياتها
  factory SpatialTopology.defaultTopology() {
    final topology = SpatialTopology();

    // 🏠 الطابق الأرضي (Floor 0): قمرة اليوم والغرف الأساسية
    topology.registerCoordinate(
      coordinate: const SpatialCoordinate(x: 0, y: 0, floor: 0),
      module: CockpitModule.instance,
    );
    topology.registerCoordinate(
      coordinate: const SpatialCoordinate(x: 0, y: 1, floor: 0), // North
      module: FocusModule.instance,
    );
    topology.registerCoordinate(
      coordinate: const SpatialCoordinate(x: 0, y: -1, floor: 0), // South
      module: CommsModule.instance,
    );
    topology.registerCoordinate(
      coordinate: const SpatialCoordinate(x: 1, y: 0, floor: 0), // East
      module: VisionModule.instance,
    );
    topology.registerCoordinate(
      coordinate: const SpatialCoordinate(x: -1, y: 0, floor: 0), // West
      module: AgendaModule.instance,
    );

    // ⚙️ الطابق الأول (Floor 1): إعدادات ومحركات الغرف
    topology.registerCoordinate(
      coordinate: const SpatialCoordinate(x: 0, y: 0, floor: 1),
      module: CockpitModule.instance,
    );
    topology.registerCoordinate(
      coordinate: const SpatialCoordinate(x: 0, y: 1, floor: 1),
      module: FocusModule.instance,
    );
    topology.registerCoordinate(
      coordinate: const SpatialCoordinate(x: 0, y: -1, floor: 1),
      module: CommsModule.instance,
    );
    topology.registerCoordinate(
      coordinate: const SpatialCoordinate(x: 1, y: 0, floor: 1),
      module: VisionModule.instance,
    );
    topology.registerCoordinate(
      coordinate: const SpatialCoordinate(x: -1, y: 0, floor: 1),
      module: AgendaModule.instance,
    );

    return topology;
  }

  /// تسجيل موديول في نقطة إحداثية محددة
  void registerCoordinate({
    required SpatialCoordinate coordinate,
    required SpatialModule module,
  }) {
    _coordinateGrid[coordinate] = module;
  }

  /// جسر التوافق القديم: تسجيل عبر SpatialDirection
  void register({
    required int floor,
    required SpatialDirection direction,
    required SpatialModule module,
  }) {
    final coord = SpatialCoordinate.fromDirection(direction, floor: floor);
    registerCoordinate(coordinate: coord, module: module);
  }

  /// الحصول على الموديول الموجود في إحداثي معين
  SpatialModule? moduleAtCoordinate(SpatialCoordinate coordinate) {
    return _coordinateGrid[coordinate];
  }

  /// جسر التوافق القديم: الحصول على الموديول عبر الاتجاه ورقم الطابق
  SpatialModule? moduleAt(int floor, SpatialDirection direction) {
    final coord = SpatialCoordinate.fromDirection(direction, floor: floor);
    return moduleAtCoordinate(coord);
  }

  /// ⚡️ جلب كافة الموديولات المسجلة في طابق معين مصنفة بإحداثياتها (X, Y)
  Map<SpatialCoordinate, SpatialModule> nodesOnFloor(int floor) {
    final result = <SpatialCoordinate, SpatialModule>{};
    for (final entry in _coordinateGrid.entries) {
      if (entry.key.floor == floor) {
        result[entry.key] = entry.value;
      }
    }
    return result;
  }

  /// جلب كافة الغرف الموجودة في طابق معين كخريطة اتجاهات
  Map<SpatialDirection, SpatialModule> roomsOnFloor(int floor) {
    final result = <SpatialDirection, SpatialModule>{};
    for (final entry in _coordinateGrid.entries) {
      if (entry.key.floor == floor) {
        final dir = entry.key.toCompassDirection();
        if (dir != null) {
          result[dir] = entry.value;
        }
      }
    }
    return result;
  }

  /// 🎯 تحديث خريطة الطوبولوجيا الحية مع تفريغ كامل لمنع الغرف الشبحية (Ghost Nodes)
  void updateFromNodes(List<dynamic> nodes) {
    final moduleRegistry = {
      for (final m in allModules) m.id: m,
      'cockpit': CockpitModule.instance,
      'focus': FocusModule.instance,
      'comms': CommsModule.instance,
      'vision': VisionModule.instance,
      'agenda': AgendaModule.instance,
    };

    // ⚡ تفريغ الشبكة تماماً قبل إعادة التسجيل لضمان مسح أي إحداثي قديم
    _coordinateGrid.clear();

    for (final node in nodes) {
      final moduleId = (node.moduleId as String?) ?? '';
      final x = (node.x as int?) ?? 0;
      final y = (node.y as int?) ?? 0;
      final floor = (node.floorLevel as int?) ?? 0;

      final module = moduleRegistry[moduleId];
      if (module != null) {
        registerCoordinate(
          coordinate: SpatialCoordinate(x: x, y: y, floor: floor),
          module: module,
        );
      }
    }
  }

  /// 🧭 خوارزمية استكشاف الغرفة المأهولة التالية (Raycasting Occupied Node Gravity)
  SpatialCoordinate? findNextOccupiedInDirection({
    required SpatialCoordinate origin,
    required SpatialDirection direction,
  }) {
    final floor = origin.floor;
    final candidates = _coordinateGrid.keys
        .where((c) => c.floor == floor && (c.x != origin.x || c.y != origin.y))
        .toList();

    switch (direction) {
      case SpatialDirection.east: // حركة نحو الشرق (+X)
        // 1. البحث عن أقرب غرفة على نفس المحور الأفقي Y
        final colinear = candidates
            .where((c) => c.y == origin.y && c.x > origin.x)
            .toList()
          ..sort((a, b) => a.x.compareTo(b.x));
        if (colinear.isNotEmpty) return colinear.first;

        // 2. البحث المرن: أقرب غرفة في النصف الشرقي عموماً
        final inQuadrant = candidates.where((c) => c.x > origin.x).toList()
          ..sort((a, b) => a.distanceTo(origin).compareTo(b.distanceTo(origin)));
        return inQuadrant.firstOrNull;

      case SpatialDirection.west: // حركة نحو الغرب (-X)
        final colinear = candidates
            .where((c) => c.y == origin.y && c.x < origin.x)
            .toList()
          ..sort((a, b) => b.x.compareTo(a.x)); // تنازلي لأخذ الأقرب لـ origin
        if (colinear.isNotEmpty) return colinear.first;

        final inQuadrant = candidates.where((c) => c.x < origin.x).toList()
          ..sort((a, b) => a.distanceTo(origin).compareTo(b.distanceTo(origin)));
        return inQuadrant.firstOrNull;

      case SpatialDirection.north: // حركة نحو الشمال (+Y)
        final colinear = candidates
            .where((c) => c.x == origin.x && c.y > origin.y)
            .toList()
          ..sort((a, b) => a.y.compareTo(b.y));
        if (colinear.isNotEmpty) return colinear.first;

        final inQuadrant = candidates.where((c) => c.y > origin.y).toList()
          ..sort((a, b) => a.distanceTo(origin).compareTo(b.distanceTo(origin)));
        return inQuadrant.firstOrNull;

      case SpatialDirection.south: // حركة نحو الجنوب (-Y)
        final colinear = candidates
            .where((c) => c.x == origin.x && c.y < origin.y)
            .toList()
          ..sort((a, b) => b.y.compareTo(a.y));
        if (colinear.isNotEmpty) return colinear.first;

        final inQuadrant = candidates.where((c) => c.y < origin.y).toList()
          ..sort((a, b) => a.distanceTo(origin).compareTo(b.distanceTo(origin)));
        return inQuadrant.firstOrNull;

      case SpatialDirection.center:
        // العودة لنقطة الأصل إذا كانت مأهولة، أو أقرب غرفة للمركز
        final originNode = SpatialCoordinate(x: 0, y: 0, floor: floor);
        if (_coordinateGrid.containsKey(originNode)) return originNode;
        candidates.sort((a, b) => a.distanceTo(originNode).compareTo(b.distanceTo(originNode)));
        return candidates.firstOrNull ?? originNode;
    }
  }

  /// جلب الإحداثي الدقيق لموديول معين على طابق ما
  SpatialCoordinate? coordinateOf(int floor, String moduleId) {
    for (final entry in _coordinateGrid.entries) {
      if (entry.key.floor == floor && entry.value.id == moduleId) {
        return entry.key;
      }
    }
    return null;
  }

  /// قائمة الطوابق المتوفرة مرتبة تصاعدياً
  List<int> get availableFloors {
    final floors = _coordinateGrid.keys.map((c) => c.floor).toSet().toList()..sort();
    return floors;
  }

  int get minFloor => availableFloors.isEmpty ? 0 : availableFloors.first;
  int get maxFloor => availableFloors.isEmpty ? 0 : availableFloors.last;

  bool hasFloor(int floor) => availableFloors.contains(floor);
  bool canAscendFrom(int floor) => floor < maxFloor && hasFloor(floor + 1);
  bool canDescendFrom(int floor) => floor > minFloor && hasFloor(floor - 1);

  SpatialDirection? directionOf(int floor, String moduleId) {
    for (final entry in _coordinateGrid.entries) {
      if (entry.key.floor == floor && entry.value.id == moduleId) {
        return entry.key.toCompassDirection();
      }
    }
    return null;
  }

  List<SpatialModule> get allModules {
    final modules = <String, SpatialModule>{};
    for (final module in _coordinateGrid.values) {
      modules[module.id] = module;
    }
    return modules.values.toList();
  }
}