// lib/desktop/comms/widgets/emergency_radar_panel.dart
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/desktop/comms/cubit/desktop_comms_cubit.dart';
import 'package:beacon_os/desktop/comms/cubit/desktop_comms_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

class EmergencyRadarPanel extends StatelessWidget {
  const EmergencyRadarPanel({required this.state, super.key});

  final DesktopCommsState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cubit = context.read<DesktopCommsCubit>();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.error.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.error.withValues(alpha: state.isBroadcastingSos ? 0.15 : 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.error.withValues(alpha: 0.4)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: colors.error,
                      child: Icon(
                        state.isBroadcastingSos
                            ? Icons.wifi_tethering_rounded
                            : Icons.warning_amber_rounded,
                        color: colors.surface,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.isBroadcastingSos
                                ? 'BROADCASTING RADAR...'
                                : 'EMERGENCY RADAR ACTIVE',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.error,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Triple-tap on phone sounds alarm & anchors GPS to Arbitrum.',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.onSurface,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.error,
                        foregroundColor: colors.surface,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.satellite_alt_rounded, size: 14),
                      label: const Text(
                        'Test',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                      onPressed: state.isBroadcastingSos ? null : cubit.triggerTestSosBroadcast,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // 🌟 استخدام Wrap لمنع طفح شارة الـ Arbitrum
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.verified_rounded, size: 11, color: Colors.green),
                          SizedBox(width: 4),
                          Text(
                            'Arbitrum Sepolia L2',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'Tamper-proof GPS beacon',
                      style: TextStyle(color: colors.onSurfaceVariant, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'EMERGENCY CONTACTS (${state.emergencyContacts.length})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.error,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Live GPS alert',
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: state.emergencyContacts.isEmpty
                ? Center(
                    child: Text(
                      'No emergency contacts registered.\nPromote contacts from directory.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11.5),
                    ),
                  )
                : ListView.builder(
                    itemCount: state.emergencyContacts.length,
                    itemBuilder: (context, index) {
                      final contact = state.emergencyContacts[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: colors.error.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colors.error.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 15,
                              backgroundColor: colors.error.withValues(alpha: 0.15),
                              child: Icon(Icons.shield_rounded, color: colors.error, size: 15),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    contact.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: colors.onSurface,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    '${contact.relationship ?? 'Emergency'} - ${contact.phoneNumber}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: colors.onSurfaceVariant, fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.phone_rounded, color: colors.primary, size: 16),
                              tooltip: 'Dial Number',
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                              onPressed: () => launchUrl(Uri.parse('tel:${contact.phoneNumber}')),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: Icon(Icons.star_rounded, color: colors.error, size: 18),
                              tooltip: 'Demote to regular',
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                              onPressed: () => cubit.toggleEmergencyStatus(contact),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: Icon(Icons.delete_outline_rounded, color: colors.error, size: 16),
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                              onPressed: () => cubit.deleteContact(contact),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}