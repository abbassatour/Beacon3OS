// lib/mobile/cockpit/view/cockpit_floor_0_view.dart
import 'dart:async';
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/core/topology/topology.dart';
import 'package:beacon_os/mobile/cockpit/cubit/cockpit_cubit.dart';
import 'package:beacon_os/mobile/cockpit/cubit/cockpit_state.dart';
import 'package:beacon_os/mobile/impact_pool/view/impact_pool_page.dart';
import 'package:beacon_os/mobile/shell/spatial_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:launcher_repository/launcher_repository.dart';
import 'package:local_vault_api/local_vault_api.dart';

/// واجهة الطابق الأرضي لقمرة القيادة (Floor 0: Today Cockpit Canvas)
class CockpitFloor0View extends StatefulWidget {
  const CockpitFloor0View({super.key});

  @override
  State<CockpitFloor0View> createState() => _CockpitFloor0ViewState();
}

class _CockpitFloor0ViewState extends State<CockpitFloor0View> {
  late Timer _clockTimer;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _currentTime = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dayName = DateFormat('EEEE').format(_currentTime).toUpperCase();
    final fullDate = DateFormat('MMMM d, yyyy').format(_currentTime);
    final timeString = DateFormat('h:mm a').format(_currentTime);

    final compassCubit = context.read<SpatialCompassCubit>();
    final colors = context.colors;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        child: BlocBuilder<CockpitCubit, CockpitState>(
          builder: (context, state) {
            final cubit = context.read<CockpitCubit>();

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 60, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              dayName,
                              style: TextStyle(
                                color: colors.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                            Row(
                              children: [
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    backgroundColor: colors.surface,
                                    foregroundColor: colors.onSurface,
                                    side: BorderSide(color: colors.outline),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    minimumSize: const Size(0, 32),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  icon: Icon(
                                    Icons.volunteer_activism_rounded,
                                    size: 16,
                                    color: colors.primary,
                                  ),
                                  label: const Text(
                                    'IMPACT',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  onPressed: () => Navigator.of(context).push(
                                    ImpactPoolPage.route(),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton.filledTonal(
                                  style: IconButton.styleFrom(
                                    backgroundColor: colors.surface,
                                    foregroundColor: colors.onSurface,
                                    side: BorderSide(color: colors.outline),
                                    minimumSize: const Size(32, 32),
                                    padding: EdgeInsets.zero,
                                  ),
                                  icon: const Icon(Icons.tune_rounded, size: 18),
                                  tooltip: 'Floor 1 • Engine & Settings',
                                  onPressed: compassCubit.goToSettingsFloor,
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              timeString,
                              style: TextStyle(
                                color: colors.onSurface,
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1,
                              ),
                            ),
                            Text(
                              fullDate,
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.battery_charging_full_rounded,
                              size: 16,
                              color: colors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                state.batteryStatus,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    child: Semantics(
                      label: state.isBriefingPlaying
                          ? 'Daily briefing is playing. Tap to stop audio.'
                          : 'Play daily audio briefing. Tap to hear overview of tasks, alarms, and battery.',
                      button: true,
                      child: Material(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: cubit.playDailyBriefing,
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: colors.primary,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: colors.primary.withValues(alpha: 0.08),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: colors.primary,
                                  child: Icon(
                                    state.isBriefingPlaying
                                        ? Icons.stop_rounded
                                        : Icons.play_arrow_rounded,
                                    color: colors.surface,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        state.isBriefingPlaying
                                            ? 'PLAYING BRIEFING...'
                                            : 'DAILY BRIEFING',
                                        style: TextStyle(
                                          color: colors.primary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        state.isBriefingPlaying
                                            ? 'Speaking overview aloud. Tap anytime to stop.'
                                            : 'Tap to hear schedule, alarms, and battery overview.',
                                        style: TextStyle(
                                          color: colors.onSurface,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: _buildSectionTitle(
                      context,
                      'NEXT UPCOMING ALARM',
                      Icons.access_time_rounded,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildNextAlarmCard(context, state.nextAlarm, cubit),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: _buildSectionTitle(
                      context,
                      "TODAY'S PRIORITIES (${state.pendingTasks.length})",
                      Icons.check_circle_outline_rounded,
                    ),
                  ),
                ),
                if (state.pendingTasks.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: colors.outline),
                        ),
                        child: Text(
                          'Your day is completely clear. Swipe ${CompassDirection.west.arrowSymbol} to view the full agenda.',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildPriorityTaskTile(
                          context,
                          state.pendingTasks[index],
                          cubit,
                        ),
                        childCount: state.pendingTasks.take(3).length,
                      ),
                    ),
                  ),
                if (state.latestMemo != null) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                      child: _buildSectionTitle(
                        context,
                        'LATEST VOICE MEMO (TAP TO HEAR)',
                        Icons.notes_rounded,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildMemoSnippetCard(
                        context,
                        state.latestMemo!,
                        cubit,
                      ),
                    ),
                  ),
                ],
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 28, 20, 40),
                    child: _SpatialNavigationGuideFooter(),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionTitle(
    BuildContext context,
    String title,
    IconData icon,
  ) {
    final colors = context.colors;
    return Row(
      children: [
        Icon(icon, size: 16, color: colors.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            color: colors.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }

  Widget _buildNextAlarmCard(
    BuildContext context,
    Alarm? alarm,
    CockpitCubit cubit,
  ) {
    final colors = context.colors;

    if (alarm == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.outline),
        ),
        child: Text(
          'No scheduled alarms for today. Swipe ${CompassDirection.north.arrowSymbol} for Focus & Alarms.',
          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
        ),
      );
    }

    final hourStr = alarm.hour.toString().padLeft(2, '0');
    final minuteStr = alarm.minute.toString().padLeft(2, '0');

    return Semantics(
      label:
          'Next alarm at $hourStr:$minuteStr labeled ${alarm.label}. Tap card to hear aloud or use switch to toggle.',
      button: true,
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => cubit.readNextAlarmAloud(alarm),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: colors.outline, width: 1.2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$hourStr:$minuteStr',
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      alarm.label,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.volume_up_rounded,
                        color: colors.primary,
                        size: 20,
                      ),
                      onPressed: () => cubit.readNextAlarmAloud(alarm),
                    ),
                    Switch(
                      activeColor: colors.primary,
                      value: alarm.isActive,
                      onChanged: (_) => cubit.toggleAlarm(alarm),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityTaskTile(
    BuildContext context,
    Task task,
    CockpitCubit cubit,
  ) {
    final colors = context.colors;

    Color priorityColor = colors.onSurfaceVariant;
    if (task.priority == 'high') priorityColor = colors.error;
    if (task.priority == 'medium') priorityColor = colors.secondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => cubit.readTaskAloud(task),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: priorityColor.withValues(alpha: 0.35),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    task.isCompleted
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    color: task.isCompleted
                        ? colors.onSurfaceVariant
                        : colors.primary,
                    size: 24,
                  ),
                  onPressed: () => cubit.toggleTask(task),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: TextStyle(
                          color: colors.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          decoration: task.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      if (task.dueDate != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Due: ${DateFormat('EEE, MMM d • h:mm a').format(task.dueDate!)}',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.volume_up_rounded,
                    color: colors.primary,
                    size: 20,
                  ),
                  onPressed: () => cubit.readTaskAloud(task),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMemoSnippetCard(
    BuildContext context,
    VoiceMemo memo,
    CockpitCubit cubit,
  ) {
    final colors = context.colors;

    return Semantics(
      label: 'Latest voice note titled ${memo.title}. Tap to listen.',
      button: true,
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => cubit.readMemoAloud(memo),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.outline),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: colors.secondary.withValues(alpha: 0.15),
                  child: Icon(
                    Icons.notes_rounded,
                    color: colors.secondary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        memo.title,
                        style: TextStyle(
                          color: colors.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        memo.content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.volume_up_rounded, color: colors.primary, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SpatialNavigationGuideFooter extends StatelessWidget {
  const _SpatialNavigationGuideFooter();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final topology = context.read<SpatialTopology>();
    final northRoom = topology.moduleAt(0, CompassDirection.north);
    final southRoom = topology.moduleAt(0, CompassDirection.south);
    final westRoom = topology.moduleAt(0, CompassDirection.west);
    final eastRoom = topology.moduleAt(0, CompassDirection.east);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        children: [
          Text(
            'SPATIAL COCKPIT GESTURES',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Text(
                '${CompassDirection.north.arrowSymbol} ${northRoom?.shortTitle ?? 'Focus'}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
                ),
              ),
              Text(
                '${CompassDirection.south.arrowSymbol} ${southRoom?.shortTitle ?? 'Comms'}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
                ),
              ),
              Text(
                '${CompassDirection.west.arrowSymbol} ${westRoom?.shortTitle ?? 'Agenda'}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
                ),
              ),
              Text(
                '${CompassDirection.east.arrowSymbol} ${eastRoom?.shortTitle ?? 'Vision'}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            SpatialGesture.ascendToSettings.visualHint,
            style: TextStyle(
              fontSize: 11,
              color: colors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Standalone Wrapper
class CockpitFloor0StandaloneView extends StatelessWidget {
  const CockpitFloor0StandaloneView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CockpitCubit(
        taskRepository: context.read<TaskAgendaRepository>(),
        focusAlarmsRepository: context.read<FocusAlarmsRepository>(),
        hardwareRepository: context.read<SystemHardwareRepository>(),
        assistantRepository: context.read<AssistantRepository>(),
      ),
      child: const CockpitFloor0View(),
    );
  }
}

typedef CockpitDashboardView = CockpitFloor0StandaloneView;
typedef CockpitDashboardContentView = CockpitFloor0View;