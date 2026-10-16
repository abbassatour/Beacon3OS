// lib/desktop/view/desktop_agenda_view.dart
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/desktop/agenda/cubit/desktop_agenda_cubit.dart';
import 'package:beacon_os/desktop/agenda/cubit/desktop_agenda_state.dart';
import 'package:beacon_os/desktop/agenda/widgets/agenda_header.dart';
import 'package:beacon_os/desktop/agenda/widgets/completed_tasks_column.dart';
import 'package:beacon_os/desktop/agenda/widgets/memos_column.dart';
import 'package:beacon_os/desktop/agenda/widgets/pending_tasks_column.dart';
import 'package:beacon_os/desktop/agenda/widgets/quick_task_composer_bar.dart';
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
                // 1. Ø±Ø£Ø³ Ø§Ù„ØµÙØ­Ø©: Ø§Ù„Ø¹Ù†ÙˆØ§Ù† ÙˆØ§Ù„Ø¨Ø­Ø« ÙˆØ§Ù„ÙÙ„ØªØ±Ø©
                AgendaHeader(state: state),
                const SizedBox(height: 18),

                // 2. Ø´Ø±ÙŠØ· Ø§Ù„Ø¥Ø¯Ø®Ø§Ù„ Ø§Ù„Ø³Ø±ÙŠØ¹ Ø¨Ø§Ù„ÙƒÙŠØ¨ÙˆØ±Ø¯
                const QuickTaskComposerBar(),
                const SizedBox(height: 20),

                // 3. Ù„ÙˆØ­Ø© Ø§Ù„Ø£Ø¹Ù…Ø¯Ø© Ø§Ù„Ø«Ù„Ø§Ø«Ø© (Zen Kanban Board)
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Ø§Ù„Ø¹Ù…ÙˆØ¯ 1: Ø§Ù„Ø£ÙˆÙ„ÙˆÙŠØ§Øª Ø§Ù„Ù†Ø´Ø·Ø©
                      Expanded(
                        child: PendingTasksColumn(tasks: state.pendingTasks),
                      ),
                      const SizedBox(width: 16),

                      // Ø§Ù„Ø¹Ù…ÙˆØ¯ 2: Ø§Ù„Ù…Ù‡Ø§Ù… Ø§Ù„Ù…ÙƒØªÙ…Ù„Ø©
                      Expanded(
                        child: CompletedTasksColumn(tasks: state.completedTasks),
                      ),
                      const SizedBox(width: 16),

                      // Ø§Ù„Ø¹Ù…ÙˆØ¯ 3: Ø§Ù„Ù…Ø°ÙƒØ±Ø§Øª Ø§Ù„ØµÙˆØªÙŠØ© ÙˆØ§Ù„Ø³Ø±ÙŠØ¹Ø©
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
