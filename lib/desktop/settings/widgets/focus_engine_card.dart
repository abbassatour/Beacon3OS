// lib/desktop/settings/widgets/focus_engine_card.dart
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/desktop/settings/cubit/desktop_settings_cubit.dart';
import 'package:beacon_os/desktop/settings/cubit/desktop_settings_state.dart';
import 'package:beacon_os/desktop/settings/widgets/settings_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';

class FocusEngineCard extends StatelessWidget {
  const FocusEngineCard({required this.state, super.key});

  final DesktopSettingsState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cubit = context.read<DesktopSettingsCubit>();

    return SettingsCard(
      title: 'FOCUS & ALARMS PREFERENCES',
      icon: Icons.hourglass_top_rounded,
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Halfway Voice Chime',
              style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            subtitle: Text(
              'Voice announcement at 50% mark of focus cycle.',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
            ),
            activeColor: colors.primary,
            value: state.voiceChimeHalfway,
            onChanged: (val) => cubit.updateSetting(
              AppSettingUpdatePayload(voiceChimeHalfway: val),
            ),
          ),
          const Divider(),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Vibrate On Session Finish',
              style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            subtitle: Text(
              'Calming haptic pulse when Pomodoro ends.',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
            ),
            activeColor: colors.primary,
            value: state.vibrateOnSessionFinish,
            onChanged: (val) => cubit.updateSetting(
              AppSettingUpdatePayload(vibrateOnSessionFinish: val),
            ),
          ),
          const Divider(),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Sync Alarms with Android Clock',
              style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            subtitle: Text(
              'Background integration with native AlarmClock.',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
            ),
            activeColor: colors.primary,
            value: state.syncAlarmsWithAndroidClock,
            onChanged: (val) => cubit.updateSetting(
              AppSettingUpdatePayload(syncAlarmsWithAndroidClock: val),
            ),
          ),
        ],
      ),
    );
  }
}