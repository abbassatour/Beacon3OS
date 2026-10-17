// lib/core/topology/spatial_topology.dart
import 'dart:async';

import 'package:beacon_os/core/topology/spatial_coordinate.dart';
import 'package:beacon_os/core/topology/spatial_direction.dart';
import 'package:beacon_os/core/topology/spatial_module.dart';
import 'package:beacon_os/core/topology/spatial_module_registry.dart';
import 'package:launcher_repository/launcher_repository.dart';

/// خريطة الطوبولوجيا المكانية الديناميكية والتفاعلية لنظام التشغيل
class SpatialTopology {
  SpatialTopology();

  /// شبكة الإحداثيات ثلاثية الأبعاد: SpatialCoordinate -> SpatialModule
  final Map<SpatialCoordinate, SpatialModule> _coordinateGrid = {};

  /// 🏷️ شبكة العناوين الحية المزامنة مع قاعدة البيانات: SpatialCoordinate -> Title
  final Map<SpatialCoordinate, String> _customTitles = {};

  /// ⚡️ قناة البث اللحظي لإشعار الكيوبيت والشاشات عند أي تعديل في مواقع أو أسماء الغرف
  final StreamController<void> _changesController =
      StreamController<void>.broadcast();

  /// تدفق الاستماع لتغييرات مواقع الغرف
  Stream<void> get changes => _changesController.stream;

  /// تسجيل موديول في نقطة إحداثية محددة مع عنوانه المخصص
  void registerCoordinate({
    required SpatialCoordinate coordinate,
    required SpatialModule module,
    String? title,
    bool notify = true,
  }) {
    _coordinateGrid[coordinate] = module;
    if (title != null && title.trim().isNotEmpty) {
      _customTitles[coordinate] = title.trim();
    }
    if (notify && !_changesController.isClosed) {
      _changesController.add(null);
    }
  }

  /// جسر التوافق: تسجيل عبر SpatialDirection
  void register({
    required int floor,
    required SpatialDirection direction,
    required SpatialModule module,
    String? title,
  }) {
    final coord = SpatialCoordinate.fromDirection(direction, floor: floor);
    registerCoordinate(coordinate: coord, module: module, title: title);
  }

  /// الحصول على الموديول الموجود في إحداثي معين
  SpatialModule? moduleAtCoordinate(SpatialCoordinate coordinate) {
    return _coordinateGrid[coordinate];
  }

  /// 🏷️ جلب عنوان الغرفة النظيف المحفوظ في قاعدة البيانات بأمان
  String titleAtCoordinate(SpatialCoordinate coordinate) {
    final custom = _customTitles[coordinate];
    if (custom != null && custom.isNotEmpty) {
      return custom;
    }
    final module = _coordinateGrid[coordinate];
    if (module != null) {
      return module.getFloorTitle(coordinate.floor);
    }
    return coordinate.floor != 0
        ? 'Settings • Floor ${coordinate.floor}'
        : 'Cockpit';
  }

  /// جسر التوافق: الحصول على الموديول عبر الاتجاه ورقم الطابق
  SpatialModule? moduleAt(int floor, SpatialDirection direction) {
    final coord = SpatialCoordinate.fromDirection(direction, floor: floor);
    return moduleAtCoordinate(coord);
  }

