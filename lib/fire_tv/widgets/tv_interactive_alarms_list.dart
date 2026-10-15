import 'package:beacon_os/core/audio/sound_controller.dart';
import 'package:beacon_os/core/audio/sound_cue.dart';
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';
import 'package:local_vault_api/local_vault_api.dart';

class TvInteractiveAlarmsList extends StatelessWidget {
  const TvInteractiveAlarmsList({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final focusRepo = context.read<FocusAlarmsRepository>();

    return StreamBuilder<List<Alarm>>(
      stream: focusRepo.watchAlarms(),
      builder: (context, snapshot) {
        final alarms = (snapshot.data ?? []).where((a) => a.isActive).toList();

        if (alarms.isEmpty) {
          return Center(
            child: Text(
              'No active alarms scheduled.',
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }

        final next = alarms.first;
        final hour12 = next.hour % 12 == 0 ? 12 : next.hour % 12;
        final period = next.hour >= 12 ? 'PM' : 'AM';
        final minStr = next.minute.toString().padLeft(2, '0');

        return InkWell(
          onTap: () {
            focusRepo.toggleAlarm(next);
            SoundController.instance.play(SoundCue.navCenter);
          },
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$hour12:$minStr $period',
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.primary, width: 1.2),
                  ),
                  child: Text(
                    next.label,
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
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