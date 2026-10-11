// lib/agenda/view/agenda_floor_0_view.dart
import 'package:beacon_os/agenda/cubit/agenda_cubit.dart';
import 'package:beacon_os/agenda/cubit/agenda_state.dart';
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/spatial_shell/spatial_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:launcher_repository/launcher_repository.dart';
import 'package:local_vault_api/local_vault_api.dart';

/// واجهة الطابق الأرضي للأجندة (Floor 0: Day Tasks & Voice Notes)
class AgendaFloor0View extends StatelessWidget {
  const AgendaFloor0View({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final returnHint = CompassDirection.west.returnGestureHint;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        child: BlocBuilder<AgendaCubit, AgendaState>(
          builder: (context, state) {
            final cubit = context.read<AgendaCubit>();

            if (state.status == AgendaStatus.loading) {
              return Center(
                child: CircularProgressIndicator(color: colors.primary),
              );
            }

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 60, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'AGENDA & TASKS',
                              style: TextStyle(
                                color: colors.onSurface,
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                            Row(
                              children: [
                                IconButton.filledTonal(
                                  style: IconButton.styleFrom(
                                    backgroundColor: colors.surface,
                                    foregroundColor: colors.onSurface,
                                    side: BorderSide(color: colors.outline),
                                  ),
                                  icon: const Icon(Icons.note_add_rounded),
                                  tooltip: 'Add Note',
                                  onPressed: () =>
                                      _showAddMemoDialog(context, cubit),
                                ),
                                const SizedBox(width: 8),
                                IconButton.filledTonal(
                                  style: IconButton.styleFrom(
                                    backgroundColor: colors.surface,
                                    foregroundColor: colors.onSurface,
                                    side: BorderSide(color: colors.outline),
                                  ),
                                  icon: const Icon(Icons.add_task_rounded),
                                  tooltip: 'Add Task',
                                  onPressed: () =>
                                      _showAddTaskDialog(context, cubit),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$returnHint or double-tap to return to Cockpit.',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.radio_button_unchecked_rounded,
                          color: colors.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'PENDING PRIORITIES (${state.pendingTasks.length})',
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (state.pendingTasks.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: colors.outline),
                        ),
                        child: Text(
                          'Your agenda is clear with zero pending tasks. Tap + to add one.',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildDismissibleTaskCard(
                          context,
                          state.pendingTasks[index],
                          cubit,
                        ),
                        childCount: state.pendingTasks.length,
                      ),
                    ),
                  ),
                if (state.sortedMemos.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.mic_none_rounded,
                                color: colors.secondary,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'VOICE & AI NOTES (${state.sortedMemos.length})',
                                style: TextStyle(
                                  color: colors.onSurface,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Swipe left to delete',
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildDismissibleMemoCard(
                          context,
                          state.sortedMemos[index],
                          cubit,
                        ),
                        childCount: state.sortedMemos.length,
                      ),
                    ),
                  ),
                ],
                if (state.completedTasks.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            color: colors.onSurfaceVariant,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'COMPLETED (${state.completedTasks.length})',
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildDismissibleTaskCard(
                          context,
                          state.completedTasks[index],
                          cubit,
                        ),
                        childCount: state.completedTasks.length,
                      ),
                    ),
                  ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 60)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDismissibleTaskCard(
    BuildContext context,
    Task task,
    AgendaCubit cubit,
  ) {
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
        onDismissed: (_) => cubit.deleteTask(task),
        child: Semantics(
          label:
              'Task: ${task.title}. Tap to read, or toggle completion checkbox.',
          button: true,
          child: Material(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => cubit.readTaskAloud(task),
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
                      onPressed: () => cubit.toggleTask(task),
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
                      onPressed: () => cubit.readTaskAloud(task),
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

  Widget _buildDismissibleMemoCard(
    BuildContext context,
    VoiceMemo memo,
    AgendaCubit cubit,
  ) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: Key(memo.id),
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
        onDismissed: (_) => cubit.deleteMemo(memo),
        child: Semantics(
          label: 'Note titled ${memo.title}. Tap to listen.',
          button: true,
          child: Material(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => cubit.readMemoAloud(memo),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.outline, width: 1.2),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor:
                          colors.secondary.withValues(alpha: 0.15),
                      child: Icon(
                        Icons.notes_rounded,
                        color: colors.secondary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            memo.title,
                            style: TextStyle(
                              color: colors.onSurface,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            memo.content,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.volume_up_rounded,
                      color: colors.primary,
                      size: 20,
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

  void _showAddTaskDialog(BuildContext context, AgendaCubit cubit) {
    final colors = context.colors;
    final titleController = TextEditingController();
    String priority = 'medium';
    DateTime? selectedDateTime;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: colors.outline, width: 1.5),
          ),
          title: Text(
            'New Task',
            style: TextStyle(
              color: colors.onSurface,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  autofocus: true,
                  style: TextStyle(color: colors.onSurface),
                  decoration: InputDecoration(
                    labelText: 'Task title...',
                    labelStyle: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: priority,
                  dropdownColor: colors.surface,
                  style: TextStyle(color: colors.onSurface),
                  decoration: InputDecoration(
                    labelText: 'Priority',
                    labelStyle: TextStyle(color: colors.onSurfaceVariant),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'high',
                      child: Text('High Priority 🔴'),
                    ),
                    DropdownMenuItem(
                      value: 'medium',
                      child: Text('Medium Priority 🟡'),
                    ),
                    DropdownMenuItem(
                      value: 'low',
                      child: Text('Low Priority ⚪'),
                    ),
                  ],
                  onChanged: (val) =>
                      setDialogState(() => priority = val ?? 'medium'),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: colors.outline),
                    foregroundColor: colors.onSurface,
                    minimumSize: const Size(double.infinity, 44),
                  ),
                  icon: Icon(
                    Icons.event_rounded,
                    size: 18,
                    color: colors.primary,
                  ),
                  label: Text(
                    selectedDateTime == null
                        ? 'Set Deadline (Optional)'
                        : 'Due: ${DateFormat('MMM d • h:mm a').format(selectedDateTime!)}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null && context.mounted) {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (time != null) {
                        setDialogState(() {
                          selectedDateTime = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                final text = titleController.text.trim();
                if (text.isNotEmpty) {
                  cubit.addNewTask(
                    title: text,
                    priority: priority,
                    dueDate: selectedDateTime,
                  );
                  Navigator.of(ctx).pop();
                }
              },
              child: const Text(
                'Create Task',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddMemoDialog(BuildContext context, AgendaCubit cubit) {
    final colors = context.colors;
    final titleController = TextEditingController();
    final contentController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colors.outline, width: 1.5),
        ),
        title: Text(
          'New Voice / Quick Note',
          style: TextStyle(
            color: colors.onSurface,
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                style: TextStyle(color: colors.onSurface),
                decoration: InputDecoration(
                  labelText: 'Title (e.g. Ideas, Project memo)...',
                  labelStyle: TextStyle(color: colors.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentController,
                maxLines: 4,
                style: TextStyle(color: colors.onSurface),
                decoration: InputDecoration(
                  labelText: 'Note content...',
                  labelStyle: TextStyle(color: colors.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.secondary,
              foregroundColor: colors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              final title = titleController.text.trim();
              final content = contentController.text.trim();
              if (title.isNotEmpty || content.isNotEmpty) {
                cubit.addNewMemo(
                  title: title.isEmpty ? 'Untitled Note' : title,
                  content: content.isEmpty ? title : content,
                );
                Navigator.of(ctx).pop();
              }
            },
            child: const Text(
              'Save Note',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

/// Standalone Wrapper (مفيد للاختبارات المعزولة أو التوجيه المستقل)
class AgendaFloor0StandaloneView extends StatelessWidget {
  const AgendaFloor0StandaloneView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AgendaCubit(
        taskRepository: context.read<TaskAgendaRepository>(),
        assistantRepository: context.read<AssistantRepository>(),
        settingsRepository: context.read<SettingsRepository>(),
      ),
      child: const AgendaFloor0View(),
    );
  }
}

// ===========================================================================
// 🛡️ أسماء توافقية لمنع أي تعطل أثناء فترة الترحيل
// ===========================================================================
typedef AgendaView = AgendaFloor0StandaloneView;
typedef AgendaContentView = AgendaFloor0View;