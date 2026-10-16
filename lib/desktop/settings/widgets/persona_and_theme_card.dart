import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/core/theme/cubit/theme_cubit.dart';
import 'package:beacon_os/desktop/settings/cubit/desktop_settings_cubit.dart';
import 'package:beacon_os/desktop/settings/cubit/desktop_settings_state.dart';
import 'package:beacon_os/desktop/settings/widgets/settings_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PersonaAndThemeCard extends StatelessWidget {
  const PersonaAndThemeCard({required this.state, super.key});

  final DesktopSettingsState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cubit = context.read<DesktopSettingsCubit>();
    final themeCubit = context.read<ThemeCubit>();

    final isBlindMode = state.userPersona == 'blind_accessible';

    return SettingsCard(
      title: 'SYSTEM PERSONA & DISPLAY',
      icon: Icons.palette_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Active Interaction Persona',
            style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('Blind Accessible')),
                  selected: isBlindMode,
                  onSelected: (val) {
                    if (val) {
                      cubit.setPersona('blind_accessible');
                      cubit.setHighContrast(true);
                      themeCubit.toggleTheme(isHighContrast: true);
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('Digital Minimalist')),
                  selected: !isBlindMode,
                  onSelected: (val) {
                    if (val) {
                      cubit.setPersona('digital_minimalist');
                      cubit.setHighContrast(false);
                      themeCubit.toggleTheme(isHighContrast: false);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'High Contrast OLED Theme',
              style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            subtitle: Text(
              'Pure black canvas with neon cyan and yellow tokens.',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
            ),
            activeColor: colors.primary,
            value: state.isHighContrast,
            onChanged: (val) {
              cubit.setHighContrast(val);
              themeCubit.toggleTheme(isHighContrast: val);
            },
          ),
        ],
      ),
    );
  }
}
