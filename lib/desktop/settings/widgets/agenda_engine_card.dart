import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/desktop/settings/cubit/desktop_settings_cubit.dart';
import 'package:beacon_os/desktop/settings/cubit/desktop_settings_state.dart';
import 'package:beacon_os/desktop/settings/widgets/settings_card.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:local_vault_api/local_vault_api.dart';

class AgendaEngineCard extends StatelessWidget {
  const AgendaEngineCard({required this.state, super.key});

  final DesktopSettingsState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cubit = context.read<DesktopSettingsCubit>();

    return SettingsCard(
      title: 'AGENDA & TASKS PREFERENCES',
      icon: Icons.calendar_today_rounded,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Default Task Priority',
                style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              DropdownButton<String>(
                value: state.defaultPriority,
                dropdownColor: colors.surface,
                style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.bold, fontSize: 12),
                items: const [
                  DropdownMenuItem(value: 'high', child: Text('ðŸ”´ High')),
                  DropdownMenuItem(value: 'medium', child: Text('ðŸŸ¡ Medium')),
                  DropdownMenuItem(value: 'low', child: Text('âšª Low')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    cubit.updateSetting(
                      AppSettingsCompanion(defaultPriority: drift.Value(val)),
                    );
                  }
                },
              ),
            ],
          ),
          const Divider(),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Auto-Archive Completed Priorities',
              style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            subtitle: Text(
              'Instantly hide finished tasks from Cockpit canvas.',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
            ),
            activeColor: colors.primary,
            value: state.autoArchiveCompleted,
            onChanged: (val) => cubit.updateSetting(
              AppSettingsCompanion(autoArchiveCompleted: drift.Value(val)),
            ),
          ),
          const Divider(),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Speak Due Dates Aloud',
              style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            subtitle: Text(
              'Voice assistant announces relative deadlines on tap.',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
            ),
            activeColor: colors.primary,
            value: state.speakDueDatesAloud,
            onChanged: (val) => cubit.updateSetting(
              AppSettingsCompanion(speakDueDatesAloud: drift.Value(val)),
            ),
          ),
        ],
      ),
    );
  }
}
