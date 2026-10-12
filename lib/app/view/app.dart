// lib/app/view/app.dart
import 'dart:async';
import 'dart:io';

import 'package:beacon_os/auth/cubit/auth_cubit.dart';
import 'package:beacon_os/core/services/permission_service.dart';
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/core/theme/cubit/theme_cubit.dart';
import 'package:beacon_os/core/topology/topology.dart';
import 'package:beacon_os/core/voice_bus/voice_bus.dart';
import 'package:beacon_os/desktop/view/desktop_shell_page.dart';
import 'package:beacon_os/onboarding/onboarding.dart';
import 'package:beacon_os/spatial_shell/spatial_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';
import 'package:local_vault_api/local_vault_api.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class App extends StatefulWidget {
  const App({
    required LauncherRepository launcherRepository,
    required AppSetting initialSettings,
    super.key,
  })  : _launcherRepository = launcherRepository,
        _initialSettings = initialSettings;

  final LauncherRepository _launcherRepository;
  final AppSetting _initialSettings;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final SpatialTopology _topology;
  late final VoiceCommandDispatcher _voiceDispatcher;
  StreamSubscription<List<SpatialNode>>? _nodesSubscription;

  bool get _isDesktop =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  @override
  void initState() {
    super.initState();

    _topology = SpatialTopology.defaultTopology();

    // ⚡️ الاستماع الحي لتحديثات مواقع الغرف من قاعدة البيانات
    _nodesSubscription = widget._launcherRepository.topology
        .watchNodes()
        .listen((nodes) {
      if (nodes.isNotEmpty && mounted) {
        setState(() {
          _topology.updateFromNodes(nodes);
        });
      }
    });

    _voiceDispatcher = VoiceCommandDispatcher(
      topology: _topology,
      assistantRepository: widget._launcherRepository.assistant,
      navigatorKey: appNavigatorKey,
    );

    widget._launcherRepository.registerVoiceDispatcher(
      (query, {base64Image}) => _voiceDispatcher.dispatch(
        query,
        base64Image: base64Image,
      ),
    );

    if (!_isDesktop) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        PermissionService.instance.requestAllPermissions();
      });
    }
  }

  @override
  void dispose() {
    _nodesSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasCompletedOnboarding =
        widget._initialSettings.hasCompletedOnboarding;

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: widget._launcherRepository),
        RepositoryProvider<SpatialTopology>.value(value: _topology),
        RepositoryProvider<VoiceCommandDispatcher>.value(
          value: _voiceDispatcher,
        ),
        RepositoryProvider<TaskAgendaRepository>.value(
          value: widget._launcherRepository.tasks,
        ),
        RepositoryProvider<FocusAlarmsRepository>.value(
          value: widget._launcherRepository.focusAlarms,
        ),
        RepositoryProvider<CommsRepository>.value(
          value: widget._launcherRepository.comms,
        ),
        RepositoryProvider<SystemHardwareRepository>.value(
          value: widget._launcherRepository.hardware,
        ),
        RepositoryProvider<SettingsRepository>.value(
          value: widget._launcherRepository.settings,
        ),
        RepositoryProvider<AssistantRepository>.value(
          value: widget._launcherRepository.assistant,
        ),
        RepositoryProvider<TopologyRepository>.value(
          value: widget._launcherRepository.topology,
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => ThemeCubit(
              isHighContrast: widget._initialSettings.isHighContrast,
            ),
          ),
          BlocProvider(
            create: (context) => AuthCubit(
              repository: widget._launcherRepository,
            ),
          ),
        ],
        child: BlocBuilder<ThemeCubit, AppThemeMode>(
          builder: (context, themeMode) {
            return MaterialApp(
              navigatorKey: appNavigatorKey,
              debugShowCheckedModeBanner: false,
              title: _isDesktop ? 'BeaconOS Command Center' : 'BeaconOS',
              theme: themeMode == AppThemeMode.highContrastOled
                  ? AppTheme.highContrastOledTheme
                  : AppTheme.warmPaperTheme,
              // 🌟 التوجيه التلقائي للمنصة:
              // لويندوز: يفتح لوحة التحكم المكتبية والشريط الجانبي فوراً
              // للهاتف: يفتح البوصلة الفضائية أو صفحة التهيئة
              home: _isDesktop
                  ? const DesktopShellPage()
                  : (hasCompletedOnboarding
                      ? const SpatialShellPage()
                      : const GatewayPage()),
            );
          },
        ),
      ),
    );
  }
}