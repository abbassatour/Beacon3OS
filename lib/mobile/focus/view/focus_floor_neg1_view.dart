// lib/mobile/focus/view/focus_floor_neg1_view.dart
import 'package:beacon_os/core/audio/sound_controller.dart';
import 'package:beacon_os/core/audio/sound_cue.dart';
import 'package:beacon_os/core/haptics/haptic_manager.dart';
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/mobile/shell/spatial_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:launcher_repository/launcher_repository.dart';

/// واجهة الطابق السفلي لغرفة التركيز (Floor -1: Focus Analytics & Deep Work Archive)
class FocusFloorNeg1View extends StatelessWidget {
  const FocusFloorNeg1View({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final focusRepo = context.read<FocusAlarmsRepository>();
    final assistant = context.read<AssistantRepository>();
    final shellCubit = context.read<SpatialShellCubit>();

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        child: CustomScrollView(
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
                              Icons.analytics_rounded,
                              color: colors.primary,
                              size: 26,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'DEEP WORK ARCHIVE',
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
                          tooltip: 'Ascend to Ground Floor (Focus)',
                          onPressed: shellCubit.returnToGroundFloor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Floor -1 • Historical Pomodoro intervals, total hours focused & deep work analytics.',
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
            // 2. بطاقة ملخص الإنجاز التاريخي الشامل
            // ==========================================
            StreamBuilder<List<FocusSessionEntity>>(
              stream: focusRepo.watchAllFocusSessions(),
              builder: (context, snapshot) {
                final sessions = snapshot.data ?? [];
                final totalMinutes = sessions.fold<int>(0, (sum, s) => sum + s.durationMinutes);
                final totalHours = (totalMinutes / 60).toStringAsFixed(1);
                final averageCycle = sessions.isNotEmpty ? (totalMinutes / sessions.length).round() : 0;

                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: colors.primary.withValues(alpha: 0.5), width: 1.5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatColumn(
                            label: 'LIFETIME HOURS',
                            value: '${totalHours}h',
                            color: colors.primary,
                          ),
                          Container(
                            height: 36,
                            width: 1.2,
                            color: colors.outline.withValues(alpha: 0.6),
                          ),
                          _buildStatColumn(
                            label: 'TOTAL CYCLES',
                            value: '${sessions.length}',
                            color: Colors.green,
                          ),
                          Container(
                            height: 36,
                            width: 1.2,
                            color: colors.outline.withValues(alpha: 0.6),
                          ),
                          _buildStatColumn(
                            label: 'AVG INTERVAL',
                            value: '${averageCycle}m',
                            color: colors.secondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            // ==========================================
            // 3. سجل الجلسات المكتملة تاريخياً (Timeline Log)
            // ==========================================
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'COMPLETED SESSIONS TIMELINE',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                    Icon(Icons.history_toggle_off_rounded, size: 16, color: colors.onSurfaceVariant),
                  ],
                ),
              ),
            ),
            StreamBuilder<List<FocusSessionEntity>>(
              stream: focusRepo.watchAllFocusSessions(),
              builder: (context, snapshot) {
                final sessions = snapshot.data ?? [];

                if (sessions.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: colors.outline),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.hourglass_empty_rounded, size: 36, color: colors.primary),
                            const SizedBox(height: 10),
                            Text(
                              'No Completed Focus Sessions Yet',
                              style: TextStyle(
                                color: colors.onSurface,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Complete Pomodoro cycles on Floor 0 to populate your long-term focus archive here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final session = sessions[index];
                        final dateStr = DateFormat('EEEE, MMM d, yyyy').format(session.completedAt.toLocal());
                        final timeStr = DateFormat('h:mm a').format(session.completedAt.toLocal());

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Material(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () async {
                                HapticManager.instance.selectionClick();
                                await SoundController.instance.play(SoundCue.navCenter);
                                await assistant.speak(
                                  '${session.durationMinutes} minutes deep work completed on $dateStr at $timeStr.',
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: colors.outline.withValues(alpha: 0.6)),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: colors.primary.withValues(alpha: 0.12),
                                      child: Icon(Icons.check_rounded, color: colors.primary, size: 18),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${session.durationMinutes} Minutes Focus Cycle',
                                            style: TextStyle(
                                              color: colors.onSurface,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '$dateStr • $timeStr',
                                            style: TextStyle(
                                              color: colors.onSurfaceVariant,
                                              fontSize: 11.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.volume_up_rounded, color: colors.primary, size: 20),
                                      tooltip: 'Read Aloud',
                                      onPressed: () async {
                                        await assistant.speak(
                                          'Focus cycle of ${session.durationMinutes} minutes recorded on $dateStr.',
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: sessions.length,
                    ),
                  ),
                );
              },
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 60)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn({
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
        const SizedBox(height: 3),
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
}