// packages/launcher_repository/lib/src/domains/settings_repository.dart
import 'dart:developer';

import 'package:cloud_sync_api/cloud_sync_api.dart';
import 'package:drift/drift.dart';
import 'package:equatable/equatable.dart';
import 'package:local_vault_api/local_vault_api.dart' as db;

import '../mappers/app_setting_mapper.dart';
import '../models/app_setting_entity.dart';

/// كائن يمثل فحصاً بصرياً محفوظاً في الخزنة
class VisionScanRecord extends Equatable {
  const VisionScanRecord({
    required this.id,
    required this.mode,
    required this.prompt,
    required this.description,
    required this.createdAt,
  });

  final String id;
  final String mode;
  final String prompt;
  final String description;
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, mode, prompt, description, createdAt];
}

/// العقد النطاقي المخصص لإدارة إعدادات النظام وهوية المستخدم وفحوصات الرؤية
abstract class SettingsRepository {
  /// الاستماع اللحظي لتغييرات الإعدادات
  Stream<AppSettingEntity> watchSettings();

  /// جلب الإعدادات الحالية لمرة واحدة
  Future<AppSettingEntity> getSettings();

  /// تحديث حقل أو أكثر في الإعدادات محلياً وسحابياً عبر الكيان النقي
  Future<void> updateSettings(AppSettingUpdatePayload updated);

  /// فحص هل أتم المستخدم مرحلة الإعداد والترحيب الأولي
  Future<bool> isOnboardingCompleted();

  /// اعتماد إتمام التهيئة وتعيين الهوية وسرعة الصوت ومستوى التباين وخيار الهمس
  Future<void> completeOnboarding({
    required String persona,
    required bool isHighContrast,
    required double speechRate,
    bool? spatialWhisperEnabled,
  });

  /// توثيق وحفظ فحص بصري جديد في الخزنة المحلية ومزامنته سحابياً
  Future<void> recordVisionScan({
    required String mode,
    required String prompt,
    required String description,
  });

  /// 👁️ مراقبة الفحوصات البصرية المحفوظة في الخزنة (أرشيف الطابق -1)
  Stream<List<VisionScanRecord>> watchVisionScans({int limit = 30});

  /// استعادة تفضيلات المستخدم من Supabase إلى قاعدة البيانات المحلية بفض نزاعات زمني
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
    // 1. الحفظ الفوري محلياً في Drift مع طابع زمني موحد
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
    bool? spatialWhisperEnabled,
  }) async {
    await _db.completeOnboarding(
      persona: persona,
      isHighContrast: isHighContrast,
      speechRate: speechRate,
      spatialWhisperEnabled: spatialWhisperEnabled,
    );

    final current = await _db.getSettings();
    await _cloud.syncSettings(_mapSettingsToCloud(current.toEntity())).catchError((Object error) {
      log('SettingsRepository: Cloud onboarding sync deferred: $error');
    });

    log('SettingsRepository: Onboarding completed for persona: $persona (whisper: ${current.spatialWhisperEnabled})');
  }

  @override
  Future<void> recordVisionScan({
    required String mode,
    required String prompt,
    required String description,
  }) async {
    try {
      final id = await _db.insertVisionScan(
        mode: mode,
        prompt: prompt,
        description: description,
      );
      _cloud
          .syncVisionScan(
            id: id,
            mode: mode,
            prompt: prompt,
            description: description,
          )
          .catchError((Object error) {
        log('SettingsRepository: Cloud vision scan sync deferred [$id]: $error');
      });
      log('SettingsRepository: 👁️ Vision scan recorded in local vault (ID: $id)');
    } catch (e) {
      log('SettingsRepository: Error recording vision scan: $e');
    }
  }

  @override
  Stream<List<VisionScanRecord>> watchVisionScans({int limit = 30}) {
    return _db.watchRecentVisionScans(limit: limit).map(
          (list) => list
              .map(
                (v) => VisionScanRecord(
                  id: v.id,
                  mode: v.mode,
                  prompt: v.prompt,
                  description: v.description,
                  createdAt: v.createdAt,
                ),
              )
              .toList(),
        );
  }

  @override
  Future<void> restoreSettingsFromCloud() async {
    if (!_cloud.isAuthenticated) return;

    try {
      final cloudSettings = await _cloud.fetchCloudSettings();
      if (cloudSettings != null) {
        final local = await _db.getSettings();
        final cloudUpdatedAtStr = cloudSettings['updated_at'] as String?;
        final cloudUpdatedAt =
            cloudUpdatedAtStr != null ? DateTime.tryParse(cloudUpdatedAtStr) : null;

        // فض النزاع LWW: لا نمسح التعديل المحلي الأحدث إذا كان غير متزامن
        final shouldApply = local.isSynced ||
            (cloudUpdatedAt != null && cloudUpdatedAt.isAfter(local.updatedAt));

        if (!shouldApply) {
          log('SettingsRepository: Local settings are newer than cloud. Skipping cloud overwrite.');
          return;
        }

        final persona = cloudSettings['user_persona'] as String? ?? 'digital_minimalist';

        await _db.updateSettings(
          db.AppSettingsCompanion(
            userPersona: Value(persona),
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
            spatialWhisperEnabled: Value(
              cloudSettings['spatial_whisper_enabled'] as bool? ?? (persona == 'blind_accessible'),
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
            updatedAt: Value(cloudUpdatedAt ?? DateTime.now().toUtc()),
            isSynced: const Value(true),
          ),
        );
        log('SettingsRepository: ⚡ Settings restored and reconciled with cloud successfully.');
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
        log('SettingsRepository: ⚡ Pending offline settings synced.');
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
      'spatial_whisper_enabled': s.spatialWhisperEnabled,
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
      'updated_at': s.updatedAt.toUtc().toIso8601String(),
    };
  }
}