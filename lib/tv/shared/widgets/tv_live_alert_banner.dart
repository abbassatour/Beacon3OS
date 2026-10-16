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
    final bannerColor = isSos ? colors.error : colors.primary;

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
            isSos ? Icons.warning_rounded : Icons.cell_tower_rounded,
            color: Colors.white,
            size: 38, // 👈 أيقونة واضحة وكبيرة
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isSos
                      ? '🚨 EMERGENCY SOS ACTIVE • ON-CHAIN ATTESTED'
                      : '📍 ACOUSTIC PING DISPATCHED',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18.5, // 👈 عنوان التنبيه بارز جداً
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isSos
                      ? 'Distress radar broadcasting live coordinates to Arbitrum ledger and family devices.'
                      : 'Living room voice query triggered hardware siren & flashlight strobe on phone.',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15, // 👈 قراءة مريحة
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
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