import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/desktop/settings/cubit/desktop_settings_cubit.dart';
import 'package:beacon_os/desktop/settings/cubit/desktop_settings_state.dart';
import 'package:beacon_os/desktop/settings/widgets/agenda_engine_card.dart';
import 'package:beacon_os/desktop/settings/widgets/audio_engine_card.dart';
import 'package:beacon_os/desktop/settings/widgets/device_pairing_card.dart';
import 'package:beacon_os/desktop/settings/widgets/focus_engine_card.dart';
import 'package:beacon_os/desktop/settings/widgets/persona_and_theme_card.dart';
import 'package:beacon_os/desktop/settings/widgets/settings_header.dart';
import 'package:beacon_os/desktop/settings/widgets/sovereign_identity_card.dart';
import 'package:beacon_os/desktop/settings/widgets/vision_and_safety_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';

class DesktopSettingsView extends StatelessWidget {
  const DesktopSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DesktopSettingsCubit(
        settingsRepository: context.read<SettingsRepository>(),
        taskRepository: context.read<TaskAgendaRepository>(),
        focusAlarmsRepository: context.read<FocusAlarmsRepository>(),
        commsRepository: context.read<CommsRepository>(),
        topologyRepository: context.read<TopologyRepository>(),
      ),
      child: const _DesktopSettingsContent(),
    );
  }
}

class _DesktopSettingsContent extends StatelessWidget {
  const _DesktopSettingsContent();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return BlocBuilder<DesktopSettingsCubit, DesktopSettingsState>(
      builder: (context, state) {
        if (state.status == DesktopSettingsStatus.loading && state.settings == null) {
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
                SettingsHeader(state: state),
                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              SovereignIdentityCard(state: state),
                              const SizedBox(height: 16),
                              const DevicePairingCard(),
                              const SizedBox(height: 16),
                              PersonaAndThemeCard(state: state),
                              const SizedBox(height: 16),
                              AudioEngineCard(state: state),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            children: [
                              AgendaEngineCard(state: state),
                              const SizedBox(height: 16),
                              FocusEngineCard(state: state),
                              const SizedBox(height: 16),
                              VisionAndSafetyCard(state: state),
                            ],
                          ),
                        ),
                      ],
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
