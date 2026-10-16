// lib/tv/shared/widgets/tv_live_alert_banner.dart
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:launcher_repository/launcher_repository.dart';

class TvLiveAlertBanner extends StatelessWidget {
  const TvLiveAlertBanner({
    required this.alert,
    required this.onDismiss,
    super.key,
  });

  final RemoteActionEvent alert;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    
    final isSos = alert.actionType == RemoteActionType.triggerSos;
    final isLocate = alert.actionType == RemoteActionType.locateDevice;
    final isRing = alert.payload['is_ring'] == true;

    Color bannerColor = colors.surface;
    IconData icon = Icons.notifications_rounded;
    String title = 'SYSTEM ALERT';
    String subtitle = 'Incoming notification...';

    if (isSos) {
      bannerColor = colors.error;
      icon = Icons.warning_rounded;
      title = '🚨 EMERGENCY SOS ACTIVE • ON-CHAIN ATTESTED';
      subtitle = 'Distress radar broadcasting live coordinates to Arbitrum ledger and family devices.';
    } else if (isLocate) {
      bannerColor = colors.primary;
      icon = Icons.cell_tower_rounded;
      title = '📍 ACOUSTIC PING DISPATCHED';
      subtitle = 'Living room voice query triggered hardware siren & flashlight strobe on phone.';
    } else if (isRing) {
      bannerColor = colors.secondary; // لون مميز للكاميرات (أصفر أو برتقالي حسب الثيم)
      icon = Icons.doorbell_rounded;
      final deviceLabel = alert.payload['device_label']?.toString().toUpperCase() ?? 'CAMERA';
      title = '🔔 RING ALERT: $deviceLabel';
      subtitle = alert.payload['description']?.toString() ?? 'Activity detected at the camera.';
    }

    // تحديد لون النص بناءً على لون الخلفية لضمان التباين
    final contentColor = isRing ? colors.surface : Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      decoration: BoxDecoration(
        color: bannerColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: bannerColor.withValues(alpha: 0.45),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: contentColor,
            size: 38,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: contentColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 18.5,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: contentColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: contentColor,
              foregroundColor: bannerColor, // لون زر معكوس
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: onDismiss,
            child: const Text(
              'Dismiss [Back]',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }
}