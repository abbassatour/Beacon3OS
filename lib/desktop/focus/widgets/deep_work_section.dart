// lib/desktop/focus/widgets/deep_work_section.dart
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outline.withValues(alpha: 0.7)),
      ),
      child: Column(
        children: [
          // عداد المؤقت الرقمي
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.scaffoldBg.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.outline.withValues(alpha: 0.4)),
            ),
            child: Column(
              children: [
                Text(
                  state.isRunning ? 'DEEP WORK CYCLE RUNNING' : 'POMODORO TIMER',
                  style: TextStyle(
                    color: state.isRunning ? colors.primary : colors.onSurfaceVariant,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    state.formattedRemainingTime,
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 56,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -2,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: state.progress,
                    minHeight: 5,
                    backgroundColor: colors.surface,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(height: 16),

                // 🌟 استخدام Wrap لمنع أي طفح في أزرار الفترات
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  runSpacing: 6,
                  children: [15, 25, 45, 60, 90].map((mins) {
                    final isSelected = state.selectedDurationMinutes == mins;
                    return InkWell(
                      onTap: state.isRunning ? null : () => cubit.selectDuration(mins),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // أزرار التحكم
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: state.isRunning ? colors.secondary : colors.primary,
                        foregroundColor: colors.surface,
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: Icon(
                        state.isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        size: 18,
                      ),
                      label: Text(
                        state.isRunning ? 'Pause' : 'Start Focus',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                      onPressed: state.isRunning ? cubit.pauseTimer : cubit.startTimer,
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.onSurface,
                        side: BorderSide(color: colors.outline),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Reset', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      onPressed: cubit.resetTimer,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // سجل الجلسات المكتملة اليوم
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'TODAY COMPLETED SESSIONS (${state.todaySessions.length})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Auto-logged',
                      style: TextStyle(color: colors.onSurfaceVariant, fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: state.todaySessions.isEmpty
                      ? Center(
                          child: Text(
                            'Complete a focus cycle to see your record here.',
                            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11.5),
                          ),
                        )
                      : ListView.builder(
                          itemCount: state.todaySessions.length,
                          itemBuilder: (context, index) {
                            final session = state.todaySessions[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: context.scaffoldBg.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: colors.outline.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        const Icon(Icons.check_circle_rounded, color: Colors.green, size: 15),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '${session.durationMinutes}m Focus Cycle',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: colors.onSurface,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    DateFormat('h:mm a').format(session.completedAt.toLocal()),
                                    style: TextStyle(
                                      color: colors.onSurfaceVariant,
                                      fontSize: 10.5,
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