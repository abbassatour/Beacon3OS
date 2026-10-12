// lib/desktop/desktop_app.dart
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/core/theme/cubit/theme_cubit.dart';
import 'package:beacon_os/desktop/view/desktop_shell_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';
import 'package:local_vault_api/local_vault_api.dart';

class DesktopApp extends StatelessWidget {
  const DesktopApp({
    required this.taskRepository,
    required this.focusAlarmsRepository,
    required this.commsRepository,
    required this.settingsRepository,
    required this.topologyRepository,
    required this.initialSettings,
    super.key,
  });

  final TaskAgendaRepository taskRepository;
  final FocusAlarmsRepository focusAlarmsRepository;
  final CommsRepository commsRepository;
  final SettingsRepository settingsRepository;
  final TopologyRepository topologyRepository;
  final AppSetting initialSettings;

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<TaskAgendaRepository>.value(value: taskRepository),
        RepositoryProvider<FocusAlarmsRepository>.value(
          value: focusAlarmsRepository,
        ),
        RepositoryProvider<CommsRepository>.value(value: commsRepository),
        RepositoryProvider<SettingsRepository>.value(value: settingsRepository),
        RepositoryProvider<TopologyRepository>.value(value: topologyRepository),
      ],
      child: BlocProvider(
        create: (_) => ThemeCubit(
          isHighContrast: initialSettings.isHighContrast,
        ),
        child: BlocBuilder<ThemeCubit, AppThemeMode>(
          builder: (context, themeMode) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              title: 'BeaconOS Command Center',
              theme: themeMode == AppThemeMode.highContrastOled
                  ? AppTheme.highContrastOledTheme
                  : AppTheme.warmPaperTheme,
              home: const DesktopShellPage(),
            );
          },
        ),
      ),
    );
  }
}