  /// جلب كافة الموديولات المسجلة في طابق معين مصنفة بإحداثياتها (X, Y)
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
        result[dir] = entry.value;
      }
    }
    return result;
  }

  /// 🎯 تحديث خريطة الطوبولوجيا ديناميكياً من السجل المركزي دون أي فحص نصي ثابت
  void updateFromNodes(List<SpatialNodeEntity> nodes) {
    final registry = SpatialModuleRegistry.instance;

    // تفريغ الشبكتين تماماً لضمان المحاذاة مع أحدث حالة لقاعدة البيانات
    _coordinateGrid.clear();
    _customTitles.clear();

    for (final node in nodes) {
      final moduleId = node.moduleId;
      final x = node.x;
      final y = node.y;
      final floor = node.floorLevel;
      final customTitle = node.customTitle?.trim();

      // 🌟 استدعاء الموديول مباشرة من السجل المركزي (يدعم أي موديول جديد تلقائياً)
      final module = registry.get(moduleId);
      if (module != null) {
        final coord = SpatialCoordinate(x: x, y: y, floor: floor);
        registerCoordinate(
          coordinate: coord,
          module: module,
          title: (customTitle != null && customTitle.isNotEmpty)
              ? customTitle
              : null,
          notify: false,
        );
      }
    }

    // ⚡️ بث إشعار التغيير لكافة المستمعين والكاميرا والشريط العلوي
    if (!_changesController.isClosed) {
      _changesController.add(null);
    }
  }

  /// 🧭 خوارزمية استكشاف الغرفة المأهولة التالية (Strict Colinear Raycasting)
  SpatialCoordinate? findNextOccupiedInDirection({
    required SpatialCoordinate origin,
    required SpatialDirection direction,
  }) {
    final floor = origin.floor;
    final candidates = _coordinateGrid.keys
        .where((c) => c.floor == floor && (c.x != origin.x || c.y != origin.y))
        .toList();

    switch (direction) {
      case SpatialDirection.east:
        final colinear = candidates
            .where((c) => c.y == origin.y && c.x > origin.x)
            .toList()
          ..sort((a, b) => a.x.compareTo(b.x));
        return colinear.firstOrNull;

      case SpatialDirection.west:
        final colinear = candidates
            .where((c) => c.y == origin.y && c.x < origin.x)
            .toList()
          ..sort((a, b) => b.x.compareTo(a.x));
        return colinear.firstOrNull;

      case SpatialDirection.north:
        final colinear = candidates
            .where((c) => c.x == origin.x && c.y > origin.y)
            .toList()
          ..sort((a, b) => a.y.compareTo(b.y));
        return colinear.firstOrNull;

      case SpatialDirection.south:
        final colinear = candidates
            .where((c) => c.x == origin.x && c.y < origin.y)
            .toList()
          ..sort((a, b) => b.y.compareTo(a.y));
        return colinear.firstOrNull;

      case SpatialDirection.center:
        final originNode = SpatialCoordinate(x: 0, y: 0, floor: floor);
        if (_coordinateGrid.containsKey(originNode)) return originNode;
        candidates.sort(
          (a, b) => a.distanceTo(originNode).compareTo(b.distanceTo(originNode)),
        );
        return candidates.firstOrNull ?? originNode;
    }
  }

  /// 🧭 فحص هل تمتلك النقطة الإحداثية الحالية أي جيران على المحور العمودي (شمالاً أو جنوباً)
  bool hasVerticalNeighbors(SpatialCoordinate origin) {
    final hasNorth = findNextOccupiedInDirection(
          origin: origin,
          direction: SpatialDirection.north,
        ) != null;

    final hasSouth = findNextOccupiedInDirection(
          origin: origin,
          direction: SpatialDirection.south,
        ) != null;

    return hasNorth || hasSouth;
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

  List<int> get availableFloors {
    final floors = _coordinateGrid.keys.map((c) => c.floor).toSet().toList()
      ..sort();
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

  /// جميع الموديولات المسجلة والموجودة في الفضاء
  List<SpatialModule> get allModules {
    final modules = <String, SpatialModule>{};
    for (final module in _coordinateGrid.values) {
      modules[module.id] = module;
    }
    // دمج موديولات السجل المركزي أيضاً حتى لو لم تكن موضوعة بعد على الكانفاس
    for (final module in SpatialModuleRegistry.instance.allModules) {
      modules[module.id] = module;
    }
    return modules.values.toList();
  }

  void dispose() {
    _changesController.close();
  }
}