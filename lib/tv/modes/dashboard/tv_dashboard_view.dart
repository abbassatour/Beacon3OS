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
          padding: const EdgeInsets.fromLTRB(28, 14, 28, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ===============================================================
              // 1. الشريط الزجاجي العلوي المدمج (Frosted Ambient Header)
              // ===============================================================
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colors.outline.withValues(alpha: 0.35),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // شعار النظام وشارة شاشة غرفة المعيشة
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: colors.primary, width: 1.2),
                      ),
                      child: Icon(
                        Icons.tv_rounded,
                        color: colors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'BEACON OS',
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.8,
                          ),
                        ),
                        Text(
                          'Living Room Command Bridge',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),

                    // شارات الحالة السريعة وفك الارتباط
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TvStatusPill.forTransport(state.transportMode, colors),
                        const SizedBox(width: 8),
                        const TvStatusPill(
                          icon: Icons.verified_rounded,
                          label: 'ARBITRUM L2',
                          color: Colors.green,
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          icon: Icon(
                            Icons.link_off_rounded,
                            color: colors.onSurfaceVariant,
                            size: 18,
                          ),
                          tooltip: 'Unpair this display',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: cubit.unpairDevice,
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),

                    // ساعة التلفاز المدمجة
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
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              periodStr,
                              style: TextStyle(
                                color: colors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          dateStr,
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // ===============================================================
              // 2. شريط التنبيه المباشر في حال الطوارئ أو الرنين
              // ===============================================================
              if (state.hasActiveAlert) ...[
                TvLiveAlertBanner(
                  alert: state.activeAlert!,
                  onDismiss: cubit.dismissActiveAlert,
                ),
                const SizedBox(height: 10),
              ],

              // ===============================================================
              // 3. شبكة البطاقات الأربع المتوازنة (Balanced 2x2 Matrix)
              // ===============================================================
              Expanded(
                child: TvGridFocusScope(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // العمود الأيسر: الرادار الصوتي + استغاثة الطوارئ
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: TvLocatorCard(focusNode: locateCardFocus),
                            ),
                            const SizedBox(height: 10),
                            Expanded(
                              child: TvSafetyCard(focusNode: sosCardFocus),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // العمود الأيمن: أجندة اليوم + المنبه القادم
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: TvAgendaCard(focusNode: agendaFocus),
                            ),
                            const SizedBox(height: 10),
                            Expanded(
                              child: TvAlarmsCard(focusNode: alarmsFocus),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // ===============================================================
              // 4. شريط إرشادات الريموت السفلي المقاوم للطفح
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.40),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colors.outline.withValues(alpha: 0.25),
        ),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildLegendItem(Icons.gamepad_rounded, 'D-PAD', 'Navigate Matrix', colors),
              _buildDivider(colors),
              _buildLegendItem(Icons.radio_button_checked_rounded, 'SELECT', 'Action / Ping / Toggle', colors),
              _buildDivider(colors),
              _buildLegendItem(Icons.arrow_back_rounded, 'BACK', 'Screensaver / Dismiss', colors),
              _buildDivider(colors),
              _buildLegendItem(Icons.wifi_tethering_rounded, 'LAN DIRECT', '< 2ms Local Bridge', colors),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(IconData icon, String keyLabel, String action, ColorScheme colors) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: colors.primary),
        const SizedBox(width: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
          decoration: BoxDecoration(
            color: colors.onSurface.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            keyLabel,
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          action,
          style: TextStyle(
            color: colors.onSurfaceVariant,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider(ColorScheme colors) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      height: 10,
      width: 1,
      color: colors.outline.withValues(alpha: 0.35),
    );
  }
}