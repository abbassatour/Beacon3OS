// lib/spatial_shell/widgets/spatial_floor_layout.dart
import 'package:beacon_os/core/physics/spatial_physics.dart';
import 'package:beacon_os/core/topology/topology.dart';
import 'package:beacon_os/spatial_shell/cubit/spatial_shell_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// المخطط الفضائي عالي الكفاءة لأي طابق في النظام مع محرك الاستبعاد المكاني (Spatial Culling Engine)
class SpatialFloorLayout extends StatelessWidget {
  const SpatialFloorLayout({
    required this.direction,
    required this.floorLevel,
    this.panOffset = Offset.zero,
    super.key,
  });

  final SpatialDirection direction;
  final int floorLevel;
  final Offset panOffset;

  @override
  Widget build(BuildContext context) {
    final topology = context.read<SpatialTopology>();
    final size = MediaQuery.of(context).size;

    // 1. جلب كافة العُقد المسجلة في هذا الطابق بإحداثياتها (X, Y, Floor)
    final nodes = topology.nodesOnFloor(floorLevel);

    // 2. تحديد الإحداثي المستهدف الحالي بناءً على اتجاه البوصلة
    final currentTargetCoord = SpatialCoordinate.fromDirection(
      direction,
      floor: floorLevel,
    );

    return RepaintBoundary(
      child: Stack(
        clipBehavior: Clip.none,
        children: nodes.entries.map((entry) {
          final coord = entry.key;
          final module = entry.value;

          // حساب الإزاحة المكانية للغرفة بناءً على إحداثياتها (X, Y) وإزاحة الكاميرا الحالية
          // نلاحظ أن محور Y الديكارتي (+1 للشمال) يقابل (-1) في محاور شاشة العرض
          final roomOffset = Offset(
            coord.x * size.width + panOffset.dx,
            -coord.y * size.height + panOffset.dy,
          );

          // ⚡️ اختبار الاستبعاد المكاني الفوري (Spatial Culling Test):
          // إذا كانت الغرفة خارج حدود الشاشة تماماً، نتجاهل رسمها بالكامل لحماية الذاكرة والـ GPU
          final isVisibleInViewport = SpatialPhysics.isIntersectingViewport(
            roomOffset: roomOffset,
            screenSize: size,
            cullBuffer: 30.0, // هامش أمان طفيف يضمن السلاسة أثناء السحب السريع
          );

          if (!isVisibleInViewport) {
            return const SizedBox.shrink();
          }

          // فحص هل الكاميرا مستقرة حالياً في هذه الغرفة بالذات
          final isTargetRoom = coord == currentTargetCoord;
          // الغرفة تعتبر نشطة بالكامل وتستجيب للمس فقط إذا استقرت الكاميرا عندها وتوقفت عن السحب البعيد
          final isCameraRestingHere = isTargetRoom && panOffset.distance < 12.0;

          return Transform.translate(
            key: ValueKey('floor_${floorLevel}_coord_${coord.x}_${coord.y}_${module.id}'),
            offset: roomOffset,
            child: RepaintBoundary(
              child: TickerMode(
                // تجميد المؤقتات والحركات الداخلية لأي غرفة لا يستقر فيها المستخدم حالياً
                enabled: isTargetRoom,
                child: IgnorePointer(
                  // حجب التفاعل اللمسي إلا إذا كانت الغرفة هي المستقرة في واجهة المستخدم
                  ignoring: !isCameraRestingHere,
                  child: ExcludeSemantics(
                    // حجب عناصر قراءة الشاشة عن المكفوفين للغرف التي تمر على الأطراف أثناء السحب
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

// 🛡️ أسماء توافقية لمنع انكسار الكود القديم
typedef CoreFloorLayout = SpatialFloorLayout;
typedef SettingsFloorLayout = SpatialFloorLayout;
typedef CompassTransitionLayout = SpatialFloorLayout;