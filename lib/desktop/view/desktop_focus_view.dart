// lib/desktop/view/desktop_focus_view.dart
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/desktop/cubit/desktop_focus_cubit.dart';
import 'package:beacon_os/desktop/cubit/desktop_focus_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:launcher_repository/launcher_repository.dart';
import 'package:local_vault_api/local_vault_api.dart';

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
                // 1. رأس الصفحة: العناوين والمقاييس السريعة
                _FocusHeader(state: state),
                const SizedBox(height: 20),

                // 2. المحتوى المقسوم: المؤقت والإحصائيات يساراً + المنبهات يميناً
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // القسم الأيسر: محرك البومودورو والعمل العميق
                      Expanded(
                        flex: 5,
                        child: _DeepWorkSection(state: state),
                      ),
                      const SizedBox(width: 20),

                      // القسم الأيمن: جدول ومزامنة المنبهات
                      Expanded(
                        flex: 5,
                        child: _AlarmsSchedulerSection(state: state),
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

class _FocusHeader extends StatelessWidget {
  const _FocusHeader({required this.state});

  final DesktopFocusState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.hourglass_top_rounded, color: colors.primary, size: 26),
                const SizedBox(width: 10),
                Text(
                  'FOCUS SESSIONS & ALARMS',
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Deep work Pomodoro intervals, daily focus history, and synchronized alarm clock schedule.',
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
        Row(
          children: [
            _StatPill(
              icon: Icons.timer_rounded,
              label: 'Today',
              value: '${state.totalFocusMinutesToday}m',
              accentColor: colors.primary,
            ),
            const SizedBox(width: 10),
            _StatPill(
              icon: Icons.task_alt_rounded,
              label: 'Cycles',
              value: '${state.todaySessions.length}',
              accentColor: Colors.green,
            ),
            const SizedBox(width: 10),
            _StatPill(
              icon: Icons.alarm_rounded,
              label: 'Active Alarms',
              value: '${state.alarms.where((a) => a.isActive).length}',
              accentColor: colors.secondary,
            ),
          ],
        ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.accentColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outline.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: accentColor),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeepWorkSection extends StatelessWidget {
  const _DeepWorkSection({required this.state});

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
          // عداد المؤقت الرقمي
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

                // أزرار فترات التركيز السريعة
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

                // أزرار التحكم
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

          // سجل الجلسات المكتملة اليوم
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

class _AlarmsSchedulerSection extends StatefulWidget {
  const _AlarmsSchedulerSection({required this.state});

  final DesktopFocusState state;

  @override
  State<_AlarmsSchedulerSection> createState() => _AlarmsSchedulerSectionState();
}

class _AlarmsSchedulerSectionState extends State<_AlarmsSchedulerSection> {
  final _labelCtrl = TextEditingController(text: 'Focus Alarm');
  TimeOfDay _selectedTime = const TimeOfDay(hour: 8, minute: 0);

  @override
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
  }

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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // رأس قسم المنبهات
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SYSTEM ALARMS & TIME-BLOCKS',
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.green),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Android Clock Sync: Active',
                    style: TextStyle(color: colors.onSurfaceVariant, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // شريط إضافة المنبه
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.scaffoldBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.outline.withValues(alpha: 0.6)),
            ),
            child: Row(
              children: [
                // زر اختيار الوقت
                InkWell(
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: _selectedTime,
                    );
                    if (picked != null) {
                      setState(() => _selectedTime = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colors.primary.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.access_time_rounded, size: 16, color: colors.primary),
                        const SizedBox(width: 8),
                        Text(
                          _selectedTime.format(context),
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // حقل اسم المنبه
                Expanded(
                  child: TextField(
                    controller: _labelCtrl,
                    style: TextStyle(color: colors.onSurface, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Alarm label...',
                      filled: true,
                      fillColor: colors.surface,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: colors.outline),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.surface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onPressed: () {
                    cubit.addAlarm(
                      hour: _selectedTime.hour,
                      minute: _selectedTime.minute,
                      label: _labelCtrl.text,
                    );
                  },
                  child: const Text('Add Alarm', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // قائمة المنبهات المسجلة
          Expanded(
            child: widget.state.alarms.isEmpty
                ? Center(
                    child: Text(
                      'No scheduled alarms. Add an alarm above.',
                      style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    itemCount: widget.state.alarms.length,
                    itemBuilder: (context, index) {
                      final alarm = widget.state.alarms[index];
                      final relativeTime = cubit.getRelativeAlarmTime(alarm.hour, alarm.minute);

                      final hour12 = alarm.hour % 12 == 0 ? 12 : alarm.hour % 12;
                      final period = alarm.hour >= 12 ? 'PM' : 'AM';
                      final minStr = alarm.minute.toString().padLeft(2, '0');
                      final timeStr = '$hour12:$minStr $period';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: alarm.isActive
                                ? colors.primary.withValues(alpha: 0.3)
                                : colors.outline.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: alarm.isActive
                                  ? colors.primary.withValues(alpha: 0.12)
                                  : context.scaffoldBg,
                              child: Icon(
                                Icons.alarm_rounded,
                                color: alarm.isActive ? colors.primary : colors.onSurfaceVariant,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    timeStr,
                                    style: TextStyle(
                                      color: alarm.isActive ? colors.onSurface : colors.onSurfaceVariant,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    alarm.isActive
                                        ? '${alarm.label} • $relativeTime'
                                        : '${alarm.label} • Disabled',
                                    style: TextStyle(
                                      color: colors.onSurfaceVariant,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: alarm.isActive,
                              activeColor: colors.primary,
                              onChanged: (_) => cubit.toggleAlarm(alarm),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline_rounded, size: 18, color: colors.error),
                              onPressed: () => cubit.deleteAlarm(alarm),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}