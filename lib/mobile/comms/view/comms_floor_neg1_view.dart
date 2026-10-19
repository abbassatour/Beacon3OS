// lib/mobile/comms/view/comms_floor_neg1_view.dart
import 'package:beacon_os/core/audio/sound_controller.dart';
import 'package:beacon_os/core/audio/sound_cue.dart';
import 'package:beacon_os/core/constants/api_constants.dart';
import 'package:beacon_os/core/haptics/haptic_manager.dart';
import 'package:beacon_os/core/services/web3_service.dart';
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/mobile/shell/spatial_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:launcher_repository/launcher_repository.dart';
import 'package:url_launcher/url_launcher.dart';

/// واجهة الطابق السفلي للاتصالات (Floor -1: Arbitrum Sepolia SOS Ledger)
class CommsFloorNeg1View extends StatelessWidget {
  const CommsFloorNeg1View({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final commsRepo = context.read<CommsRepository>();
    final assistant = context.read<AssistantRepository>();
    final shellCubit = context.read<SpatialShellCubit>();

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ==========================================
            // 1. رأس الصفحة والملاحة الفضائية
            // ==========================================
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.verified_user_rounded,
                              color: colors.error,
                              size: 26,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'ARBITRUM SOS LEDGER',
                              style: TextStyle(
                                color: colors.onSurface,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                        IconButton.filledTonal(
                          style: IconButton.styleFrom(
                            backgroundColor: colors.surface,
                            foregroundColor: colors.onSurface,
                            side: BorderSide(color: colors.outline),
                          ),
                          icon: const Icon(Icons.arrow_upward_rounded, size: 20),
                          tooltip: 'Ascend to Ground Floor (Comms)',
                          onPressed: shellCubit.returnToGroundFloor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Floor -1 • Immutable on-chain emergency records & GPS dispatch history.',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ==========================================
            // 2. بطاقة إثبات الأثر والعقد الذكي
            // ==========================================
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: colors.error.withValues(alpha: 0.5), width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 9,
                                height: 9,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'ARBITRUM SEPOLIA (L2)',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'TAMPER-PROOF',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Every SOS broadcast anchors non-custodial GPS coordinates and battery telemetry directly to the BeaconImpactPool contract, creating an irrefutable legal and rescue audit trail.',
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'CONTRACT ADDRESS',
                                  style: TextStyle(
                                    color: colors.onSurfaceVariant,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  ApiConstants.impactContractAddress,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: colors.onSurface,
                                    fontSize: 11.5,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 16),
                            tooltip: 'Copy Contract Address',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: ApiConstants.impactContractAddress));
                              HapticManager.instance.selectionClick();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Contract address copied!'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ==========================================
            // 3. سجل الاستغاثات التاريخية (SOS History)
            // ==========================================
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'DISTRESS ATTESTATIONS LOG',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                    Icon(Icons.history_rounded, size: 16, color: colors.onSurfaceVariant),
                  ],
                ),
              ),
            ),
            StreamBuilder<List<SosAlertRecord>>(
              stream: commsRepo.watchSosHistory(),
              builder: (context, snapshot) {
                final alerts = snapshot.data ?? [];

                if (alerts.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: colors.outline),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.shield_outlined, size: 36, color: Colors.green),
                            const SizedBox(height: 10),
                            Text(
                              'Zero Distress Records',
                              style: TextStyle(
                                color: colors.onSurface,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Your emergency SOS history is completely quiet. Tapping SOS on Floor 0 logs alerts here and on Arbitrum.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final alert = alerts[index];
                        final timeStr = DateFormat('MMM d, yyyy • h:mm a').format(alert.triggeredAt.toLocal());

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Material(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () async {
                                HapticManager.instance.selectionClick();
                                await SoundController.instance.play(SoundCue.navCenter);
                                await assistant.speak(
                                  'Emergency alert at $timeStr. Coordinates: ${alert.latitude.toStringAsFixed(3)} degrees North, ${alert.longitude.toStringAsFixed(3)} degrees East. Battery was at ${alert.batteryLevel} percent.',
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: colors.error.withValues(alpha: 0.3)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.warning_amber_rounded, size: 18, color: colors.error),
                                            const SizedBox(width: 8),
                                            Text(
                                              'SOS BROADCAST',
                                              style: TextStyle(
                                                color: colors.error,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Text(
                                          timeStr,
                                          style: TextStyle(
                                            color: colors.onSurfaceVariant,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'GPS: ${alert.latitude.toStringAsFixed(5)}, ${alert.longitude.toStringAsFixed(5)} • Battery: ${alert.batteryLevel}%',
                                      style: TextStyle(
                                        color: colors.onSurface,
                                        fontSize: 13,
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: colors.onSurface,
                                            side: BorderSide(color: colors.outline),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          ),
                                          icon: const Icon(Icons.map_rounded, size: 14),
                                          label: const Text('Open Map', style: TextStyle(fontSize: 11.5)),
                                          onPressed: () {
                                            if (alert.googleMapsUrl.startsWith('http')) {
                                              launchUrl(Uri.parse(alert.googleMapsUrl));
                                            }
                                          },
                                        ),
                                        const SizedBox(width: 8),
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: colors.onSurface,
                                            side: BorderSide(color: colors.outline),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          ),
                                          icon: const Icon(Icons.volume_up_rounded, size: 14),
                                          label: const Text('Listen', style: TextStyle(fontSize: 11.5)),
                                          onPressed: () async {
                                            await assistant.speak(
                                              'Alert on $timeStr. Latitude ${alert.latitude.toStringAsFixed(3)}, Longitude ${alert.longitude.toStringAsFixed(3)}.',
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: alerts.length,
                    ),
                  ),
                );
              },
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 60)),
          ],
        ),
      ),
    );
  }
}