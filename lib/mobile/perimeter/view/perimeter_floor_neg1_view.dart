// lib/mobile/perimeter/view/perimeter_floor_neg1_view.dart
import 'package:beacon_os/core/audio/sound_controller.dart';
import 'package:beacon_os/core/audio/sound_cue.dart';
import 'package:beacon_os/core/haptics/haptic_manager.dart';
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/mobile/shell/spatial_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:launcher_repository/launcher_repository.dart';

/// واجهة الطابق السفلي للمحيط الأمني (Floor -1: Perimeter Activity Archive & Security Log)
class PerimeterFloorNeg1View extends StatefulWidget {
  const PerimeterFloorNeg1View({super.key});

  @override
  State<PerimeterFloorNeg1View> createState() => _PerimeterFloorNeg1ViewState();
}

class _PerimeterFloorNeg1ViewState extends State<PerimeterFloorNeg1View> {
  String _selectedFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ringRepo = context.read<LauncherRepository>().ring;
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
                              Icons.security_rounded,
                              color: colors.primary,
                              size: 26,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'PERIMETER ARCHIVE',
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
                          tooltip: 'Ascend to Ground Floor (Perimeter)',
                          onPressed: shellCubit.returnToGroundFloor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Floor -1 • Historical doorbell dings, motion captures & Gemini 2.0 scene descriptions.',
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
            // 2. بطاقة إحصائيات الأحداث الأمنية
            // ==========================================
            StreamBuilder<List<RingEventEntity>>(
              stream: ringRepo.watchRecentEvents(limit: 50),
              builder: (context, snapshot) {
                final events = snapshot.data ?? [];
                final dingCount = events.where((e) => e.eventType == 'ding').length;
                final motionCount = events.where((e) => e.eventType == 'motion').length;

                return SliverToBoxAdapter(
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
                            label: 'TOTAL EVENTS',
                            value: '${events.length}',
                            color: colors.primary,
                          ),
                          Container(
                            height: 32,
                            width: 1,
                            color: colors.outline.withValues(alpha: 0.6),
                          ),
                          _buildStatItem(
                            label: 'DOORBELL DINGS',
                            value: '$dingCount',
                            color: colors.secondary,
                          ),
                          Container(
                            height: 32,
                            width: 1,
                            color: colors.outline.withValues(alpha: 0.6),
                          ),
                          _buildStatItem(
                            label: 'MOTION ALERTS',
                            value: '$motionCount',
                            color: Colors.green,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            // ==========================================
            // 3. أزرار الفلترة السريعة
            // ==========================================
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    _buildFilterChip('All Events', 'all', colors),
                    const SizedBox(width: 8),
                    _buildFilterChip('Doorbell Dings', 'ding', colors),
                    const SizedBox(width: 8),
                    _buildFilterChip('Motion Alerts', 'motion', colors),
                  ],
                ),
              ),
            ),

            // ==========================================
            // 4. قائمة الأحداث الأمنية التاريخية
            // ==========================================
            StreamBuilder<List<RingEventEntity>>(
              stream: ringRepo.watchRecentEvents(limit: 50),
              builder: (context, snapshot) {
                final allEvents = snapshot.data ?? [];
                final filtered = allEvents.where((e) {
                  if (_selectedFilter == 'all') return true;
                  return e.eventType == _selectedFilter;
                }).toList();

                if (filtered.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: colors.outline),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.shield_outlined, size: 36, color: colors.primary),
                            const SizedBox(height: 10),
                            Text(
                              'No Activity in Perimeter Archive',
                              style: TextStyle(
                                color: colors.onSurface,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Doorbell presses and perimeter motion triggers will be recorded here.',
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
                        final event = filtered[index];
                        final isDing = event.eventType == 'ding';
                        final badgeColor = isDing ? colors.secondary : colors.primary;
                        final timeStr = DateFormat('EEEE, MMM d • h:mm a').format(event.timestamp.toLocal());
                        final description = event.aiSceneDescription ?? 'Activity logged at ${event.deviceLabel}.';

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Material(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () async {
                                HapticManager.instance.selectionClick();
                                await SoundController.instance.play(SoundCue.navCenter);
                                await assistant.speak(
                                  'Security event at ${event.deviceLabel} on $timeStr. $description',
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: colors.outline.withValues(alpha: 0.6)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: badgeColor.withValues(alpha: 0.15),
                                      child: Icon(
                                        isDing ? Icons.notifications_active_rounded : Icons.directions_run_rounded,
                                        color: badgeColor,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                event.deviceLabel.toUpperCase(),
                                                style: TextStyle(
                                                  color: colors.onSurface,
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                              Text(
                                                DateFormat('h:mm a').format(event.timestamp.toLocal()),
                                                style: TextStyle(
                                                  color: colors.onSurfaceVariant,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            timeStr,
                                            style: TextStyle(
                                              color: colors.onSurfaceVariant.withValues(alpha: 0.8),
                                              fontSize: 10.5,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            description,
                                            style: TextStyle(
                                              color: colors.onSurface,
                                              fontSize: 13,
                                              height: 1.35,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: Icon(Icons.volume_up_rounded, color: colors.primary, size: 20),
                                      tooltip: 'Read Aloud',
                                      onPressed: () async {
                                        await assistant.speak(description);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: filtered.length,
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

  Widget _buildFilterChip(String label, String value, ColorScheme colors) {
    final isSelected = _selectedFilter == value;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: colors.primary,
      backgroundColor: colors.surface,
      labelStyle: TextStyle(
        color: isSelected ? colors.surface : colors.onSurface,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
      side: BorderSide(
        color: isSelected ? colors.primary : colors.outline,
      ),
      onSelected: (val) {
        if (val) {
          HapticManager.instance.selectionClick();
          setState(() => _selectedFilter = value);
        }
      },
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