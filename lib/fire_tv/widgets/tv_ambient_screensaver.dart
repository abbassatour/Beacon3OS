import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TvAmbientScreensaver extends StatelessWidget {
  const TvAmbientScreensaver({
    required this.currentTime,
    super.key,
  });

  final DateTime currentTime;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final timeStr = DateFormat('h:mm').format(currentTime);
    final periodStr = DateFormat('a').format(currentTime);
    final dateStr = DateFormat('EEEE, MMMM d').format(currentTime);

    return Center(
      key: const ValueKey('tv_ambient_screensaver'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                timeStr,
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 90,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -3,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                periodStr,
                style: TextStyle(
                  color: colors.primary,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            dateStr,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: colors.outline.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.radio_button_checked_rounded,
                  size: 14,
                  color: Colors.green,
                ),
                const SizedBox(width: 8),
                Text(
                  'Living Room Bridge Active • Press any remote button to wake',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}