// lib/desktop/view/desktop_focus_view.dart
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/desktop/focus/cubit/desktop_focus_cubit.dart';
import 'package:beacon_os/desktop/focus/cubit/desktop_focus_state.dart';
import 'package:beacon_os/desktop/focus/widgets/alarms_scheduler_section.dart';
import 'package:beacon_os/desktop/focus/widgets/deep_work_section.dart';
import 'package:beacon_os/desktop/focus/widgets/focus_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';

class DesktopFocusView extends StatelessWidget {
  const DesktopFocusView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DesktopFocusCubit(
        focusAlarmsRepository: context.read<FocusAlarmsRepository>(),
      ),
      child: const _DesktopFocusContent(),
    );
  }
}

class _DesktopFocusContent extends StatelessWidget {
  const _DesktopFocusContent();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return BlocBuilder<DesktopFocusCubit, DesktopFocusState>(
      builder: (context, state) {
        if (state.status == DesktopFocusStatus.loading && state.alarms.isEmpty) {
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
                // 1. Ø±Ø£Ø³ Ø§Ù„ØµÙØ­Ø©: Ø§Ù„Ø¹Ù†Ø§ÙˆÙŠÙ† ÙˆØ§Ù„Ù…Ù‚Ø§ÙŠÙŠØ³ Ø§Ù„Ø³Ø±ÙŠØ¹Ø©
                FocusHeader(state: state),
                const SizedBox(height: 20),

                // 2. Ø§Ù„Ù…Ø­ØªÙˆÙ‰ Ø§Ù„Ù…Ù‚Ø³ÙˆÙ…: Ø§Ù„Ù…Ø¤Ù‚Øª ÙŠØ³Ø§Ø±Ø§Ù‹ + Ø§Ù„Ù…Ù†Ø¨Ù‡Ø§Øª ÙŠÙ…ÙŠÙ†Ø§Ù‹
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Ø§Ù„Ù‚Ø³Ù… Ø§Ù„Ø£ÙŠØ³Ø±: Ù…Ø­Ø±Ùƒ Ø§Ù„Ø¨ÙˆÙ…ÙˆØ¯ÙˆØ±Ùˆ ÙˆØ§Ù„Ø¹Ù…Ù„ Ø§Ù„Ø¹Ù…ÙŠÙ‚
                      Expanded(
                        flex: 5,
                        child: DeepWorkSection(state: state),
                      ),
                      const SizedBox(width: 20),

                      // Ø§Ù„Ù‚Ø³Ù… Ø§Ù„Ø£ÙŠÙ…Ù†: Ø¬Ø¯ÙˆÙ„ ÙˆÙ…Ø²Ø§Ù…Ù†Ø© Ø§Ù„Ù…Ù†Ø¨Ù‡Ø§Øª
                      Expanded(
                        flex: 5,
                        child: AlarmsSchedulerSection(state: state),
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
