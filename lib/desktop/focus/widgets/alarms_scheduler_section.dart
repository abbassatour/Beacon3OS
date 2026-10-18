// lib/desktop/focus/widgets/alarms_scheduler_section.dart
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/desktop/focus/cubit/desktop_focus_cubit.dart';
import 'package:beacon_os/desktop/focus/cubit/desktop_focus_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';

class AlarmsSchedulerSection extends StatefulWidget {
  const AlarmsSchedulerSection({required this.state, super.key});

  final DesktopFocusState state;

  @override
  State<AlarmsSchedulerSection> createState() => _AlarmsSchedulerSectionState();
}

class _AlarmsSchedulerSectionState extends State<AlarmsSchedulerSection> {
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outline.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'SYSTEM ALARMS & TIME-BLOCKS',
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.green),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Clock Sync',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // شريط إضافة المنبه المدمج
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: context.scaffoldBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.outline.withValues(alpha: 0.6)),
            ),
            child: Row(
              children: [
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
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.primary.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time_rounded, size: 13, color: colors.primary),
                        const SizedBox(width: 4),
                        Text(
                          _selectedTime.format(context),
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                Expanded(
                  child: TextField(
                    controller: _labelCtrl,
                    style: TextStyle(color: colors.onSurface, fontSize: 11.5),
                    decoration: InputDecoration(
                      hintText: 'Alarm label...',
                      filled: true,
                      fillColor: colors.surface,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: colors.outline),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.surface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    cubit.addAlarm(
                      hour: _selectedTime.hour,
                      minute: _selectedTime.minute,
                      label: _labelCtrl.text,
                    );
                  },
                  child: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // قائمة المنبهات المسجلة
          Expanded(
            child: widget.state.alarms.isEmpty
                ? Center(
                    child: Text(
                      'No scheduled alarms. Add an alarm above.',
                      style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11.5),
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
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: alarm.isActive
                                ? colors.primary.withValues(alpha: 0.3)
                                : colors.outline.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: alarm.isActive
                                  ? colors.primary.withValues(alpha: 0.12)
                                  : context.scaffoldBg,
                              child: Icon(
                                Icons.alarm_rounded,
                                color: alarm.isActive ? colors.primary : colors.onSurfaceVariant,
                                size: 15,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    timeStr,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: alarm.isActive ? colors.onSurface : colors.onSurfaceVariant,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    alarm.isActive
                                        ? '${alarm.label} - $relativeTime'
                                        : '${alarm.label} - Disabled',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: colors.onSurfaceVariant,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            // 🌟 تحجيم دقيق للمفتاح يمنع طفح الـ 11 بيكسل
                            SizedBox(
                              width: 38,
                              height: 24,
                              child: FittedBox(
                                child: Switch(
                                  value: alarm.isActive,
                                  activeColor: colors.primary,
                                  onChanged: (_) => cubit.toggleAlarm(alarm),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: Icon(Icons.delete_outline_rounded, size: 16, color: colors.error),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
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