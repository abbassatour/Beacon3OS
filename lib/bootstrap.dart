// lib/bootstrap.dart
import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:beacon_os/app/app.dart';
import 'package:beacon_os/core/audio/sound_controller.dart';
import 'package:beacon_os/core/constants/api_constants.dart';
import 'package:beacon_os/core/haptics/haptic_manager.dart';
import 'package:beacon_os/core/services/web3_service.dart';
import 'package:beacon_os/desktop/desktop.dart';
import 'package:beacon_os/tv/tv.dart';
import 'package:bloc/bloc.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:launcher_repository/launcher_repository.dart';
import 'package:local_vault_api/local_vault_api.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:voice_ai_api/voice_ai_api.dart';

/// يحدد نمط الإطلاق المستهدف للتطبيق
enum DeviceTarget { auto, mobile, tv, desktop }

class AppBlocObserver extends BlocObserver {
  const AppBlocObserver();

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);
    log('onChange(${bloc.runtimeType}, $change)');
  }

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    log('onError(${bloc.runtimeType}, $error, $stackTrace)');
    super.onError(bloc, error, stackTrace);
  }
}

Future<void> bootstrap({DeviceTarget target = DeviceTarget.auto}) async {
  FlutterError.onError = (details) {
    log(details.exceptionAsString(), stackTrace: details.stack);
  };

  Bloc.observer = const AppBlocObserver();
  WidgetsFlutterBinding.ensureInitialized();

  final isMobilePlatform = Platform.isAndroid || Platform.isIOS;

  // 📺 1. فحص التلفاز وتهيئة أبعاد العرض
  var isTv = target == DeviceTarget.tv;
  if (!isTv && Platform.isAndroid) {
    try {
      const channel = MethodChannel('com.beaconos/system');
      isTv = await channel.invokeMethod<bool>('isTv') ?? false;
      log('Bootstrap: Television auto-detected -> $isTv');
    } catch (e) {
      log('Bootstrap: isTv check skipped: $e');
    }
  }

  // فرض الوضع الأفقي وشاشة كاملة لشاشات التلفزيون
  if (isTv) {
    try {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } catch (_) {}
  } else if (isMobilePlatform) {
    try {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } catch (_) {}
  }

  // 2. تهيئة سحابة Supabase بأمان
  if (ApiConstants.supabaseUrl.isNotEmpty &&
      ApiConstants.supabaseAnonKey.isNotEmpty) {
    try {
      await Supabase.initialize(
        url: ApiConstants.supabaseUrl,
        anonKey: ApiConstants.supabaseAnonKey,
      );
      log('Supabase: Initialized successfully.');
    } catch (e) {
      log('Supabase init error (offline tolerant): $e');
    }
  }

  // 3. الخزنة المحلية ومحرك الهوية السيادية Web3 DID (Single Source of Truth)
  final database = AppDatabase();

  try {
    await Web3Service.instance
        .initialize(database: database)
        .timeout(const Duration(seconds: 5));
    log('Bootstrap: Web3 Sovereign Identity initialized.');
  } catch (e) {
    log('Bootstrap: Web3 init deferred: $e');
  }

  // 4. تهيئة وكيل الذكاء الاصطناعي ومستودع النظام
  final llmAgent = LlmAgent(openRouterApiKey: ApiConstants.openRouterApiKey);
  final launcherRepository = LauncherRepository(
    database: database,
    llmAgent: llmAgent,
  );

  // تفعيل الاستماع اللحظي للرادار والطوبولوجيا
  launcherRepository.comms.initializeRealtimeSync();
  launcherRepository.topology.initializeRealtimeSync();

  // 5. تهيئة محركات الصوت (للهواتف فقط)
  if (isMobilePlatform && !isTv) {
    try {
      await launcherRepository.assistant
          .initializeEngines()
          .timeout(const Duration(seconds: 4));
      log('Bootstrap: Audio engines initialized.');
    } catch (e) {
      log('Bootstrap: Audio engines init bypassed: $e');
    }
  }

  // 6. قراءة الإعدادات مع إعدادات افتراضية ذكية بحسب نوع الشاشة
  AppSetting initialSettings;
  try {
    initialSettings = await launcherRepository.settings
        .getSettings()
        .timeout(const Duration(seconds: 4));
  } catch (e) {
    initialSettings = AppSetting(
      id: 'local_device_settings',
      userPersona: isTv ? 'blind_accessible' : 'digital_minimalist',
      hasCompletedOnboarding: isTv || target == DeviceTarget.desktop,
      speechRate: 0.5,
      hapticsEnabled: true,
      soundCuesEnabled: true,
      isHighContrast: isTv, // تباين عالي افتراضي للقراءة من مسافة 3 أمتار على التلفاز
      defaultPriority: 'medium',
      autoArchiveCompleted: true,
      speakDueDatesAloud: true,
      autoDialEmergency: true,
      shareGpsOnSos: true,
      speakIncomingSms: true,
      voiceChimeHalfway: true,
      vibrateOnSessionFinish: true,
      syncAlarmsWithAndroidClock: true,
      visionInspectionDetail: 'concise',
      autoFlashlightInDark: true,
      preferredCurrency: 'USD / Local',
      updatedAt: DateTime.now(),
      isSynced: false,
    );
  }

  SoundController.instance.isEnabled = initialSettings.soundCuesEnabled;
  HapticManager.instance.isEnabled = initialSettings.hapticsEnabled;
  unawaited(launcherRepository.assistant.setSpeechRate(initialSettings.speechRate));

  // 7. توجيه إطلاق التطبيق للمنصة المناسبة
  if (target == DeviceTarget.tv || isTv) {
    runApp(
      TvApp(
        taskRepository: launcherRepository.tasks,
        focusAlarmsRepository: launcherRepository.focusAlarms,
        commsRepository: launcherRepository.comms,
        settingsRepository: launcherRepository.settings,
        topologyRepository: launcherRepository.topology,
        initialSettings: initialSettings,
      ),
    );
  } else if (target == DeviceTarget.desktop) {
    runApp(
      DesktopApp(
        taskRepository: launcherRepository.tasks,
        focusAlarmsRepository: launcherRepository.focusAlarms,
        commsRepository: launcherRepository.comms,
        settingsRepository: launcherRepository.settings,
        topologyRepository: launcherRepository.topology,
        initialSettings: initialSettings,
      ),
    );
  } else {
    runApp(
      App(
        launcherRepository: launcherRepository,
        initialSettings: initialSettings,
        isTv: false,
      ),
    );
  }
}