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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.error.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.error.withValues(alpha: state.isBroadcastingSos ? 0.15 : 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.error.withValues(alpha: 0.4)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: colors.error,
                      child: Icon(
                        state.isBroadcastingSos
                            ? Icons.wifi_tethering_rounded
                            : Icons.warning_amber_rounded,
                        color: colors.surface,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.isBroadcastingSos
                                ? 'BROADCASTING TEST RADAR...'
                                : 'EMERGENCY RADAR ACTIVE',
                            style: TextStyle(
                              color: colors.error,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Triple-tap on phone sounds alarm & anchors GPS to Arbitrum ledger.',
                            style: TextStyle(
                              color: colors.onSurface,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.error,
                        foregroundColor: colors.surface,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      icon: const Icon(Icons.satellite_alt_rounded, size: 16),
                      label: const Text(
                        'Test SOS',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                      onPressed: state.isBroadcastingSos ? null : cubit.triggerTestSosBroadcast,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.verified_rounded, size: 12, color: Colors.green),
                          SizedBox(width: 4),
                          Text(
                            'Arbitrum Sepolia Attested (L2)',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Tamper-proof GPS beacon',
                      style: TextStyle(color: colors.onSurfaceVariant, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'EMERGENCY DISPATCH CONTACTS (${state.emergencyContacts.length})',
                style: TextStyle(
                  color: colors.error,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
              Text(
                'Receives live GPS alert',
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: state.emergencyContacts.isEmpty
                ? Center(
                    child: Text(
                      'No emergency contacts registered.\nPromote standard contacts to emergency priority.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    itemCount: state.emergencyContacts.length,
                    itemBuilder: (context, index) {
                      final contact = state.emergencyContacts[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: colors.error.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: colors.error.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: colors.error.withValues(alpha: 0.15),
                              child: Icon(Icons.shield_rounded, color: colors.error, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    contact.name,
                                    style: TextStyle(
                                      color: colors.onSurface,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    '${contact.relationship ?? 'Emergency Primary'} - ${contact.phoneNumber}',
                                    style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.phone_rounded, color: colors.primary, size: 18),
                              tooltip: 'Dial Number',
                              onPressed: () => launchUrl(Uri.parse('tel:${contact.phoneNumber}')),
                            ),
                            IconButton(
                              icon: Icon(Icons.star_rounded, color: colors.error, size: 20),
                              tooltip: 'Demote to regular contact',
                              onPressed: () => cubit.toggleEmergencyStatus(contact),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline_rounded, color: colors.error, size: 18),
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
