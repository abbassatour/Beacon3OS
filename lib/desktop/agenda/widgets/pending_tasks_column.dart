import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/desktop/agenda/cubit/desktop_agenda_cubit.dart';
import 'package:beacon_os/desktop/agenda/widgets/board_column_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:local_vault_api/local_vault_api.dart';

class PendingTasksColumn extends StatelessWidget {
  const PendingTasksColumn({required this.tasks, super.key});

  final List<Task> tasks;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cubit = context.read<DesktopAgendaCubit>();

    return BoardColumnContainer(
      title: 'PENDING PRIORITIES',
      count: tasks.length,
      icon: Icons.radio_button_unchecked_rounded,
      accentColor: colors.primary,
      child: tasks.isEmpty
          ? buildEmptyColumnPlaceholder(
              icon: Icons.check_circle_outline_rounded,
              message: 'Zero pending tasks! Your agenda is clear.',
              colors: colors,
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final task = tasks[index];
                return _buildTaskCard(context, task, cubit, colors);
              },
            ),
    );
  }

  Widget _buildTaskCard(
    BuildContext context,
    Task task,
    DesktopAgendaCubit cubit,
    ColorScheme colors,
  ) {
    Color badgeColor = colors.onSurfaceVariant;
    if (task.priority == 'high') badgeColor = colors.error;
    if (task.priority == 'medium') badgeColor = colors.secondary;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outline.withValues(alpha: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: task.isCompleted,
            activeColor: colors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            onChanged: (_) => cubit.toggleTask(task),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        task.priority.toUpperCase(),
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (task.dueDate != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        'Due: ${DateFormat('MMM d, h:mm a').format(task.dueDate!)}',
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  task.title,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, size: 16, color: colors.onSurfaceVariant),
            onSelected: (action) {
              if (action == 'delete') {
                cubit.deleteTask(task);
              } else {
                cubit.updateTaskPriority(task, action);
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'high', child: Text('Set High Priority')),
              const PopupMenuItem(value: 'medium', child: Text('Set Medium Priority')),
              const PopupMenuItem(value: 'low', child: Text('Set Low Priority')),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'delete',
                child: Text('ðŸ—‘ï¸ Delete Task', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
