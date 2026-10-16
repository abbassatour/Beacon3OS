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
          subtitle: 'Synchronized with Android Clock',
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
          strokeWidth: 2,
        ),
      );
    }

    if (!state.hasUpcomingAlarm) {
      return Center(
        child: Text(
          'No active alarms scheduled.',
          style: TextStyle(
            color: colors.onSurfaceVariant,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    final next = state.nextAlarm!;
    final hour12 = next.hour % 12 == 0 ? 12 : next.hour % 12;
    final period = next.hour >= 12 ? 'PM' : 'AM';
    final minStr = next.minute.toString().padLeft(2, '0');

    return InkWell(
      onTap: () => cubit.toggleAlarm(next),
      borderRadius: BorderRadius.circular(12),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$hour12:$minStr $period',
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.primary, width: 1.2),
              ),
              child: Text(
                next.label,
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}