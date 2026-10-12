// lib/main_windows.dart
import 'dart:async';
import 'dart:developer';

import 'package:beacon_os/core/constants/api_constants.dart';
import 'package:beacon_os/desktop/desktop_app.dart';
import 'package:cloud_sync_api/cloud_sync_api.dart';
import 'package:flutter/material.dart';
import 'package:launcher_repository/launcher_repository.dart';
import 'package:local_vault_api/local_vault_api.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:system_hardware_api/system_hardware_api.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. تهيئة سحابة Supabase بأمان
  if (ApiConstants.supabaseUrl.isNotEmpty &&
      ApiConstants.supabaseAnonKey.isNotEmpty) {
    try {
      await Supabase.initialize(
        url: ApiConstants.supabaseUrl,
        anonKey: ApiConstants.supabaseAnonKey,
      );
      log('Desktop Main: Supabase connected successfully.');
    } catch (e) {
      log('Desktop Main: Supabase init error: $e');
    }
  }

  // 2. تشغيل المحركات الأساسية (Drift SQLite + Cloud Sync + Hardware)
  final database = AppDatabase();
  final cloudSync = CloudSyncClient();
  final hardware = HardwareClient();

  // 3. حقن المستودعات المشتركة لسطح المكتب
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

  // تفعيل الاستماع اللحظي لتغييرات السحابة على سطح المكتب
  commsRepo.initializeRealtimeSync();
  topologyRepo.initializeRealtimeSync();

  // جلب إعدادات الثيم الحالية من الخزنة المحلية
  AppSetting initialSettings;
  try {
    initialSettings = await settingsRepo.getSettings();
  } catch (_) {
    initialSettings = const AppSetting(
      id: 'local_device_settings',
      userPersona: 'digital_minimalist',
      hasCompletedOnboarding: true,
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
      updatedAt: null,
      isSynced: false,
    );
  }

  runApp(
    DesktopApp(
      taskRepository: taskRepo,
      focusAlarmsRepository: focusRepo,
      commsRepository: commsRepo,
      settingsRepository: settingsRepo,
      topologyRepository: topologyRepo,
      initialSettings: initialSettings,
    ),
  );
}