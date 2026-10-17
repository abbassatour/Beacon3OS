// packages/launcher_repository/lib/src/domains/settings_repository.dart
import 'dart:developer';

import 'package:cloud_sync_api/cloud_sync_api.dart';
import 'package:drift/drift.dart';
import 'package:local_vault_api/local_vault_api.dart' as db;

import '../models/app_setting_entity.dart';
import '../mappers/app_setting_mapper.dart';

/// العقد النطاقي المخصص لإدارة إعدادات النظام وهوية المستخدم
abstract class SettingsRepository {
  /// الاستماع اللحظي لتغييرات الإعدادات
  Stream<AppSettingEntity> watchSettings();

  /// جلب الإعدادات الحالية لمرة واحدة
  Future<AppSettingEntity> getSettings();

  /// تحديث حقل أو أكثر في الإعدادات محلياً وسحابياً عبر الكيان النقي
  Future<void> updateSettings(AppSettingUpdatePayload updated);

  /// فحص هل أتم المستخدم مرحلة الإعداد والترحيب الأولي
  Future<bool> isOnboardingCompleted();

  /// اعتماد إتمام التهيئة وتعيين الهوية وسرعة الصوت ومستوى التباين
  Future<void> completeOnboarding({
    required String persona,
    required bool isHighContrast,
    required double speechRate,
  });

  /// استعادة تفضيلات المستخدم من Supabase إلى قاعدة البيانات المحلية
  Future<void> restoreSettingsFromCloud();

  /// فحص ومزامنة أي تعديل تم على الإعدادات أثناء انقطاع الإنترنت
  Future<void> syncPendingSettings();
}

