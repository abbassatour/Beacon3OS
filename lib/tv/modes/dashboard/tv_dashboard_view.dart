// lib/tv/modes/dashboard/tv_dashboard_view.dart
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/tv/cards/agenda/view/tv_agenda_card.dart';
import 'package:beacon_os/tv/cards/alarms/view/tv_alarms_card.dart';
import 'package:beacon_os/tv/cards/locator/view/tv_locator_card.dart';
import 'package:beacon_os/tv/cards/safety/view/tv_safety_card.dart';
import 'package:beacon_os/tv/shared/tv_focus_policy.dart';
import 'package:beacon_os/tv/shared/widgets/tv_live_alert_banner.dart';
import 'package:beacon_os/tv/shared/widgets/tv_status_pill.dart';
import 'package:beacon_os/tv/shell/cubit/tv_shell_cubit.dart';
import 'package:beacon_os/tv/shell/cubit/tv_shell_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

class TvDashboardView extends StatelessWidget {
  const TvDashboardView({
    required this.locateCardFocus,
    required this.sosCardFocus,
    required this.agendaFocus,
    required this.alarmsFocus,
    super.key,
  });

  final FocusNode locateCardFocus;
  final FocusNode sosCardFocus;
  final FocusNode agendaFocus;
  final FocusNode alarmsFocus;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cubit = context.read<TvShellCubit>();

    return BlocBuilder<TvShellCubit, TvShellState>(
      builder: (context, state) {
        final timeStr = DateFormat('h:mm').format(state.currentTime);
        final periodStr = DateFormat('a').format(state.currentTime);
        final dateStr = DateFormat('EEEE, MMMM d').format(state.currentTime);

        return Padding(
          key: const ValueKey('tv_active_dashboard'),
          padding: const EdgeInsets.fromLTRB(36, 20, 36, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ===============================================================
              // 1. الشريط الزجاجي العلوي (Cinematic Frosted Header Bar)
              // ===============================================================
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: 0.70),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: colors.outline.withValues(alpha: 0.5),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // شعار النظام وهوية الشاشة
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: colors.primary, width: 1.5),
                      ),
                      child: Icon(Icons.tv_rounded, color: colors.primary, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'BEACON OS',
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                          ),
                        ),
                        Text(
                          'Living Room Command Bridge',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),

                    // شارات الحالة السريعة
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TvStatusPill.forTransport(state.transportMode, colors),
                        const SizedBox(width: 10),
                        TvStatusPill(
                          icon: Icons.verified_rounded,
                          label: 'ARBITRUM L2',
                          color: Colors.green,
                        ),
                        const SizedBox(width: 10),
                        IconButton(
                          icon: Icon(
                            Icons.link_off_rounded,
                            color: colors.onSurfaceVariant,
                            size: 20,
                          ),
                          tooltip: 'Unpair this display',
                          onPressed: cubit.unpairDevice,
                        ),
                      ],
                    ),
                    const SizedBox(width: 20),

                    // ساعة التلفاز العريضة
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
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
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              periodStr,
                              style: TextStyle(
                                color: colors.primary,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
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
              ),
              const SizedBox(height: 14),

              // ===============================================================
              // 2. شريط التنبيه المباشر في حال الطوارئ أو الرنين
              // ===============================================================
              if (state.hasActiveAlert) ...[
                TvLiveAlertBanner(
                  alert: state.activeAlert!,
                  onDismiss: cubit.dismissActiveAlert,
                ),
                const SizedBox(height: 12),
              ],

              // ===============================================================
              // 3. شبكة البطاقات الأربع (2x2 Matrix)
              // ===============================================================
              Expanded(
                child: TvGridFocusScope(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // العمود الأيسر: الرادار الصوتي + استغاثة الطوارئ
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              flex: 6,
                              child: TvLocatorCard(focusNode: locateCardFocus),
                            ),
                            const SizedBox(height: 14),
                            Expanded(
                              flex: 4,
                              child: TvSafetyCard(focusNode: sosCardFocus),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),

                      // العمود الأيمن: أجندة اليوم + المنبه القادم
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              flex: 6,
                              child: TvAgendaCard(focusNode: agendaFocus),
                            ),
                            const SizedBox(height: 14),
                            Expanded(
                              flex: 4,
                              child: TvAlarmsCard(focusNode: alarmsFocus),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ===============================================================
              // 4. شريط إرشادات الريموت السفلي (Remote Navigation Legend)
              // ===============================================================
              _buildRemoteLegendBar(colors),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRemoteLegendBar(ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colors.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildLegendItem(Icons.gamepad_rounded, 'D-PAD', 'Navigate Matrix', colors),
          _buildDivider(colors),
          _buildLegendItem(Icons.radio_button_checked_rounded, 'SELECT', 'Action / Ping / Toggle', colors),
          _buildDivider(colors),
          _buildLegendItem(Icons.arrow_back_rounded, 'BACK', 'Screensaver / Dismiss Alert', colors),
          _buildDivider(colors),
          _buildLegendItem(Icons.wifi_tethering_rounded, 'LAN P2P', '< 2ms Ultra-Low Latency', colors),
        ],
      ),
    );
  }

  Widget _buildLegendItem(IconData icon, String keyLabel, String action, ColorScheme colors) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: colors.primary),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: colors.onSurface.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            keyLabel,
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          action,
          style: TextStyle(
            color: colors.onSurfaceVariant,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider(ColorScheme colors) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      height: 12,
      width: 1,
      color: colors.outline.withValues(alpha: 0.4),
    );
  }
}