// lib/desktop/focus/widgets/focus_header.dart
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/desktop/focus/cubit/desktop_focus_state.dart';
import 'package:beacon_os/desktop/focus/widgets/stat_pill.dart';
import 'package:flutter/material.dart';

class FocusHeader extends StatelessWidget {
  const FocusHeader({required this.state, super.key});

  final DesktopFocusState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      children: [
        // 🌟 تغليف عمود العنوان بـ Expanded لمنع طفح الـ 377 بيكسل
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.hourglass_top_rounded,
                    color: colors.primary,
                    size: 26,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'FOCUS SESSIONS & ALARMS',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Deep work Pomodoro intervals, daily focus history, and synchronized alarm clock schedule.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // كبسولات الإحصائيات في شريط مرن لا يضغط على العنوان
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StatPill(
              icon: Icons.timer_rounded,
              label: 'Today',
              value: '${state.totalFocusMinutesToday}m',
              accentColor: colors.primary,
            ),
            const SizedBox(width: 8),
            StatPill(
              icon: Icons.task_alt_rounded,
              label: 'Cycles',
              value: '${state.todaySessions.length}',
              accentColor: Colors.green,
            ),
            const SizedBox(width: 8),
            StatPill(
              icon: Icons.alarm_rounded,
              label: 'Active',
              value: '${state.alarms.where((a) => a.isActive).length}',
              accentColor: colors.secondary,
            ),
          ],
        ),
      ],
    );
  }
}