/// التنفيذ المدمج بين قاعدة بيانات Drift وسحابة Supabase
class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl({
    required db.AppDatabase database,
    required CloudSyncClient cloudSync,
  })  : _db = database,
        _cloud = cloudSync;

  final db.AppDatabase _db;
  final CloudSyncClient _cloud;

  @override
  Stream<AppSettingEntity> watchSettings() {
    return _db.watchSettings().map((settings) => settings.toEntity());
  }

  @override
  Future<AppSettingEntity> getSettings() async {
    final settings = await _db.getSettings();
    return settings.toEntity();
  }

  @override
  Future<void> updateSettings(AppSettingUpdatePayload updated) async {
    // 1. الحفظ الفوري محلياً في Drift (Offline-First) بعد التحويل لـ Companion
    await _db.updateSettings(updated.toCompanion());

    // 2. المزامنة السحابية غير المعطلة
    final current = await _db.getSettings();
    _cloud.syncSettings(_mapSettingsToCloud(current.toEntity())).catchError((Object error) {
      log('SettingsRepository: Cloud sync deferred: $error');
    });
  }

  @override
  Future<bool> isOnboardingCompleted() => _db.hasCompletedOnboarding();

  @override
  Future<void> completeOnboarding({
    required String persona,
    required bool isHighContrast,
    required double speechRate,
  }) async {
    await _db.completeOnboarding(
      persona: persona,
      isHighContrast: isHighContrast,
      speechRate: speechRate,
    );

    final current = await _db.getSettings();
    await _cloud.syncSettings(_mapSettingsToCloud(current.toEntity())).catchError((Object error) {
      log('SettingsRepository: Cloud onboarding sync deferred: $error');
    });

    log('SettingsRepository: Onboarding completed for persona: $persona');
  }

  @override
  Future<void> restoreSettingsFromCloud() async {
    if (!_cloud.isAuthenticated) return;

    try {
      final cloudSettings = await _cloud.fetchCloudSettings();
      if (cloudSettings != null) {
        await _db.updateSettings(
          db.AppSettingsCompanion(
            userPersona: Value(
              cloudSettings['user_persona'] as String? ?? 'digital_minimalist',
            ),
            hasCompletedOnboarding: Value(
              cloudSettings['has_completed_onboarding'] as bool? ?? false,
            ),
            speechRate: Value(
              (cloudSettings['speech_rate'] as num?)?.toDouble() ?? 0.5,
            ),
            hapticsEnabled: Value(
              cloudSettings['haptics_enabled'] as bool? ?? true,
            ),
            soundCuesEnabled: Value(
              cloudSettings['sound_cues_enabled'] as bool? ?? true,
            ),
            isHighContrast: Value(
              cloudSettings['is_high_contrast'] as bool? ?? false,
            ),
            defaultPriority: Value(
              cloudSettings['default_priority'] as String? ?? 'medium',
            ),
            autoArchiveCompleted: Value(
              cloudSettings['auto_archive_completed'] as bool? ?? true,
            ),
            speakDueDatesAloud: Value(
              cloudSettings['speak_due_dates_aloud'] as bool? ?? true,
            ),
            autoDialEmergency: Value(
              cloudSettings['auto_dial_emergency'] as bool? ?? true,
            ),
            shareGpsOnSos: Value(
              cloudSettings['share_gps_on_sos'] as bool? ?? true,
            ),
            speakIncomingSms: Value(
              cloudSettings['speak_incoming_sms'] as bool? ?? true,
            ),
            voiceChimeHalfway: Value(
              cloudSettings['voice_chime_halfway'] as bool? ?? true,
            ),
            vibrateOnSessionFinish: Value(
              cloudSettings['vibrate_on_session_finish'] as bool? ?? true,
            ),
            syncAlarmsWithAndroidClock: Value(
              cloudSettings['sync_alarms_with_android_clock'] as bool? ?? true,
            ),
            visionInspectionDetail: Value(
              cloudSettings['vision_inspection_detail'] as String? ?? 'concise',
            ),
            autoFlashlightInDark: Value(
              cloudSettings['auto_flashlight_in_dark'] as bool? ?? true,
            ),
            preferredCurrency: Value(
              cloudSettings['preferred_currency'] as String? ?? 'USD / Local',
            ),
            isSynced: const Value(true),
          ),
        );
        log('SettingsRepository: Settings restored from cloud successfully.');
      }
    } catch (e, st) {
      log('SettingsRepository: Failed to restore cloud settings: $e', stackTrace: st);
    }
  }

  @override
  Future<void> syncPendingSettings() async {
    if (!_cloud.isAuthenticated) return;

    try {
      final settings = await _db.getSettings();
      if (!settings.isSynced) {
        await _cloud.syncSettings(_mapSettingsToCloud(settings.toEntity()));
        await _db.updateSettings(const db.AppSettingsCompanion(isSynced: Value(true)));
        log('SettingsRepository: Pending offline settings synced.');
      }
    } catch (e) {
      log('SettingsRepository: Pending settings sync error: $e');
    }
  }

  /// تحويل كائن الكيان النقي إلى خريطة متوافقة مع Supabase
  Map<String, dynamic> _mapSettingsToCloud(AppSettingEntity s) {
    return {
      'id': s.id,
      'user_persona': s.userPersona,
      'has_completed_onboarding': s.hasCompletedOnboarding,
      'speech_rate': s.speechRate,
      'haptics_enabled': s.hapticsEnabled,
      'sound_cues_enabled': s.soundCuesEnabled,
      'is_high_contrast': s.isHighContrast,
      'default_priority': s.defaultPriority,
      'auto_archive_completed': s.autoArchiveCompleted,
      'speak_due_dates_aloud': s.speakDueDatesAloud,
      'auto_dial_emergency': s.autoDialEmergency,
      'share_gps_on_sos': s.shareGpsOnSos,
      'speak_incoming_sms': s.speakIncomingSms,
      'voice_chime_halfway': s.voiceChimeHalfway,
      'vibrate_on_session_finish': s.vibrateOnSessionFinish,
      'sync_alarms_with_android_clock': s.syncAlarmsWithAndroidClock,
      'vision_inspection_detail': s.visionInspectionDetail,
      'auto_flashlight_in_dark': s.autoFlashlightInDark,
      'preferred_currency': s.preferredCurrency,
    };
  }
}