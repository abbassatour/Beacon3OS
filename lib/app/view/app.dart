// lib/app/view/app.dart
import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:beacon_os/app/default_topology.dart';
import 'package:beacon_os/core/audio/sound_controller.dart';
import 'package:beacon_os/core/audio/sound_cue.dart';
import 'package:beacon_os/core/haptics/haptic_manager.dart';
import 'package:beacon_os/core/services/permission_service.dart';
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/core/theme/cubit/theme_cubit.dart';
import 'package:beacon_os/core/topology/topology.dart';
import 'package:beacon_os/core/voice_bus/voice_bus.dart';
import 'package:beacon_os/desktop/desktop.dart';
import 'package:beacon_os/mobile/mobile.dart';
import 'package:beacon_os/tv/tv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class App extends StatefulWidget {
  const App({
    required LauncherRepository launcherRepository,
    required AppSettingEntity initialSettings,
    this.isTv = false,
    super.key,
  })  : _launcherRepository = launcherRepository,
        _initialSettings = initialSettings;

  final LauncherRepository _launcherRepository;
  final AppSettingEntity _initialSettings;
  final bool isTv;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final SpatialTopology _topology;
  late final VoiceCommandDispatcher _voiceDispatcher;
  StreamSubscription<List<SpatialNodeEntity>>? _nodesSubscription;
  StreamSubscription<RemoteActionEvent>? _remoteActionsSubscription;
  Timer? _locateSoundTimer;

  bool get _isDesktop =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  bool get _isTv => widget.isTv;

  @override
  void initState() {
    super.initState();

    _topology = createDefaultSpatialTopology();

    // ⚡ 1. الاستماع الحي لتحديثات مواقع الغرف في الفضاء
    _nodesSubscription = widget._launcherRepository.topology
        .watchNodes()
        .listen((nodes) {
      if (nodes.isNotEmpty && mounted) {
        setState(() {
          _topology.updateFromNodes(nodes);
        });
      }
    });

    // 🧠 2. تهيئة موجه الأوامر الصوتية الثنائي
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

    // 🔔 3. تسجيل معالج صفارة الإنذار والاهتزاز عند طلب العثور على الهاتف
    widget._launcherRepository.comms.registerLocateHandler(() async {
      log('App: 📢 Inbound Remote Locate Triggered! Sounding siren & haptics...');
      try {
        await SoundController.instance.play(SoundCue.sosAlarm);
        await HapticManager.instance.emergencyAlarmPulse();

        // إيقاف الصفارة تلقائياً بعد 4 ثوانٍ
        _locateSoundTimer?.cancel();
        _locateSoundTimer = Timer(const Duration(seconds: 4), () {
          SoundController.instance.stopAll();
        });
      } catch (e) {
        log('App: Error playing locate audio/haptics: $e');
      }
    });

    // 🛰️ 4. الاستماع للأوامر الواردة عن بعد وعرض إشعار فوري
    _remoteActionsSubscription =
        widget._launcherRepository.comms.remoteActionEvents.listen((event) {
      log('App: ⚡ Received remote action event: ${event.actionType}');
      final navContext = appNavigatorKey.currentContext;
      if (navContext != null) {
        final messenger = ScaffoldMessenger.maybeOf(navContext);
        if (messenger != null) {
          messenger.hideCurrentSnackBar();

          if (event.actionType == RemoteActionType.locateDevice) {
            messenger.showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.cell_tower_rounded, color: Colors.white),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text('📍 Acoustic Beacon Active: Living room ping'),
                    ),
                  ],
                ),
                backgroundColor: Colors.blueAccent,
                duration: Duration(seconds: 3),
              ),
            );
          } else if (event.actionType == RemoteActionType.triggerSos) {
            messenger.showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.white),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text('🚨 Emergency SOS Broadcast Triggered!'),
                    ),
                  ],
                ),
                backgroundColor: Colors.redAccent,
                duration: Duration(seconds: 5),
              ),
            );
          } else if (event.payload['is_ring'] == true) {
            final label = event.payload['device_label'] ?? 'Camera';
            messenger.showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.doorbell_rounded, color: Colors.white),
                    const SizedBox(width: 10),
                    Expanded(child: Text('🔔 Activity detected at $label')),
                  ],
                ),
                backgroundColor: Colors.orangeAccent,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      }
    });

    // 🌐 5. تشغيل محرك النقل الهجين والـ P2P للهاتف المحمول فور الإقلاع
    if (!_isDesktop && !_isTv) {
      unawaited(
        widget._launcherRepository.comms.initializeHybridTransport(
          deviceType: 'phone',
        ),
      );
    }

    // 📱 6. طلب الأذونات فقط على بيئات الهاتف المحمول
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
    _locateSoundTimer?.cancel();
    _remoteActionsSubscription?.cancel();
    widget._launcherRepository.comms.unregisterLocateHandler();
    _nodesSubscription?.cancel();
    _topology.dispose();
    super.dispose();
  }

  Widget _resolveHomeScreen(bool hasCompletedOnboarding) {
    if (_isDesktop) {
      return const DesktopShellPage();
    }
    if (_isTv) {
      return const TvShellPage();
    }
    return hasCompletedOnboarding
        ? const SpatialShellPage()
        : const GatewayPage();
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
        RepositoryProvider<RingRepository>.value(
          value: widget._launcherRepository.ring,
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
                  : (_isTv ? 'BeaconOS Fire TV' : 'BeaconOS'),
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