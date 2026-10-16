// lib/spatial_shell/widgets/spatial_portal_transform.dart
import 'package:beacon_os/core/physics/spatial_physics.dart';
import 'package:flutter/widgets.dart';

/// يطبق مصفوفة المنظور الفضائي ثلاثي الأبعاد (Matrix4) وتأثير عمق الارتفاع للطابق.
class SpatialPortalTransform extends StatelessWidget {
  const SpatialPortalTransform({
    required this.floor,
    required this.currentZ,
    required this.child,
    this.isActive = true,
    super.key,
  });

  final int floor;
  final double currentZ;
  final Widget child;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final relativeDistance = floor - currentZ;
    final distanceAbs = relativeDistance.abs();

    if (distanceAbs >= 1.0) {
      return const SizedBox.shrink();
    }

    final opacity = SpatialPhysics.smootherStep(
      (1.0 - distanceAbs).clamp(0.0, 1.0),
    );

    final double scale;
    if (relativeDistance >= 0) {
      scale = 1.0 - (relativeDistance * 0.12);
    } else {
      scale = 1.0 - (relativeDistance * 0.10);
    }

    final translateY = -relativeDistance * SpatialPhysics.elevationLiftOffset;
    final tiltX = relativeDistance * 0.04;

    final matrix = Matrix4.identity()
      ..setEntry(3, 2, SpatialPhysics.perspectiveCoefficient)
      ..translate(0.0, translateY)
      ..scale(scale, scale)
      ..rotateX(tiltX);

    return Transform(
      key: ValueKey('spatial_portal_transform_$floor'),
      alignment: Alignment.center,
      transform: matrix,
      child: Opacity(
        opacity: opacity,
        child: IgnorePointer(
          ignoring: !isActive,
          child: child,
        ),
      ),
    );
  }
}