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
          subtitle: 'Press [SELECT] to toggle completion',
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
          strokeWidth: 2,
        ),
      );
    }

    if (state.isEmpty) {
      return Center(
        child: Text(
          'Zero pending priorities! Agenda clear.',
          style: TextStyle(
            color: colors.onSurfaceVariant,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: state.tasks.length,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final task = state.tasks[index];
        return InkWell(
          onTap: () => cubit.toggleTaskCompletion(task),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: context.scaffoldBg.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: colors.outline.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.radio_button_unchecked_rounded,
                  size: 16,
                  color: colors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: colors.secondary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    task.priority.toUpperCase(),
                    style: TextStyle(
                      color: colors.secondary,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
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