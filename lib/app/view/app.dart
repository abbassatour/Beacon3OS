// lib/app/view/app.dart
import 'dart:async';
import 'dart:io';

import 'package:beacon_os/auth/cubit/auth_cubit.dart';
import 'package:beacon_os/core/services/permission_service.dart';
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/core/theme/cubit/theme_cubit.dart';
import 'package:beacon_os/core/topology/topology.dart';
import 'package:beacon_os/core/voice_bus/voice_bus.dart';
import 'package:beacon_os/desktop/desktop.dart';
import 'package:beacon_os/onboarding/onboarding.dart';
import 'package:beacon_os/spatial_shell/spatial_shell.dart';
import 'package:beacon_os/tv/tv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';
import 'package:local_vault_api/local_vault_api.dart';

/// مفتاح التنقل العام للمنظومة بالكامل
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class App extends StatefulWidget {
  const App({
    required LauncherRepository launcherRepository,
    required AppSetting initialSettings,
    this.isTv = false,
    super.key,
  })  : _launcherRepository = launcherRepository,
        _initialSettings = initialSettings;

  final LauncherRepository _launcherRepository;
  final AppSetting _initialSettings;
  final bool isTv;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final SpatialTopology _topology;
  late final VoiceCommandDispatcher _voiceDispatcher;
  StreamSubscription<List<SpatialNode>>? _nodesSubscription;

  bool get _isDesktop =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  bool get _isTv => widget.isTv;

  @override
  void initState() {
    super.initState();

    // 1. تهيئة الطوبولوجيا المكانية الافتراضية
    _topology = SpatialTopology.defaultTopology();

    // 2. الاستماع لتحديثات وتوزيع الغرف من قاعدة البيانات المحلية
    _nodesSubscription = widget._launcherRepository.topology
        .watchNodes()
        .listen((nodes) {
      if (nodes.isNotEmpty && mounted) {
        setState(() {
          _topology.updateFromNodes(nodes);
        });
      }
    });

    // 3. تهيئة موجه الأوامر الصوتية الثنائي (Fast-Path + Gemini)
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

    // ⚡ تأخير طلب الأذونات على الهواتف لمدة 1.2 ثانية لاكتمال رسم الإطار الأول وتفادي الشاشة السوداء
    if (!_isDesktop && !_isTv) {
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) {
          PermissionService.instance.requestAllPermissions();
        }
      });
    }
  }

  @override
  void dispose() {
    _nodesSubscription?.cancel();
    _topology.dispose(); // 👈 إغلاق قناة بث الطوبولوجيا بأمان
    super.dispose();
  }

  /// 🌟 اختيار الشاشة المناسبة للمنصة ونوع الجهاز
  Widget _resolveHomeScreen(bool hasCompletedOnboarding) {
    if (_isDesktop) {
      return const DesktopShellPage(); // 💻 واجهة سطح المكتب
    }
    if (_isTv) {
      return const TvShellPage(); // 📺 شاشة التلفزيون المحدثة بنظام الـ Cubits النظيف
    }
    return hasCompletedOnboarding
        ? const SpatialShellPage() // 📱 شاشة الهاتف الأساسية (الفضاء الديكارتي)
        : const GatewayPage();     // 🚪 بوابة الترحيب واختيار نمط الاستخدام
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
              isHighContrast: widget._initialSettings.isHighContrast || _isTv,
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
              title: _isDesktop
                  ? 'BeaconOS Command Center'
                  : (_isTv ? 'BeaconOS TV Canvas' : 'BeaconOS'),
              theme: (_isTv || themeMode == AppThemeMode.highContrastOled)
                  ? AppTheme.highContrastOledTheme
                  : AppTheme.warmPaperTheme,
              home: _resolveHomeScreen(hasCompletedOnboarding),
            );
          },
        ),
      ),
    );
  }
}