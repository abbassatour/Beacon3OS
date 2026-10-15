import 'package:flutter/material.dart';

class TvPulsingRadarIcon extends StatefulWidget {
  const TvPulsingRadarIcon({
    required this.icon,
    required this.color,
    super.key,
  });

  final IconData icon;
  final Color color;

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
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 70 + (_controller.value * 24),
              height: 70 + (_controller.value * 24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.color.withValues(
                    alpha: (1.0 - _controller.value) * 0.5,
                  ),
                  width: 1.8,
                ),
              ),
            ),
            CircleAvatar(
              radius: 34,
              backgroundColor: widget.color.withValues(alpha: 0.15),
              child: Icon(widget.icon, size: 34, color: widget.color),
            ),
          ],
        );
      },
    );
  }
}