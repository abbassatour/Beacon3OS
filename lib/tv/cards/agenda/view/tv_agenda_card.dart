// lib/tv/cards/agenda/view/tv_agenda_card.dart
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/tv/cards/agenda/cubit/tv_agenda_cubit.dart';
import 'package:beacon_os/tv/cards/agenda/cubit/tv_agenda_state.dart';
import 'package:beacon_os/tv/shared/widgets/tv_focusable_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';

class TvAgendaCard extends StatelessWidget {
  const TvAgendaCard({
    required this.focusNode,
    super.key,
  });

  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cubit = context.read<TvAgendaCubit>();

    return BlocBuilder<TvAgendaCubit, TvAgendaState>(
      builder: (context, state) {
        return TvFocusableCard(
          focusNode: focusNode,
          title: 'TODAY PRIORITIES',
          subtitle: state.isEmpty ? null : '${state.tasks.length} Pending Tasks',
          icon: Icons.calendar_today_rounded,
          accentColor: colors.secondary,
          onSelect: () {
            if (state.tasks.isNotEmpty) {
              cubit.toggleTaskCompletion(state.tasks.first);
            }
          },
          child: _buildBody(context, state, cubit, colors),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    TvAgendaState state,
    TvAgendaCubit cubit,
    ColorScheme colors,
  ) {
    if (state.isLoading && state.isEmpty) {
      return Center(
        child: CircularProgressIndicator(
          color: colors.secondary,
          strokeWidth: 2.0,
        ),
      );
    }

    if (state.isEmpty) {
      return Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                color: Colors.green.withValues(alpha: 0.8),
                size: 32,
              ),
              const SizedBox(height: 6),
              Text(
                'Zero Pending Priorities',
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Your agenda is clear and zen.',
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // عرض المهمة الأولى بأسلوب بارز ومقروء، مع سرد المهام التالية بشكل مضغوط
    final topTask = state.tasks.first;
    final remainingTasks = state.tasks.skip(1).take(2).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // المهمة الكبرى (Top Priority Hero Item)
            _buildPriorityItem(
              context: context,
              task: topTask,
              isHero: true,
              colors: colors,
            ),

            // المهام الثانوية إن وجدت
            for (final nextTask in remainingTasks) ...[
              const SizedBox(height: 4),
              _buildPriorityItem(
                context: context,
                task: nextTask,
                isHero: false,
                colors: colors,
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildPriorityItem({
    required BuildContext context,
    required TaskEntity task,
    required bool isHero,
    required ColorScheme colors,
  }) {
    Color badgeColor = colors.onSurfaceVariant;
    if (task.priority == 'high') badgeColor = colors.error;
    if (task.priority == 'medium') badgeColor = colors.secondary;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 10,
        vertical: isHero ? 6 : 4,
      ),
      decoration: BoxDecoration(
        color: isHero
            ? colors.secondary.withValues(alpha: 0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isHero
            ? Border.all(
                color: colors.secondary.withValues(alpha: 0.35),
                width: 1.0,
              )
            : null,
      ),
      child: Row(
        children: [
          Icon(
            isHero
                ? Icons.radio_button_unchecked_rounded
                : Icons.circle_outlined,
            size: isHero ? 16 : 12,
            color: isHero ? colors.secondary : colors.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              task.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.onSurface,
                fontSize: isHero ? 13.5 : 12,
                fontWeight: isHero ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: badgeColor.withValues(alpha: 0.4),
                width: 0.8,
              ),
            ),
            child: Text(
              task.priority.toUpperCase(),
              style: TextStyle(
                color: badgeColor,
                fontSize: 8.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}