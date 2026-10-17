// lib/desktop/agenda/widgets/completed_tasks_column.dart
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/desktop/agenda/cubit/desktop_agenda_cubit.dart';
import 'package:beacon_os/desktop/agenda/widgets/board_column_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:launcher_repository/launcher_repository.dart'; // ✅ الاستيراد النقي

class CompletedTasksColumn extends StatelessWidget {
  const CompletedTasksColumn({required this.tasks, super.key});

  final List<TaskEntity> tasks; // ✅

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cubit = context.read<DesktopAgendaCubit>();

    return BoardColumnContainer(
      title: 'COMPLETED ARCHIVE',
      count: tasks.length,
      icon: Icons.check_circle_rounded,
      accentColor: Colors.green,
      child: tasks.isEmpty
          ? buildEmptyColumnPlaceholder(
              icon: Icons.inbox_rounded,
              message: 'No completed tasks yet.',
              colors: colors,
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final task = tasks[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: colors.surface.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.outline.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: true,
                        activeColor: Colors.green,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        onChanged: (_) => cubit.toggleTask(task),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          task.title,
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 13,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline_rounded, size: 16, color: colors.error),
                        onPressed: () => cubit.deleteTask(task),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}