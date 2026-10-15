// lib/agenda/view/agenda_floor_0_view.dart
import 'package:beacon_os/agenda/cubit/agenda_cubit.dart';
import 'package:beacon_os/agenda/cubit/agenda_state.dart';
import 'package:beacon_os/agenda/widgets/add_memo_dialog.dart';
import 'package:beacon_os/agenda/widgets/add_task_dialog.dart';
import 'package:beacon_os/agenda/widgets/dismissible_memo_card.dart';
import 'package:beacon_os/agenda/widgets/dismissible_task_card.dart';
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/spatial_shell/spatial_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';

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
                                  onPressed: () => _showAddMemo(context, cubit),
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
                                  onPressed: () => _showAddTask(context, cubit),
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
                        (context, index) {
                          final task = state.pendingTasks[index];
                          return DismissibleTaskCard(
                            task: task,
                            onDismissed: () => cubit.deleteTask(task),
                            onToggle: () => cubit.toggleTask(task),
                            onReadAloud: () => cubit.readTaskAloud(task),
                          );
                        },
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
                        (context, index) {
                          final memo = state.sortedMemos[index];
                          return DismissibleMemoCard(
                            memo: memo,
                            onDismissed: () => cubit.deleteMemo(memo),
                            onReadAloud: () => cubit.readMemoAloud(memo),
                          );
                        },
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
                        (context, index) {
                          final task = state.completedTasks[index];
                          return DismissibleTaskCard(
                            task: task,
                            onDismissed: () => cubit.deleteTask(task),
                            onToggle: () => cubit.toggleTask(task),
                            onReadAloud: () => cubit.readTaskAloud(task),
                          );
                        },
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

  void _showAddTask(BuildContext context, AgendaCubit cubit) {
    showDialog<void>(
      context: context,
      builder: (_) => AddTaskDialog(
        onSave: ({
          required title,
          required priority,
          dueDate,
        }) {
          cubit.addNewTask(
            title: title,
            priority: priority,
            dueDate: dueDate,
          );
        },
      ),
    );
  }

  void _showAddMemo(BuildContext context, AgendaCubit cubit) {
    showDialog<void>(
      context: context,
      builder: (_) => AddMemoDialog(
        onSave: ({
          required title,
          required content,
        }) {
          cubit.addNewMemo(
            title: title,
            content: content,
          );
        },
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

// 🛡️ أسماء توافقية لمنع أي تعطل أثناء فترة الترحيل
typedef AgendaView = AgendaFloor0StandaloneView;
typedef AgendaContentView = AgendaFloor0View;