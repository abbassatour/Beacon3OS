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
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: bannerColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            isSos ? Icons.warning_rounded : Icons.cell_tower_rounded,
            color: Colors.white,
            size: 30,
          ),
          const SizedBox(width: 14),
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
                    fontSize: 15,
                    letterSpacing: 1.1,
                  ),
                ),
                Text(
                  isSos
                      ? 'Distress radar broadcasting live coordinates to Arbitrum ledger.'
                      : 'Living room voice query triggered hardware siren & flashlight strobe.',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: onDismiss,
            child: const Text(
              'Dismiss',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}