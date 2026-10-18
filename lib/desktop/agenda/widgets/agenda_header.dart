// lib/desktop/agenda/widgets/agenda_header.dart
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/desktop/agenda/cubit/desktop_agenda_cubit.dart';
import 'package:beacon_os/desktop/agenda/cubit/desktop_agenda_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AgendaHeader extends StatelessWidget {
  const AgendaHeader({required this.state, super.key});

  final DesktopAgendaState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cubit = context.read<DesktopAgendaCubit>();

    return Row(
      children: [
        // 🌟 جعل العنوان والوصف مرنين لمنع طفح الـ 376 بيكسل
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    color: colors.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'AGENDA & ZEN TASK BOARD',
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
                'Keyboard-driven priority board, real-time sync with mobile phonebook & alarms.',
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
        // أدوات الفلترة والبحث في اليمين بحجم متكيف
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 200,
              height: 38,
              child: TextField(
                onChanged: cubit.setSearchQuery,
                decoration: InputDecoration(
                  hintText: 'Search tasks or notes...',
                  hintStyle: TextStyle(
                    color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: colors.onSurfaceVariant,
                  ),
                  filled: true,
                  fillColor: colors.surface,
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: colors.outline.withValues(alpha: 0.6),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: colors.outline.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: colors.outline.withValues(alpha: 0.6),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: state.priorityFilter,
                  dropdownColor: colors.surface,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Filter: All')),
                    DropdownMenuItem(value: 'high', child: Text('High Priority')),
                    DropdownMenuItem(value: 'medium', child: Text('Medium Priority')),
                    DropdownMenuItem(value: 'low', child: Text('Low Priority')),
                  ],
                  onChanged: (val) {
                    if (val != null) cubit.setPriorityFilter(val);
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}