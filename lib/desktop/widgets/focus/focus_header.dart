import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/desktop/cubit/desktop_focus_state.dart';
import 'package:beacon_os/desktop/widgets/focus/stat_pill.dart';
import 'package:flutter/material.dart';

class FocusHeader extends StatelessWidget {
  const FocusHeader({required this.state, super.key});

  final DesktopFocusState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.hourglass_top_rounded, color: colors.primary, size: 26),
                const SizedBox(width: 10),
                Text(
                  'FOCUS SESSIONS & ALARMS',
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Deep work Pomodoro intervals, daily focus history, and synchronized alarm clock schedule.',
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
        Row(
          children: [
            StatPill(
              icon: Icons.timer_rounded,
              label: 'Today',
              value: '${state.totalFocusMinutesToday}m',
              accentColor: colors.primary,
            ),
            const SizedBox(width: 10),
            StatPill(
              icon: Icons.task_alt_rounded,
              label: 'Cycles',
              value: '${state.todaySessions.length}',
              accentColor: Colors.green,
            ),
            const SizedBox(width: 10),
            StatPill(
              icon: Icons.alarm_rounded,
              label: 'Active Alarms',
              value: '${state.alarms.where((a) => a.isActive).length}',
              accentColor: colors.secondary,
            ),
          ],
        ),
      ],
    );
  }
}