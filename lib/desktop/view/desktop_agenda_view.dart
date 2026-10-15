// lib/desktop/view/desktop_agenda_view.dart
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/desktop/cubit/desktop_agenda_cubit.dart';
import 'package:beacon_os/desktop/cubit/desktop_agenda_state.dart';
import 'package:beacon_os/desktop/widgets/agenda/agenda_header.dart';
import 'package:beacon_os/desktop/widgets/agenda/completed_tasks_column.dart';
import 'package:beacon_os/desktop/widgets/agenda/memos_column.dart';
import 'package:beacon_os/desktop/widgets/agenda/pending_tasks_column.dart';
import 'package:beacon_os/desktop/widgets/agenda/quick_task_composer_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';

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
                AgendaHeader(state: state),
                const SizedBox(height: 18),

                // 2. شريط الإدخال السريع بالكيبورد
                const QuickTaskComposerBar(),
                const SizedBox(height: 20),

                // 3. لوحة الأعمدة الثلاثة (Zen Kanban Board)
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // العمود 1: الأولويات النشطة
                      Expanded(
                        child: PendingTasksColumn(tasks: state.pendingTasks),
                      ),
                      const SizedBox(width: 16),

                      // العمود 2: المهام المكتملة
                      Expanded(
                        child: CompletedTasksColumn(tasks: state.completedTasks),
                      ),
                      const SizedBox(width: 16),

                      // العمود 3: المذكرات الصوتية والسريعة
                      Expanded(
                        child: MemosColumn(memos: state.filteredMemos),
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