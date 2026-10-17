// lib/desktop/settings/widgets/audio_engine_card.dart
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/desktop/settings/cubit/desktop_settings_cubit.dart';
import 'package:beacon_os/desktop/settings/cubit/desktop_settings_state.dart';
import 'package:beacon_os/desktop/settings/widgets/settings_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';

class AudioEngineCard extends StatelessWidget {
  const AudioEngineCard({required this.state, super.key});

  final DesktopSettingsState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cubit = context.read<DesktopSettingsCubit>();

    return SettingsCard(
      title: 'AUDIO & FEEDBACK ENGINE',
      icon: Icons.volume_up_rounded,
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Spatial Audio Cues',
              style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            subtitle: Text(
              'Harmonic compass chimes when navigating rooms.',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
            ),
            activeColor: colors.primary,
            value: state.soundCuesEnabled,
            onChanged: (val) => cubit.updateSetting(
              AppSettingUpdatePayload(soundCuesEnabled: val),
            ),
          ),
          const Divider(),
          // 🧭 🌟 زر التبديل الجديد لهمس الغرف لسطح المكتب
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Spatial Room Whisper',
              style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            subtitle: Text(
              'Whisper upcoming room name via TTS when panning compass.',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
            ),
            activeColor: colors.primary,
            value: state.spatialWhisperEnabled,
            onChanged: (val) => cubit.updateSetting(
              AppSettingUpdatePayload(spatialWhisperEnabled: val),
            ),
          ),
          const Divider(),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Tactile Haptics',
              style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            subtitle: Text(
              'Vibrations on mobile transitions and mic pulses.',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
            ),
            activeColor: colors.primary,
            value: state.hapticsEnabled,
            onChanged: (val) => cubit.updateSetting(
              AppSettingUpdatePayload(hapticsEnabled: val),
            ),
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Speech Rate (${(state.speechRate * 2).toStringAsFixed(1)}x)',
                style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              SizedBox(
                width: 140,
                child: Slider(
                  value: state.speechRate.clamp(0.3, 1.0),
                  min: 0.3,
                  max: 1.0,
                  divisions: 14,
                  activeColor: colors.primary,
                  onChanged: cubit.setSpeechRate,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}