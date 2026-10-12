// lib/desktop/view/desktop_agenda_view.dart
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/desktop/cubit/desktop_agenda_cubit.dart';
import 'package:beacon_os/desktop/cubit/desktop_agenda_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:launcher_repository/launcher_repository.dart';
import 'package:local_vault_api/local_vault_api.dart';

class DesktopAgendaView extends StatelessWidget {
  const DesktopAgendaView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DesktopAgendaCubit(
        taskRepository: context.read<TaskAgendaRepository>(),
      ),
      child: const _DesktopAgendaContent(),
    );
  }
}

class _DesktopAgendaContent extends StatelessWidget {
  const _DesktopAgendaContent();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return BlocBuilder<DesktopAgendaCubit, DesktopAgendaState>(
      builder: (context, state) {
        if (state.status == DesktopAgendaStatus.loading && state.tasks.isEmpty) {
          return Center(
            child: CircularProgressIndicator(color: colors.primary),
          );
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. رأس الصفحة: العنوان والبحث والفلترة
                _AgendaHeader(state: state),
                const SizedBox(height: 18),

                // 2. شريط الإدخال السريع بالكيبورد
                const _QuickTaskComposerBar(),
                const SizedBox(height: 20),

                // 3. لوحة الأعمدة الثلاثة (Zen Kanban Board)
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // العمود 1: الأولويات النشطة
                      Expanded(
                        child: _PendingTasksColumn(tasks: state.pendingTasks),
                      ),
                      const SizedBox(width: 16),

                      // العمود 2: المهام المكتملة
                      Expanded(
                        child: _CompletedTasksColumn(tasks: state.completedTasks),
                      ),
                      const SizedBox(width: 16),

                      // العمود 3: المذكرات الصوتية والسريعة
                      Expanded(
                        child: _MemosColumn(memos: state.filteredMemos),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AgendaHeader extends StatelessWidget {
  const _AgendaHeader({required this.state});

  final DesktopAgendaState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cubit = context.read<DesktopAgendaCubit>();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today_rounded, color: colors.primary, size: 24),
                const SizedBox(width: 10),
                Text(
                  'AGENDA & ZEN TASK BOARD',
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
              'Keyboard-driven priority board, real-time sync with mobile phonebook & alarms.',
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
        Row(
          children: [
            // حقل البحث اللحظي
            SizedBox(
              width: 240,
              height: 40,
              child: TextField(
                onChanged: cubit.setSearchQuery,
                decoration: InputDecoration(
                  hintText: 'Search tasks or notes...',
                  hintStyle: TextStyle(
                    color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                  prefixIcon: Icon(Icons.search_rounded, size: 18, color: colors.onSurfaceVariant),
                  filled: true,
                  fillColor: colors.surface,
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: colors.outline.withValues(alpha: 0.6)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: colors.outline.withValues(alpha: 0.6)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // فلتر الأولويات
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.outline.withValues(alpha: 0.6)),
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
                    DropdownMenuItem(value: 'high', child: Text('🔴 High Priority')),
                    DropdownMenuItem(value: 'medium', child: Text('🟡 Medium Priority')),
                    DropdownMenuItem(value: 'low', child: Text('⚪ Low Priority')),
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

class _QuickTaskComposerBar extends StatefulWidget {
  const _QuickTaskComposerBar();

  @override
  State<_QuickTaskComposerBar> createState() => _QuickTaskComposerBarState();
}

class _QuickTaskComposerBarState extends State<_QuickTaskComposerBar> {
  final _controller = TextEditingController();
  String _selectedPriority = 'medium';
  DateTime? _selectedDueDate;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    context.read<DesktopAgendaCubit>().addNewTask(
          title: text,
          priority: _selectedPriority,
          dueDate: _selectedDueDate,
        );

    _controller.clear();
    setState(() {
      _selectedDueDate = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outline.withValues(alpha: 0.8)),
      ),
      child: Row(
        children: [
          Icon(Icons.add_task_rounded, color: colors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _controller,
              onSubmitted: (_) => _submit(),
              style: TextStyle(color: colors.onSurface, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Type a priority task and press [Enter] to create...',
                hintStyle: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
                border: InputBorder.none,
              ),
            ),
          ),
          // اختيار الأولوية
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedPriority,
              dropdownColor: colors.surface,
              style: TextStyle(color: colors.onSurface, fontSize: 12, fontWeight: FontWeight.bold),
              items: const [
                DropdownMenuItem(value: 'high', child: Text('🔴 High')),
                DropdownMenuItem(value: 'medium', child: Text('🟡 Medium')),
                DropdownMenuItem(value: 'low', child: Text('⚪ Low')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedPriority = val);
              },
            ),
          ),
          const SizedBox(width: 8),

          // موعد الاستحقاق
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: colors.onSurfaceVariant,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            icon: Icon(
              Icons.event_rounded,
              size: 16,
              color: _selectedDueDate != null ? colors.primary : colors.onSurfaceVariant,
            ),
            label: Text(
              _selectedDueDate == null
                  ? 'Due Date'
                  : DateFormat('MMM d').format(_selectedDueDate!),
              style: TextStyle(
                fontSize: 12,
                color: _selectedDueDate != null ? colors.primary : colors.onSurfaceVariant,
                fontWeight: _selectedDueDate != null ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) {
                setState(() => _selectedDueDate = picked);
              }
            },
          ),
          const SizedBox(width: 8),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.surface,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _submit,
            child: const Text('Add Task', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _PendingTasksColumn extends StatelessWidget {
  const _PendingTasksColumn({required this.tasks});

  final List<Task> tasks;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cubit = context.read<DesktopAgendaCubit>();

    return _BoardColumnContainer(
      title: 'PENDING PRIORITIES',
      count: tasks.length,
      icon: Icons.radio_button_unchecked_rounded,
      accentColor: colors.primary,
      child: tasks.isEmpty
          ? _buildEmptyState(
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
              const PopupMenuItem(value: 'high', child: Text('🔴 Set High Priority')),
              const PopupMenuItem(value: 'medium', child: Text('🟡 Set Medium Priority')),
              const PopupMenuItem(value: 'low', child: Text('⚪ Set Low Priority')),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'delete',
                child: Text('🗑️ Delete Task', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompletedTasksColumn extends StatelessWidget {
  const _CompletedTasksColumn({required this.tasks});

  final List<Task> tasks;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cubit = context.read<DesktopAgendaCubit>();

    return _BoardColumnContainer(
      title: 'COMPLETED ARCHIVE',
      count: tasks.length,
      icon: Icons.check_circle_rounded,
      accentColor: Colors.green,
      child: tasks.isEmpty
          ? _buildEmptyState(
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

class _MemosColumn extends StatelessWidget {
  const _MemosColumn({required this.memos});

  final List<VoiceMemo> memos;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cubit = context.read<DesktopAgendaCubit>();

    return _BoardColumnContainer(
      title: 'VOICE & AI NOTES',
      count: memos.length,
      icon: Icons.notes_rounded,
      accentColor: colors.secondary,
      headerAction: IconButton(
        icon: const Icon(Icons.note_add_rounded, size: 18),
        tooltip: 'New Note',
        onPressed: () => _showAddMemoDialog(context, cubit),
      ),
      child: memos.isEmpty
          ? _buildEmptyState(
              icon: Icons.mic_none_rounded,
              message: 'No voice notes in vault.',
              colors: colors,
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: memos.length,
              itemBuilder: (context, index) {
                final memo = memos[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.outline.withValues(alpha: 0.6)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              memo.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.onSurface,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline_rounded, size: 16, color: colors.error),
                            onPressed: () => cubit.deleteMemo(memo),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        memo.content,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        DateFormat('MMM d, h:mm a').format(memo.createdAt),
                        style: TextStyle(
                          color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  void _showAddMemoDialog(BuildContext context, DesktopAgendaCubit cubit) {
    final colors = context.colors;
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'New Quick Note',
          style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contentCtrl,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Content'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.surface,
            ),
            onPressed: () {
              cubit.addNewMemo(title: titleCtrl.text, content: contentCtrl.text);
              Navigator.of(ctx).pop();
            },
            child: const Text('Save Note'),
          ),
        ],
      ),
    );
  }
}

class _BoardColumnContainer extends StatelessWidget {
  const _BoardColumnContainer({
    required this.title,
    required this.count,
    required this.icon,
    required this.accentColor,
    required this.child,
    this.headerAction,
  });

  final String title;
  final int count;
  final IconData icon;
  final Color accentColor;
  final Widget child;
  final Widget? headerAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      decoration: BoxDecoration(
        color: context.scaffoldBg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outline.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icon, color: accentColor, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '$title ($count)',
                      style: TextStyle(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
                if (headerAction != null) headerAction!,
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

Widget _buildEmptyState({
  required IconData icon,
  required String message,
  required ColorScheme colors,
}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: colors.onSurfaceVariant.withValues(alpha: 0.4), size: 36),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}