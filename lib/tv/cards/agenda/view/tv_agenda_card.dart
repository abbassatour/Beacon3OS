// lib/tv/cards/agenda/view/tv_agenda_card.dart
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/tv/cards/agenda/cubit/tv_agenda_cubit.dart';
import 'package:beacon_os/tv/cards/agenda/cubit/tv_agenda_state.dart';
import 'package:beacon_os/tv/shared/widgets/tv_focusable_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
          subtitle: 'Press [SELECT] to complete top priority',
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
        child: CircularProgressIndicator(color: colors.secondary, strokeWidth: 2.5),
      );
    }

    if (state.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 38),
            const SizedBox(height: 8),
            Text(
              'Zero pending priorities! Agenda is clear.',
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: state.tasks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final task = state.tasks[index];
        final isTop = index == 0;

        Color badgeColor = colors.onSurfaceVariant;
        if (task.priority == 'high') badgeColor = colors.error;
        if (task.priority == 'medium') badgeColor = colors.secondary;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isTop
                ? colors.primary.withValues(alpha: 0.08)
                : context.scaffoldBg.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isTop
                  ? colors.primary.withValues(alpha: 0.35)
                  : colors.outline.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.radio_button_unchecked_rounded,
                size: 20,
                color: isTop ? colors.primary : colors.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 15,
                    fontWeight: isTop ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  task.priority.toUpperCase(),
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}