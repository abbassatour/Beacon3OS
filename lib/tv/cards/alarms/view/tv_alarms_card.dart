// lib/tv/cards/alarms/view/tv_alarms_card.dart
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/tv/cards/alarms/cubit/tv_alarms_cubit.dart';
import 'package:beacon_os/tv/cards/alarms/cubit/tv_alarms_state.dart';
import 'package:beacon_os/tv/shared/widgets/tv_focusable_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TvAlarmsCard extends StatelessWidget {
  const TvAlarmsCard({
    required this.focusNode,
    super.key,
  });

  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cubit = context.read<TvAlarmsCubit>();

    return BlocBuilder<TvAlarmsCubit, TvAlarmsState>(
      builder: (context, state) {
        return TvFocusableCard(
          focusNode: focusNode,
          title: 'UPCOMING ALARM',
          icon: Icons.alarm_rounded,
          accentColor: colors.primary,
          onSelect: () {
            if (state.hasUpcomingAlarm) {
              cubit.toggleAlarm(state.nextAlarm!);
            }
          },
          child: _buildBody(context, state, cubit, colors),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    TvAlarmsState state,
    TvAlarmsCubit cubit,
    ColorScheme colors,
  ) {
    if (state.status == TvAlarmsStatus.loading && !state.hasUpcomingAlarm) {
      return Center(
        child: CircularProgressIndicator(
          color: colors.primary,
          strokeWidth: 2.0,
        ),
      );
    }

    if (!state.hasUpcomingAlarm) {
      return Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.alarm_off_rounded,
                size: 20,
                color: colors.onSurfaceVariant.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 8),
              Text(
                'No Active Alarms Scheduled',
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final next = state.nextAlarm!;
    final hour12 = next.hour % 12 == 0 ? 12 : next.hour % 12;
    final period = next.hour >= 12 ? 'PM' : 'AM';
    final minStr = next.minute.toString().padLeft(2, '0');

    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // رمز المنبه
            Icon(
              Icons.access_time_filled_rounded,
              size: 28,
              color: colors.primary,
            ),
            const SizedBox(width: 10),
            // الوقت الرقمي
            Text(
              '$hour12:$minStr',
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              period,
              style: TextStyle(
                color: colors.primary,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 14),
            // شارة اسم المنبه
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.4),
                  width: 1.0,
                ),
              ),
              child: Text(
                next.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}