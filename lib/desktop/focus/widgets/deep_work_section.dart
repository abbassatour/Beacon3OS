import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/desktop/focus/cubit/desktop_focus_cubit.dart';
import 'package:beacon_os/desktop/focus/cubit/desktop_focus_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

class DeepWorkSection extends StatelessWidget {
  const DeepWorkSection({required this.state, super.key});

  final DesktopFocusState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cubit = context.read<DesktopFocusCubit>();

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outline.withValues(alpha: 0.7)),
      ),
      child: Column(
        children: [
          // Ø¹Ø¯Ø§Ø¯ Ø§Ù„Ù…Ø¤Ù‚Øª Ø§Ù„Ø±Ù‚Ù…ÙŠ
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: context.scaffoldBg.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.outline.withValues(alpha: 0.4)),
            ),
            child: Column(
              children: [
                Text(
                  state.isRunning ? 'DEEP WORK CYCLE RUNNING' : 'POMODORO TIMER',
                  style: TextStyle(
                    color: state.isRunning ? colors.primary : colors.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  state.formattedRemainingTime,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 64,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -2,
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: state.progress,
                    minHeight: 6,
                    backgroundColor: colors.surface,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(height: 20),

                // Ø£Ø²Ø±Ø§Ø± ÙØªØ±Ø§Øª Ø§Ù„ØªØ±ÙƒÙŠØ² Ø§Ù„Ø³Ø±ÙŠØ¹Ø©
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [15, 25, 45, 60, 90].map((mins) {
                    final isSelected = state.selectedDurationMinutes == mins;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: InkWell(
                        onTap: state.isRunning ? null : () => cubit.selectDuration(mins),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? colors.primary : colors.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? colors.primary : colors.outline,
                            ),
                          ),
                          child: Text(
                            '${mins}m',
                            style: TextStyle(
                              color: isSelected ? colors.surface : colors.onSurface,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Ø£Ø²Ø±Ø§Ø± Ø§Ù„ØªØ­ÙƒÙ…
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: state.isRunning ? colors.secondary : colors.primary,
                        foregroundColor: colors.surface,
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: Icon(
                        state.isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        size: 20,
                      ),
                      label: Text(
                        state.isRunning ? 'Pause' : 'Start Focus',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                      ),
                      onPressed: state.isRunning ? cubit.pauseTimer : cubit.startTimer,
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.onSurface,
                        side: BorderSide(color: colors.outline),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Reset', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: cubit.resetTimer,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Ø³Ø¬Ù„ Ø§Ù„Ø¬Ù„Ø³Ø§Øª Ø§Ù„Ù…ÙƒØªÙ…Ù„Ø© Ø§Ù„ÙŠÙˆÙ…
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TODAY COMPLETED SESSIONS (${state.todaySessions.length})',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                    Text(
                      'Auto-logged to vault',
                      style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: state.todaySessions.isEmpty
                      ? Center(
                          child: Text(
                            'Complete a focus cycle to see your deep work record here.',
                            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                          ),
                        )
                      : ListView.builder(
                          itemCount: state.todaySessions.length,
                          itemBuilder: (context, index) {
                            final session = state.todaySessions[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: context.scaffoldBg.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: colors.outline.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
                                      const SizedBox(width: 10),
                                      Text(
                                        '${session.durationMinutes} Minutes Focus Cycle',
                                        style: TextStyle(
                                          color: colors.onSurface,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    DateFormat('h:mm a').format(session.completedAt),
                                    style: TextStyle(
                                      color: colors.onSurfaceVariant,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
