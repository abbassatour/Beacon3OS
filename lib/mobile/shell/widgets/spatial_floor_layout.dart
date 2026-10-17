// lib/mobile/shell/widgets/spatial_floor_layout.dart
import 'package:beacon_os/core/physics/spatial_physics.dart';
import 'package:beacon_os/core/topology/topology.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// المخطط الفضائي عالي الكفاءة لأي طابق مع محرك الاستبعاد المكاني (Spatial Culling Engine)
class SpatialFloorLayout extends StatelessWidget {
  const SpatialFloorLayout({
    required this.currentCoordinate,
    required this.floorLevel,
    this.panOffset = Offset.zero,
    super.key,
  });

  /// الإحداثي الديكارتي النشط حالياً في الكانفاس
  final SpatialCoordinate currentCoordinate;
  final int floorLevel;
  final Offset panOffset;

  @override
  Widget build(BuildContext context) {
    final topology = context.read<SpatialTopology>();
    final size = MediaQuery.of(context).size;

    // 1. جلب كافة العُقد المسجلة حياً في هذا الطابق من قاعدة البيانات
    final nodes = topology.nodesOnFloor(floorLevel);

    return RepaintBoundary(
      child: Stack(
        clipBehavior: Clip.none,
        children: nodes.entries.map((entry) {
          final coord = entry.key;
          final module = entry.value;

          // 📐 حساب الإزاحة المكانية للغرفة بناءً على إحداثياتها وإزاحة الكاميرا الحالية
          final roomOffset = Offset(
            coord.x * size.width + panOffset.dx,
            -coord.y * size.height + panOffset.dy,
          );

          // ⚡️ اختبار الاستبعاد المكاني الفوري مع حماية Buffer واسعة (250px) لمنع إعادة بناء الكيوبتات
          final isVisibleInViewport = SpatialPhysics.isIntersectingViewport(
            roomOffset: roomOffset,
            screenSize: size,
            cullBuffer: 250.0,
          );

          if (!isVisibleInViewport) {
            return const SizedBox.shrink();
          }

          // 🎯 فحص هل الكاميرا مستقرة حالياً في هذه الغرفة بالإحداثيات المباشرة
          final isTargetRoom = coord.x == currentCoordinate.x &&
              coord.y == currentCoordinate.y &&
              coord.floor == floorLevel;

          final isCameraRestingHere = isTargetRoom &&
              (Offset(
                    coord.x * size.width + panOffset.dx,
                    -coord.y * size.height + panOffset.dy,
                  )).distance <
                  14.0;

          return Transform.translate(
            key: ValueKey('floor_${floorLevel}_coord_${coord.x}_${coord.y}_${module.id}'),
            offset: roomOffset,
            child: RepaintBoundary(
              child: TickerMode(
                // تجميد العمليات والمؤقتات لأي غرفة خارج مركز الرؤية
                enabled: isTargetRoom,
                child: IgnorePointer(
                  ignoring: !isCameraRestingHere,
                  child: ExcludeSemantics(
                    excluding: !isCameraRestingHere,
                    child: FocusScope(
                      canRequestFocus: isCameraRestingHere,
                      child: module.buildFloorView(context, floorLevel),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}