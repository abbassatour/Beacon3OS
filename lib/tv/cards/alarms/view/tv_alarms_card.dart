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
          subtitle: 'Synchronized with Native Android Clock',
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
        child: CircularProgressIndicator(color: colors.primary, strokeWidth: 2.5),
      );
    }

    if (!state.hasUpcomingAlarm) {
      return Center(
        child: Text(
          'No active alarms scheduled for today.',
          style: TextStyle(
            color: colors.onSurfaceVariant,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    final next = state.nextAlarm!;
    final hour12 = next.hour % 12 == 0 ? 12 : next.hour % 12;
    final period = next.hour >= 12 ? 'PM' : 'AM';
    final minStr = next.minute.toString().padLeft(2, '0');

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.access_time_filled_rounded, size: 36, color: colors.primary),
        const SizedBox(width: 16),
        Text(
          '$hour12:$minStr',
          style: TextStyle(
            color: colors.onSurface,
            fontSize: 38,
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          period,
          style: TextStyle(
            color: colors.primary,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.primary, width: 1.2),
          ),
          child: Text(
            next.label,
            style: TextStyle(
              color: colors.primary,
              fontWeight: FontWeight.w900,
              fontSize: 13,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}