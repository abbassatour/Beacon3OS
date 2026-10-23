// lib/tv/shared/widgets/tv_pulsing_radar_icon.dart
import 'package:flutter/material.dart';

class TvPulsingRadarIcon extends StatefulWidget {
  const TvPulsingRadarIcon({
    required this.icon,
    required this.color,
    this.radius = 24.0,
    super.key,
  });

  final IconData icon;
  final Color color;
  final double radius;

  @override
  State<TvPulsingRadarIcon> createState() => _TvPulsingRadarIconState();
}

class _TvPulsingRadarIconState extends State<TvPulsingRadarIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseSize = widget.radius * 2;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final pulseExpansion = _controller.value * 14.0;
        final currentPulseSize = baseSize + pulseExpansion;

        return SizedBox(
          width: baseSize + 16,
          height: baseSize + 16,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // حلقة النبض الرادارية المتلاشية
              Container(
                width: currentPulseSize,
                height: currentPulseSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.color.withValues(
                      alpha: (1.0 - _controller.value) * 0.45,
                    ),
                    width: 1.5,
                  ),
                ),
              ),
              // الدائرة المركزية الثابتة
              CircleAvatar(
                radius: widget.radius,
                backgroundColor: widget.color.withValues(alpha: 0.15),
                child: Icon(
                  widget.icon,
                  size: widget.radius * 1.05,
                  color: widget.color,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}