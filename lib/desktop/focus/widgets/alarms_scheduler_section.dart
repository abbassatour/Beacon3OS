import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/desktop/focus/cubit/desktop_focus_cubit.dart';
import 'package:beacon_os/desktop/focus/cubit/desktop_focus_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outline.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          const SizedBox(height: 14),

          // Ø´Ø±ÙŠØ· Ø¥Ø¶Ø§ÙØ© Ø§Ù„Ù…Ù†Ø¨Ù‡
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.scaffoldBg,
              borderRadius: BorderRadius.circular(14),
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

          // Ù‚Ø§Ø¦Ù…Ø© Ø§Ù„Ù…Ù†Ø¨Ù‡Ø§Øª Ø§Ù„Ù…Ø³Ø¬Ù„Ø©
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
                                        ? '${alarm.label} â€¢ $relativeTime'
                                        : '${alarm.label} â€¢ Disabled',
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
