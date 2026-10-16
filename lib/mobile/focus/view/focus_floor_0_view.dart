// lib/mobile/focus/view/focus_floor_0_view.dart
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/mobile/focus/cubit/focus_cubit.dart';
import 'package:beacon_os/mobile/focus/cubit/focus_state.dart';
import 'package:beacon_os/mobile/shell/spatial_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';
import 'package:local_vault_api/local_vault_api.dart';

/// واجهة الطابق الأرضي لغرفة التركيز والمنبهات (Floor 0: Focus Timer & Alarms)
class FocusFloor0View extends StatelessWidget {
  const FocusFloor0View({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final returnHint = CompassDirection.north.returnGestureHint;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        child: BlocBuilder<FocusCubit, FocusState>(
          builder: (context, state) {
            final cubit = context.read<FocusCubit>();

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'FOCUS & ALARMS',
                              style: TextStyle(
                                color: colors.onSurface,
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$returnHint or double-tap to return to Cockpit.',
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
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
                          icon: const Icon(Icons.alarm_add_rounded),
                          tooltip: 'Add System Alarm',
                          onPressed: () => _showAddAlarmDialog(context, cubit),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildTimerCard(context, state, cubit),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.access_time_rounded,
                                color: colors.primary, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'SCHEDULED ALARMS (${state.alarms.length})',
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Tap to hear time • Swipe to delete',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (state.alarms.isEmpty)
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
                          'No scheduled alarms. Tap + above or ask Beacon AI to set an alarm.',
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
                        (context, index) => _buildDismissibleAlarmTile(
                          context,
                          state.alarms[index],
                          cubit,
                        ),
                        childCount: state.alarms.length,
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 60)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTimerCard(
    BuildContext context,
    FocusState state,
    FocusCubit cubit,
  ) {
    final colors = context.colors;
    final mins = (state.remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (state.remainingSeconds % 60).toString().padLeft(2, '0');
    final remainingTimeText = '$mins:$secs';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outline, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: colors.onSurface.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                state.isTimerRunning
                    ? 'FOCUS SESSION IN PROGRESS'
                    : 'STUDY & FOCUS INTERVAL',
                style: TextStyle(
                  color: state.isTimerRunning
                      ? colors.primary
                      : colors.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: context.scaffoldBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Today: ${state.totalFocusMinutesToday}m',
                  style: TextStyle(
                    color: colors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              remainingTimeText,
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 68,
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
              minHeight: 4,
              backgroundColor: context.scaffoldBg,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [15, 25, 45, 60].map((duration) {
              final isSelected = state.selectedDurationMinutes == duration;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: InkWell(
                    onTap: state.isTimerRunning
                        ? null
                        : () => cubit.selectDuration(duration),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? colors.primary : context.scaffoldBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? colors.primary : colors.outline,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${duration}m',
                          style: TextStyle(
                            color: isSelected ? colors.surface : colors.onSurface,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: state.isTimerRunning
                        ? colors.secondary
                        : colors.primary,
                    foregroundColor: colors.surface,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: Icon(
                    state.isTimerRunning
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 22,
                  ),
                  label: Text(
                    state.isTimerRunning ? 'Pause' : 'Start Focus',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  onPressed: state.isTimerRunning
                      ? cubit.pauseTimer
                      : cubit.startTimer,
                ),
              ),
              if (state.timerStatus != TimerStatus.idle) ...[
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  style: IconButton.styleFrom(
                    backgroundColor: context.scaffoldBg,
                    foregroundColor: colors.onSurfaceVariant,
                    minimumSize: const Size(52, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 22),
                  tooltip: 'Reset Timer',
                  onPressed: cubit.resetTimer,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDismissibleAlarmTile(
    BuildContext context,
    Alarm alarm,
    FocusCubit cubit,
  ) {
    final colors = context.colors;
    final hourStr = alarm.hour.toString().padLeft(2, '0');
    final minuteStr = alarm.minute.toString().padLeft(2, '0');
    final relativeTime = _calculateRelativeTime(alarm.hour, alarm.minute);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: Key(alarm.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: colors.error.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.delete_outline_rounded, color: colors.error),
        ),
        onDismissed: (_) => cubit.deleteAlarm(alarm),
        child: Material(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => cubit.readAlarmDetailsAloud(alarm),
            onLongPress: () => _confirmDeleteAlarm(context, alarm, cubit),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.outline, width: 1.2),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: alarm.isActive
                        ? colors.primary.withValues(alpha: 0.12)
                        : context.scaffoldBg,
                    child: Icon(
                      Icons.alarm_rounded,
                      color: alarm.isActive
                          ? colors.primary
                          : colors.onSurfaceVariant,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$hourStr:$minuteStr',
                          style: TextStyle(
                            color: alarm.isActive
                                ? colors.onSurface
                                : colors.onSurfaceVariant,
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                          ),
                        ),
                        Text(
                          alarm.isActive
                              ? '${alarm.label} • Rings $relativeTime'
                              : '${alarm.label} • Turned Off',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.volume_up_rounded,
                      color: colors.primary,
                      size: 20,
                    ),
                    onPressed: () => cubit.readAlarmDetailsAloud(alarm),
                  ),
                  Switch(
                    activeColor: colors.primary,
                    value: alarm.isActive,
                    onChanged: (_) => cubit.toggleAlarm(alarm),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _calculateRelativeTime(int hour, int minute) {
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;
    var alarmMinutes = hour * 60 + minute;
    var diffMinutes = alarmMinutes - currentMinutes;
    if (diffMinutes <= 0) diffMinutes += 24 * 60;

    final hours = diffMinutes ~/ 60;
    final mins = diffMinutes % 60;

    if (hours == 0) return 'in $mins minutes';
    if (mins == 0) return 'in $hours hours';
    return 'in $hours hours and $mins minutes';
  }

  void _confirmDeleteAlarm(
    BuildContext context,
    Alarm alarm,
    FocusCubit cubit,
  ) {
    final colors = context.colors;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: colors.outline),
        ),
        title: Text(
          'Delete Alarm?',
          style: TextStyle(
            color: colors.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to delete the alarm for ${alarm.hour}:${alarm.minute}?',
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.surface,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              cubit.deleteAlarm(alarm);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddAlarmDialog(
    BuildContext context,
    FocusCubit cubit,
  ) async {
    final colors = context.colors;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (ctx, child) {
        return Theme(
          data: ThemeData(
            colorScheme: colors,
            timePickerTheme: TimePickerThemeData(
              backgroundColor: colors.surface,
              dialBackgroundColor: context.scaffoldBg,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime != null) {
      await cubit.addAlarm(
        hour: pickedTime.hour,
        minute: pickedTime.minute,
        label: 'Mindful Alarm',
      );
    }
  }
}

/// Standalone Wrapper
class FocusFloor0StandaloneView extends StatelessWidget {
  const FocusFloor0StandaloneView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => FocusCubit(
        focusRepository: context.read<FocusAlarmsRepository>(),
        assistantRepository: context.read<AssistantRepository>(),
        settingsRepository: context.read<SettingsRepository>(),
      ),
      child: const FocusFloor0View(),
    );
  }
}

// 🛡️ أسماء توافقية لمنع انكسار الكود القديم
typedef FocusAlarmsView = FocusFloor0StandaloneView;
typedef FocusAlarmsContentView = FocusFloor0View;