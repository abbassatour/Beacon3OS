// lib/bootstrap.dart
import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:beacon_os/app/app.dart';
import 'package:beacon_os/core/audio/sound_controller.dart';
import 'package:beacon_os/core/constants/api_constants.dart';
import 'package:beacon_os/core/haptics/haptic_manager.dart';
import 'package:beacon_os/core/services/background_sync_worker.dart';
import 'package:beacon_os/core/services/web3_service.dart';
import 'package:bloc/bloc.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:launcher_repository/launcher_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:voice_ai_api/voice_ai_api.dart';
import 'package:workmanager/workmanager.dart';

enum AppFlavor { development, staging, production }

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

Future<void> bootstrap({AppFlavor flavor = AppFlavor.development}) async {
  FlutterError.onError = (details) {
    log(details.exceptionAsString(), stackTrace: details.stack);
  };

  if (flavor != AppFlavor.production) {
    Bloc.observer = const AppBlocObserver();
  }
  
  WidgetsFlutterBinding.ensureInitialized();

  final isMobile = Platform.isAndroid || Platform.isIOS;

  var isTv = false;
  if (Platform.isAndroid) {
    try {
      const channel = MethodChannel('com.beaconos/system');
      isTv = await channel.invokeMethod<bool>('isTv') ?? false;
      log('Bootstrap: Television detected -> $isTv');
    } catch (e) {
      log('Bootstrap: isTv check skipped: $e');
    }
  }

  if (isMobile) {
    try {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } catch (e) {
      log('Bootstrap: Immersive mode setup bypassed: $e');
    }
  }

  // 1. تهيئة Supabase إذا توفرت المتغيرات
  if (ApiConstants.supabaseUrl.isNotEmpty && ApiConstants.supabaseAnonKey.isNotEmpty) {
    try {
      await Supabase.initialize(
        url: ApiConstants.supabaseUrl,
        anonKey: ApiConstants.supabaseAnonKey,
      );
      log('Supabase: Initialized successfully.');
    } catch (e) {
      log('Supabase init error: $e');
    }
  }

  // 2. ⚡ تشغيل Web3 في الخلفية بدون حجب الواجهة
  unawaited(
    Web3Service.instance.initialize().catchError((Object e) {
      log('Bootstrap: Web3 init deferred: $e');
    }),
  );

  final llmAgent = LlmAgent(openRouterApiKey: ApiConstants.openRouterApiKey);
  final launcherRepository = LauncherRepository(
    llmAgent: llmAgent,
  );

  // 3. ⚡ تشغيل محركات الصوت (TTS & Speech) في الخلفية دون تجميد شاشة البداية
  unawaited(
    launcherRepository.assistant.initializeEngines().catchError((Object e) {
      log('Bootstrap: Audio engines init bypassed: $e');
    }),
  );

  // 4. 🌙 تسجيل محرك المزامنة التلقائية بالخلفية عبر WorkManager (لأندرويد وFire TV)
  if (Platform.isAndroid) {
    unawaited(() async {
      try {
        await Workmanager().initialize(
          callbackDispatcher,
          isInDebugMode: flavor == AppFlavor.development,
        );

        await Workmanager().registerPeriodicTask(
          'beacon_vault_sync_periodic',
          beaconPeriodicSyncTask,
          frequency: const Duration(minutes: 15),
          constraints: Constraints(
            networkType: NetworkType.connected,
          ),
          existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        );
        log('Bootstrap: 🌙 WorkManager periodic background sync registered.');
      } catch (e) {
        log('Bootstrap: WorkManager init error: $e');
      }
    }());
  }

  // 5. قراءة الإعدادات بمهلة قصيرة جداً (1.5 ثانية) لضمان عدم التعليق على SQLite
  AppSettingEntity initialSettings;
  try {
    initialSettings = await launcherRepository.settings
        .getSettings()
        .timeout(const Duration(milliseconds: 1500));
  } catch (e) {
    log('Bootstrap: Settings fallback used: $e');
    initialSettings = AppSettingEntity(
      id: 'local_device_settings',
      userPersona: isTv ? 'blind_accessible' : 'digital_minimalist',
      hasCompletedOnboarding: isTv ? true : false,
      speechRate: 0.5,
      hapticsEnabled: true,
      soundCuesEnabled: true,
      isHighContrast: isTv ? true : false,
      spatialWhisperEnabled: false,
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

  // 6. 🚀 تشغيل الواجهة فوراً
  runApp(
    App(
      launcherRepository: launcherRepository,
      initialSettings: initialSettings,
      isTv: isTv,
    ),
  );
}