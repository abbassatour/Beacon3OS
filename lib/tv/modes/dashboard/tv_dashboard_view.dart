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
        final timeStr = DateFormat('h:mm a').format(state.currentTime);
        final dateStr = DateFormat('EEE, MMM d').format(state.currentTime);

        return Padding(
          key: const ValueKey('tv_active_dashboard'),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. شريط رأس الشاشة (Top Status Header)
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: colors.primary, width: 1.8),
                          ),
                          child: Icon(
                            Icons.tv_rounded,
                            color: colors.primary,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
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
                                  fontSize: 22, // 👈 وضوح عنوان النظام
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.8,
                                ),
                              ),
                              Text(
                                'Living Room Bridge • Linked',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                  fontSize: 14, // 👈 خط مريح
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TvStatusPill.forTransport(state.transportMode, colors),
                      const SizedBox(width: 10),
                      TvStatusPill(
                        icon: Icons.verified_rounded,
                        label: 'ARBITRUM L2',
                        color: colors.primary,
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: Icon(
                          Icons.link_off_rounded,
                          color: colors.onSurfaceVariant,
                          size: 22,
                        ),
                        tooltip: 'Unpair this display',
                        onPressed: cubit.unpairDevice,
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            timeStr,
                            style: TextStyle(
                              color: colors.onSurface,
                              fontSize: 30, // 👈 ساعة علوية عريضة ومقروءة
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            dateStr,
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 14.5, // 👈 تاريخ واضح
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 2. شريط التنبيه اللحظي المنبثق للطوارئ والـ Ping
              if (state.hasActiveAlert) ...[
                TvLiveAlertBanner(
                  alert: state.activeAlert!,
                  onDismiss: cubit.dismissActiveAlert,
                ),
                const SizedBox(height: 14),
              ],

              // 3. شبكة الـ 2x2 المعيارية المحكومة بسياسة الفوكس الحتمية
              Expanded(
                child: TvGridFocusScope(
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
                              child: TvLocatorCard(focusNode: locateCardFocus),
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              flex: 4,
                              child: TvSafetyCard(focusNode: sosCardFocus),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              flex: 6,
                              child: TvAgendaCard(focusNode: agendaFocus),
                            ),
                            const SizedBox(height: 16),
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
            ],
          ),
        );
      },
    );
  }
}