// lib/main_firetv.dart
import 'dart:async';
import 'dart:developer';

import 'package:beacon_os/core/constants/api_constants.dart';
import 'package:beacon_os/tv/tv.dart'; // 👈 الاستيراد الجديد المباشر
import 'package:cloud_sync_api/cloud_sync_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:launcher_repository/launcher_repository.dart';
import 'package:local_vault_api/local_vault_api.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:system_hardware_api/system_hardware_api.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. تثبيت اتجاه الشاشة أفقياً دائماً للتلفزيون
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // 2. إخفاء أشرطة الحالة الافتراضية للاندرويد لشاشات التلفزيون
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // 3. تهيئة سحابة Supabase لمزامنة غرفة المعيشة مع الهاتف
  if (ApiConstants.supabaseUrl.isNotEmpty &&
      ApiConstants.supabaseAnonKey.isNotEmpty) {
    try {
      await Supabase.initialize(
        url: ApiConstants.supabaseUrl,
        anonKey: ApiConstants.supabaseAnonKey,
      );
      log('FireTV Main: Supabase connected for Living Room Sync.');
    } catch (e) {
      log('FireTV Main: Supabase init error: $e');
    }
  }

  // 4. تشغيل الخزنة المحلية ومحركات العتاد
  final database = AppDatabase();
  final cloudSync = CloudSyncClient();
  final hardware = HardwareClient();

  // 5. تهيئة المستودعات السحابية والمحلية
  final taskRepo = TaskAgendaRepositoryImpl(
    database: database,
    cloudSync: cloudSync,
  );
  final focusRepo = FocusAlarmsRepositoryImpl(
    database: database,
    cloudSync: cloudSync,
    hardware: hardware,
  );
  final commsRepo = CommsRepositoryImpl(
    database: database,
    cloudSync: cloudSync,
    hardware: hardware,
  );
  final settingsRepo = SettingsRepositoryImpl(
    database: database,
    cloudSync: cloudSync,
  );
  final topologyRepo = TopologyRepositoryImpl(
    database: database,
    cloudSync: cloudSync,
  );

  // تفعيل الاستماع اللحظي لأوامر الطوارئ واستدعاءات Alexa+
  commsRepo.initializeRealtimeSync();
  topologyRepo.initializeRealtimeSync();

  // جلب إعدادات الخزنة
  AppSetting initialSettings;
  try {
    initialSettings = await settingsRepo.getSettings();
  } catch (_) {
    initialSettings = AppSetting(
      id: 'local_device_settings',
      userPersona: 'blind_accessible',
      hasCompletedOnboarding: true,
      speechRate: 0.5,
      hapticsEnabled: true,
      soundCuesEnabled: true,
      isHighContrast: true, // تباين عالي افتراضي للقراءة الواضحة من مسافة 3 أمتار
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
      updatedAt: DateTime(2026),
      isSynced: false,
    );
  }

  // 🚀 تشغيل TvApp الجديدة بنظام الـ Cubits النظيف
  runApp(
    TvApp(
      taskRepository: taskRepo,
      focusAlarmsRepository: focusRepo,
      commsRepository: commsRepo,
      settingsRepository: settingsRepo,
      topologyRepository: topologyRepo,
      initialSettings: initialSettings,
    ),
  );
}