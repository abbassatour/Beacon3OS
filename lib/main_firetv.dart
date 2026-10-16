// lib/main_firetv.dart
import 'dart:async';
import 'dart:developer';

import 'package:beacon_os/core/constants/api_constants.dart';
import 'package:beacon_os/fire_tv/fire_tv_app.dart';
import 'package:cloud_sync_api/cloud_sync_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:launcher_repository/launcher_repository.dart';
import 'package:local_vault_api/local_vault_api.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:system_hardware_api/system_hardware_api.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. ØªØ«Ø¨ÙŠØª Ø§ØªØ¬Ø§Ù‡ Ø§Ù„Ø´Ø§Ø´Ø© Ø£ÙÙ‚ÙŠØ§Ù‹ Ø¯Ø§Ø¦Ù…Ø§Ù‹ Ù„Ù„ØªÙ„ÙØ²ÙŠÙˆÙ†
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // 2. Ø¥Ø®ÙØ§Ø¡ Ø£Ø´Ø±Ø·Ø© Ø§Ù„Ø­Ø§Ù„Ø© Ø§Ù„Ø§ÙØªØ±Ø§Ø¶ÙŠØ© Ù„Ù„Ø§Ù†Ø¯Ø±ÙˆÙŠØ¯ Ù„Ø´Ø§Ø´Ø§Øª Ø§Ù„ØªÙ„ÙØ²ÙŠÙˆÙ†
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // 3. ØªÙ‡ÙŠØ¦Ø© Ø³Ø­Ø§Ø¨Ø© Supabase Ù„Ù…Ø²Ø§Ù…Ù†Ø© ØºØ±ÙØ© Ø§Ù„Ù…Ø¹ÙŠØ´Ø© Ù…Ø¹ Ø§Ù„Ù‡Ø§ØªÙ
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

  // 4. ØªØ´ØºÙŠÙ„ Ø§Ù„Ø®Ø²Ù†Ø© Ø§Ù„Ù…Ø­Ù„ÙŠØ© ÙˆÙ…Ø­Ø±ÙƒØ§Øª Ø§Ù„Ø¹ØªØ§Ø¯
  final database = AppDatabase();
  final cloudSync = CloudSyncClient();
  final hardware = HardwareClient();

  // 5. ØªÙ‡ÙŠØ¦Ø© Ø§Ù„Ù…Ø³ØªÙˆØ¯Ø¹Ø§Øª Ø§Ù„Ø³Ø­Ø§Ø¨ÙŠØ© ÙˆØ§Ù„Ù…Ø­Ù„ÙŠØ©
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

  // ØªÙØ¹ÙŠÙ„ Ø§Ù„Ø§Ø³ØªÙ…Ø§Ø¹ Ø§Ù„Ù„Ø­Ø¸ÙŠ Ù„Ø£ÙˆØ§Ù…Ø± Ø§Ù„Ø·ÙˆØ§Ø±Ø¦ ÙˆØ§Ø³ØªØ¯Ø¹Ø§Ø¡Ø§Øª Alexa+
  commsRepo.initializeRealtimeSync();
  topologyRepo.initializeRealtimeSync();

  // Ø¬Ù„Ø¨ Ø¥Ø¹Ø¯Ø§Ø¯Ø§Øª Ø§Ù„Ø®Ø²Ù†Ø©
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
      isHighContrast: true, // ØªØ¨Ø§ÙŠÙ† Ø¹Ø§Ù„ÙŠ Ø§ÙØªØ±Ø§Ø¶ÙŠ Ù„Ù„Ù‚Ø±Ø§Ø¡Ø© Ø§Ù„ÙˆØ§Ø¶Ø­Ø© Ù…Ù† Ù…Ø³Ø§ÙØ© 3 Ø£Ù…ØªØ§Ø±
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

  runApp(
    FireTvApp(
      taskRepository: taskRepo,
      focusAlarmsRepository: focusRepo,
      commsRepository: commsRepo,
      settingsRepository: settingsRepo,
      topologyRepository: topologyRepo,
      initialSettings: initialSettings,
    ),
  );
}
