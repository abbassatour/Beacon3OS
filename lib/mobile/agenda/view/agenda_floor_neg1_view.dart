// lib/mobile/agenda/view/agenda_floor_neg1_view.dart
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/mobile/agenda/cubit/agenda_cubit.dart';
import 'package:beacon_os/mobile/agenda/cubit/agenda_state.dart';
import 'package:beacon_os/mobile/shell/spatial_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:launcher_repository/launcher_repository.dart';

/// واجهة الطابق السفلي للأجندة (Floor -1: Archived Tasks & Notes)
class AgendaFloorNeg1View extends StatelessWidget {
  const AgendaFloorNeg1View({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final shellCubit = context.read<SpatialShellCubit>();

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        child: BlocBuilder<AgendaCubit, AgendaState>(
          builder: (context, state) {
            final cubit = context.read<AgendaCubit>();

            if (state.status == AgendaStatus.loading && state.tasks.isEmpty) {
              return Center(
                child: CircularProgressIndicator(color: colors.primary),
              );
            }

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ==========================================
                // 1. رأس الصفحة والملاحة الفضائية
                // ==========================================
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.inventory_2_rounded,
                                  color: colors.primary,
                                  size: 26,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'ARCHIVED PRIORITIES',
                                  style: TextStyle(
                                    color: colors.onSurface,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                            IconButton.filledTonal(
                              style: IconButton.styleFrom(
                                backgroundColor: colors.surface,
                                foregroundColor: colors.onSurface,
                                side: BorderSide(color: colors.outline),
                              ),
                              icon: const Icon(Icons.arrow_upward_rounded, size: 20),
                              tooltip: 'Ascend to Ground Floor (Agenda)',
                              onPressed: shellCubit.returnToGroundFloor,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Floor -1 • Completed priorities archive, historical memos & restoration.',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ==========================================
                // 2. بطاقة إحصاءات الإنجاز
                // ==========================================
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: colors.outline, width: 1.2),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(
                            label: 'COMPLETED',
                            value: '${state.completedTasks.length}',
                            color: Colors.green,
                          ),
                          Container(
                            height: 30,
                            width: 1,
                            color: colors.outline.withValues(alpha: 0.6),
                          ),
                          _buildStatItem(
                            label: 'VOICE NOTES',
                            value: '${state.memos.length}',
                            color: colors.secondary,
                          ),
                          Container(
                            height: 30,
                            width: 1,
                            color: colors.outline.withValues(alpha: 0.6),
                          ),
                          _buildStatItem(
                            label: 'ACTIVE TODAY',
                            value: '${state.pendingTasks.length}',
                            color: colors.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ==========================================
                // 3. قسم المهام المكتملة تاريخياً
                // ==========================================
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, size: 18, color: Colors.green),
                            const SizedBox(width: 8),
                            Text(
                              'COMPLETED ARCHIVE (${state.completedTasks.length})',
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
                          'Tap undo to restore',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (state.completedTasks.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: colors.outline),
                        ),
                        child: Text(
                          'No completed tasks archived yet. Completed tasks from Floor 0 will be preserved here.',
                          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
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
                          final task = state.completedTasks[index];
                          return _buildArchivedTaskTile(context, task, cubit, colors);
                        },
                        childCount: state.completedTasks.length,
                      ),
                    ),
                  ),

                // ==========================================
                // 4. قسم المذكرات الصوتية المحفوظة
                // ==========================================
                if (state.sortedMemos.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                      child: Row(
                        children: [
                          Icon(Icons.notes_rounded, color: colors.secondary, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'SAVED VOICE MEMOS VAULT (${state.sortedMemos.length})',
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
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final memo = state.sortedMemos[index];
                          return _buildArchivedMemoTile(context, memo, cubit, colors);
                        },
                        childCount: state.sortedMemos.length,
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

  Widget _buildStatItem({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _buildArchivedTaskTile(
    BuildContext context,
    TaskEntity task,
    AgendaCubit cubit,
    ColorScheme colors,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => cubit.readTaskAloud(task),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.outline.withValues(alpha: 0.6)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.green,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Completed • ${DateFormat('MMM d, h:mm a').format(task.updatedAt.toLocal())}',
                        style: TextStyle(
                          color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.undo_rounded, color: colors.primary, size: 20),
                  tooltip: 'Restore to Today',
                  onPressed: () => cubit.toggleTask(task),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded, color: colors.error, size: 18),
                  tooltip: 'Delete Permanently',
                  onPressed: () => cubit.deleteTask(task),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildArchivedMemoTile(
    BuildContext context,
    VoiceMemoEntity memo,
    AgendaCubit cubit,
    ColorScheme colors,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => cubit.readMemoAloud(memo),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.outline.withValues(alpha: 0.6)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: colors.secondary.withValues(alpha: 0.15),
                  child: Icon(Icons.notes_rounded, color: colors.secondary, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        memo.title,
                        style: TextStyle(
                          color: colors.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        memo.content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.volume_up_rounded, color: colors.primary, size: 20),
                  tooltip: 'Read Aloud',
                  onPressed: () => cubit.readMemoAloud(memo),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded, color: colors.error, size: 18),
                  tooltip: 'Delete Note',
                  onPressed: () => cubit.deleteMemo(memo),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// غلاف مستقل لتوفير الـ Cubit تلقائياً في حالة التنقل المباشر
class AgendaFloorNeg1StandaloneView extends StatelessWidget {
  const AgendaFloorNeg1StandaloneView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AgendaCubit(
        taskRepository: context.read<TaskAgendaRepository>(),
        assistantRepository: context.read<AssistantRepository>(),
        settingsRepository: context.read<SettingsRepository>(),
      ),
      child: const AgendaFloorNeg1View(),
    );
  }
}