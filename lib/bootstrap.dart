// lib/bootstrap.dart
import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:beacon_os/app/app.dart';
import 'package:beacon_os/core/audio/sound_controller.dart';
import 'package:beacon_os/core/constants/api_constants.dart';
import 'package:beacon_os/core/haptics/haptic_manager.dart';
import 'package:beacon_os/core/services/onesignal_service.dart';
import 'package:beacon_os/core/services/revenuecat_service.dart';
import 'package:bloc/bloc.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:launcher_repository/launcher_repository.dart';
import 'package:local_vault_api/local_vault_api.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:voice_ai_api/voice_ai_api.dart';

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

Future<void> bootstrap() async {
  FlutterError.onError = (details) {
    log(details.exceptionAsString(), stackTrace: details.stack);
  };

  Bloc.observer = const AppBlocObserver();
  WidgetsFlutterBinding.ensureInitialized();

  final isMobile = Platform.isAndroid || Platform.isIOS;

  // 1. وضع الشاشة الكاملة الحقيقي للهواتف فقط
  if (isMobile) {
    try {
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.immersiveSticky,
      );
    } catch (e) {
      log('Bootstrap: Immersive mode setup bypassed: $e');
    }
  }

  // 2. تهيئة Supabase بأمان تام
  if (ApiConstants.supabaseUrl.isNotEmpty &&
      ApiConstants.supabaseAnonKey.isNotEmpty) {
    try {
      await Supabase.initialize(
        url: ApiConstants.supabaseUrl,
        anonKey: ApiConstants.supabaseAnonKey,
      );
      log('Supabase: Initialized successfully.');
    } catch (e) {
      log('Supabase init error: $e');
    }
  } else {
    log('Supabase: Skipped initialization (Keys are empty).');
  }

  // 3. تهيئة خدمات السحابة والاشتراكات للهواتف فقط مع حماية زمنية
  if (isMobile) {
    try {
      await RevenueCatService.initialize().timeout(const Duration(seconds: 2));
    } catch (e) {
      log('Bootstrap: RevenueCat init deferred: $e');
    }

    try {
      await OneSignalService.initialize().timeout(const Duration(seconds: 2));
    } catch (e) {
      log('Bootstrap: OneSignal init deferred: $e');
    }
  } else {
    log('Bootstrap: Skipped mobile-only services (OneSignal, RevenueCat) on Desktop.');
  }

  // 4. تهيئة وكيل الذكاء الاصطناعي ومستودع النظام
  final llmAgent = LlmAgent(openRouterApiKey: ApiConstants.openRouterApiKey);
  final launcherRepository = LauncherRepository(llmAgent: llmAgent);

  // ⚡️ 5. تهيئة محركات الصوت (Speech-To-Text و TTS) مع حماية ضد التعليق
  try {
    await launcherRepository.assistant
        .initializeEngines()
        .timeout(const Duration(seconds: 2));
    log('Bootstrap: Audio engines initialized.');
  } catch (e) {
    log('Bootstrap: Audio engines init timed out or bypassed (Desktop/Emulator fallback): $e');
  }

  // 🎨 6. قراءة الإعدادات مع كائن احتياطي
  AppSetting initialSettings;
  try {
    initialSettings = await launcherRepository.settings
        .getSettings()
        .timeout(const Duration(seconds: 2));
  } catch (e) {
    log('Bootstrap: Settings fallback triggered: $e');
    initialSettings = AppSetting(
      id: 'local_device_settings',
      userPersona: 'digital_minimalist',
      hasCompletedOnboarding: false,
      speechRate: 0.5,
      hapticsEnabled: true,
      soundCuesEnabled: true,
      isHighContrast: false,
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

  // 🎛️ 7. ضبط التفضيلات فوراً
  SoundController.instance.isEnabled = initialSettings.soundCuesEnabled;
  HapticManager.instance.isEnabled = initialSettings.hapticsEnabled;
  unawaited(launcherRepository.assistant.setSpeechRate(initialSettings.speechRate));

  // 🚀 8. إطلاق الواجهة فوراً
  runApp(
    App(
      launcherRepository: launcherRepository,
      initialSettings: initialSettings,
    ),
  );
}