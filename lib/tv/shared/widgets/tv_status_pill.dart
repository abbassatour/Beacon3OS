// lib/tv/shared/widgets/tv_status_pill.dart
import 'package:flutter/material.dart';
import 'package:launcher_repository/launcher_repository.dart';

class TvStatusPill extends StatelessWidget {
  const TvStatusPill({
    required this.icon,
    required this.label,
    required this.color,
    super.key,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  /// مُنشئ سريع لبناء شارة نمط نقل البيانات (LAN Direct vs Cloud Relay)
  static Widget forTransport(SyncTransportMode mode, ColorScheme colors) {
    switch (mode) {
      case SyncTransportMode.lanDirect:
        return const TvStatusPill(
          icon: Icons.bolt_rounded,
          label: 'LAN DIRECT (< 2ms)',
          color: Colors.green,
        );
      case SyncTransportMode.cloudRelay:
        return TvStatusPill(
          icon: Icons.cloud_done_rounded,
          label: 'CLOUD RELAY',
          color: colors.primary,
        );
      case SyncTransportMode.discovering:
        return TvStatusPill(
          icon: Icons.wifi_find_rounded,
          label: 'SCANNING LAN...',
          color: colors.secondary,
        );
      case SyncTransportMode.standalone:
        return TvStatusPill(
          icon: Icons.wifi_off_rounded,
          label: 'STANDALONE',
          color: colors.onSurfaceVariant,
        );
    }
  }
}