import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/desktop/settings/cubit/desktop_settings_cubit.dart';
import 'package:beacon_os/desktop/settings/cubit/desktop_settings_state.dart';
import 'package:beacon_os/desktop/settings/widgets/settings_card.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:local_vault_api/local_vault_api.dart';

class VisionAndSafetyCard extends StatelessWidget {
  const VisionAndSafetyCard({required this.state, super.key});

  final DesktopSettingsState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cubit = context.read<DesktopSettingsCubit>();

    return SettingsCard(
      title: 'AI VISION & RADAR PREFERENCES',
      icon: Icons.shield_rounded,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Vision Inspection Detail',
                style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              DropdownButton<String>(
                value: state.visionInspectionDetail,
                dropdownColor: colors.surface,
                style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.bold, fontSize: 12),
                items: const [
                  DropdownMenuItem(value: 'concise', child: Text('Concise (Fast)')),
                  DropdownMenuItem(value: 'detailed', child: Text('Deep Spatial Inspection')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    cubit.updateSetting(
                      AppSettingsCompanion(visionInspectionDetail: drift.Value(val)),
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
              'Auto-Dial Emergency Primary Contact',
              style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            subtitle: Text(
              'Immediately place phone call when SOS triggers.',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
            ),
            activeColor: colors.error,
            value: state.autoDialEmergency,
            onChanged: (val) => cubit.updateSetting(
              AppSettingsCompanion(autoDialEmergency: drift.Value(val)),
            ),
          ),
          const Divider(),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Share Live GPS on SOS',
              style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            subtitle: Text(
              'Generate Google Maps link for rescue radar.',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
            ),
            activeColor: colors.error,
            value: state.shareGpsOnSos,
            onChanged: (val) => cubit.updateSetting(
              AppSettingsCompanion(shareGpsOnSos: drift.Value(val)),
            ),
          ),
        ],
      ),
    );
  }
}
