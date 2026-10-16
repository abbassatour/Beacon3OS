import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:local_vault_api/local_vault_api.dart';

class DismissibleTaskCard extends StatelessWidget {
  const DismissibleTaskCard({
    required this.task,
    required this.onDismissed,
    required this.onToggle,
    required this.onReadAloud,
    super.key,
  });

  final Task task;
  final VoidCallback onDismissed;
  final VoidCallback onToggle;
  final VoidCallback onReadAloud;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDone = task.isCompleted;

    Color priorityColor = colors.onSurfaceVariant;
    if (task.priority == 'high') priorityColor = colors.error;
    if (task.priority == 'medium') priorityColor = colors.secondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: Key(task.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: colors.error.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.delete_outline_rounded, color: colors.error),
        ),
        onDismissed: (_) => onDismissed(),
        child: Semantics(
          label:
              'Task: ${task.title}. Tap to read, or toggle completion checkbox.',
          button: true,
          child: Material(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onReadAloud,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDone
                        ? colors.outline
                        : priorityColor.withValues(alpha: 0.4),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        isDone
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined,
                        color: isDone
                            ? colors.onSurfaceVariant
                            : priorityColor,
                        size: 24,
                      ),
                      onPressed: onToggle,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (task.priority == 'high' && !isDone)
                                Container(
                                  margin: const EdgeInsets.only(right: 6),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.error.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'HIGH',
                                    style: TextStyle(
                                      color: colors.error,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              Expanded(
                                child: Text(
                                  task.title,
                                  style: TextStyle(
                                    color: isDone
                                        ? colors.onSurfaceVariant
                                        : colors.onSurface,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    decoration: isDone
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (task.dueDate != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              'Due: ${DateFormat('EEE, MMM d • h:mm a').format(task.dueDate!)}',
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.volume_up_rounded,
                        color: colors.primary,
                        size: 20,
                      ),
                      onPressed: onReadAloud,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}