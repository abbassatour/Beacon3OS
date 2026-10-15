import 'package:beacon_os/core/audio/sound_controller.dart';
import 'package:beacon_os/core/audio/sound_cue.dart';
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/fire_tv/widgets/tv_card_responsive.dart';
import 'package:beacon_os/fire_tv/widgets/tv_interactive_alarms_list.dart';
import 'package:beacon_os/fire_tv/widgets/tv_interactive_tasks_list.dart';
import 'package:beacon_os/fire_tv/widgets/tv_live_alert_banner.dart';
import 'package:beacon_os/fire_tv/widgets/tv_pulsing_radar_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:launcher_repository/launcher_repository.dart';

class TvDashboardView extends StatelessWidget {
  const TvDashboardView({
    required this.currentTime,
    required this.transportMode,
    required this.activeAlert,
    required this.locateCardFocus,
    required this.sosCardFocus,
    required this.agendaFocus,
    required this.alarmsFocus,
    required this.onUnpair,
    required this.onDismissAlert,
    super.key,
  });

  final DateTime currentTime;
  final SyncTransportMode transportMode;
  final RemoteActionEvent? activeAlert;
  final FocusNode locateCardFocus;
  final FocusNode sosCardFocus;
  final FocusNode agendaFocus;
  final FocusNode alarmsFocus;
  final VoidCallback onUnpair;
  final VoidCallback onDismissAlert;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final timeStr = DateFormat('h:mm a').format(currentTime);
    final dateStr = DateFormat('EEE, MMM d').format(currentTime);

    return Padding(
      key: const ValueKey('tv_active_dashboard'),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // شريط الحالة العلوي
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.primary, width: 1.5),
                      ),
                      child: Icon(Icons.tv_rounded, color: colors.primary, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'BEACON OS',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.onSurface,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                          Text(
                            'Living Room Bridge • Linked',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTransportBadge(colors),
                  const SizedBox(width: 8),
                  _buildPillBadge(
                    icon: Icons.verified_rounded,
                    label: 'ARBITRUM L2',
                    color: colors.primary,
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: Icon(
                      Icons.link_off_rounded,
                      color: colors.onSurfaceVariant,
                      size: 20,
                    ),
                    tooltip: 'Unpair this display',
                    onPressed: onUnpair,
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeStr,
                        style: TextStyle(
                          color: colors.onSurface,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        dateStr,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (activeAlert != null) ...[
            TvLiveAlertBanner(
              alert: activeAlert!,
              onDismiss: onDismissAlert,
            ),
            const SizedBox(height: 12),
          ],

          // شبكة البطاقات التفاعلية (2x2 Matrix)
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 6,
                        child: TvCardResponsive(
                          focusNode: locateCardFocus,
                          title: 'ACOUSTIC PHONE LOCATOR',
                          subtitle: 'Press [SELECT] to ping missing phone',
                          icon: Icons.radar_rounded,
                          accentColor: colors.primary,
                          onSelect: () async {
                            final comms = context.read<CommsRepository>();
                            final ok = await comms.requestLocatePhone(
                              reason: 'Fire TV living room request',
                            );
                            if (ok) {
                              SoundController.instance.play(SoundCue.wake);
                            }
                          },
                          child: Center(
                            child: SingleChildScrollView(
                              physics: const NeverScrollableScrollPhysics(),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TvPulsingRadarIcon(
                                    icon: Icons.phonelink_ring_rounded,
                                    color: colors.primary,
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'PING PHONE HARDWARE',
                                    style: TextStyle(
                                      color: colors.onSurface,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Pings phone instantly via Local LAN (< 2ms)',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: colors.onSurfaceVariant,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        flex: 4,
                        child: TvCardResponsive(
                          focusNode: sosCardFocus,
                          title: 'FAMILY SAFETY RADAR (SOS)',
                          subtitle: 'Simulate on-chain emergency alert',
                          icon: Icons.emergency_rounded,
                          accentColor: colors.error,
                          onSelect: () {
                            context.read<CommsRepository>().triggerEmergencySos();
                            SoundController.instance.play(SoundCue.sosAlarm);
                          },
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: colors.error.withValues(alpha: 0.15),
                                child: Icon(
                                  Icons.warning_amber_rounded,
                                  size: 26,
                                  color: colors.error,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Triple-tapping Beacon phone broadcasts real-time GPS coordinates here in < 2ms and anchors an attestation on Arbitrum Sepolia.',
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: colors.onSurface,
                                    fontSize: 12,
                                    height: 1.35,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 6,
                        child: TvCardResponsive(
                          focusNode: agendaFocus,
                          title: 'AGENDA & PRIORITIES',
                          subtitle: 'Press [SELECT] to toggle tasks',
                          icon: Icons.calendar_today_rounded,
                          accentColor: colors.secondary,
                          child: const TvInteractiveTasksList(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        flex: 4,
                        child: TvCardResponsive(
                          focusNode: alarmsFocus,
                          title: 'UPCOMING ALARMS',
                          subtitle: 'Synchronized with Android Clock',
                          icon: Icons.alarm_rounded,
                          accentColor: colors.primary,
                          child: const TvInteractiveAlarmsList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransportBadge(ColorScheme colors) {
    switch (transportMode) {
      case SyncTransportMode.lanDirect:
        return _buildPillBadge(
          icon: Icons.bolt_rounded,
          label: 'LAN DIRECT (< 2ms)',
          color: Colors.green,
        );
      case SyncTransportMode.cloudRelay:
        return _buildPillBadge(
          icon: Icons.cloud_done_rounded,
          label: 'CLOUD RELAY',
          color: colors.primary,
        );
      case SyncTransportMode.discovering:
        return _buildPillBadge(
          icon: Icons.wifi_find_rounded,
          label: 'SCANNING LAN...',
          color: colors.secondary,
        );
      case SyncTransportMode.standalone:
        return _buildPillBadge(
          icon: Icons.wifi_off_rounded,
          label: 'STANDALONE',
          color: colors.onSurfaceVariant,
        );
    }
  }

  Widget _buildPillBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
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
}