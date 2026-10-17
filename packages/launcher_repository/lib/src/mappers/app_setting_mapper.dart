// packages/launcher_repository/lib/src/mappers/app_setting_mapper.dart
import 'package:drift/drift.dart';
import 'package:local_vault_api/local_vault_api.dart' as db;
import '../models/app_setting_entity.dart';

/// تحويل بيانات الجدول القادمة من Drift إلى الكيان النقي (Entity)
extension AppSettingDataToEntity on db.AppSetting {
  AppSettingEntity toEntity() {
    return AppSettingEntity(
      id: id,
      userPersona: userPersona,
      hasCompletedOnboarding: hasCompletedOnboarding,
      speechRate: speechRate,
      hapticsEnabled: hapticsEnabled,
      soundCuesEnabled: soundCuesEnabled,
      isHighContrast: isHighContrast,
      defaultPriority: defaultPriority,
      autoArchiveCompleted: autoArchiveCompleted,
      speakDueDatesAloud: speakDueDatesAloud,
      autoDialEmergency: autoDialEmergency,
      shareGpsOnSos: shareGpsOnSos,
      speakIncomingSms: speakIncomingSms,
      voiceChimeHalfway: voiceChimeHalfway,
      vibrateOnSessionFinish: vibrateOnSessionFinish,
      syncAlarmsWithAndroidClock: syncAlarmsWithAndroidClock,
      visionInspectionDetail: visionInspectionDetail,
      autoFlashlightInDark: autoFlashlightInDark,
      preferredCurrency: preferredCurrency,
      updatedAt: updatedAt,
      isSynced: isSynced,
    );
  }
}

/// تحويل حمولة التحديث النقية إلى كائن Companion الخاص بـ Drift للحفظ
extension AppSettingUpdatePayloadToCompanion on AppSettingUpdatePayload {
  db.AppSettingsCompanion toCompanion() {
    return db.AppSettingsCompanion(
      userPersona: userPersona != null ? Value(userPersona!) : const Value.absent(),
      hasCompletedOnboarding: hasCompletedOnboarding != null ? Value(hasCompletedOnboarding!) : const Value.absent(),
      speechRate: speechRate != null ? Value(speechRate!) : const Value.absent(),
      hapticsEnabled: hapticsEnabled != null ? Value(hapticsEnabled!) : const Value.absent(),
      soundCuesEnabled: soundCuesEnabled != null ? Value(soundCuesEnabled!) : const Value.absent(),
      isHighContrast: isHighContrast != null ? Value(isHighContrast!) : const Value.absent(),
      defaultPriority: defaultPriority != null ? Value(defaultPriority!) : const Value.absent(),
      autoArchiveCompleted: autoArchiveCompleted != null ? Value(autoArchiveCompleted!) : const Value.absent(),
      speakDueDatesAloud: speakDueDatesAloud != null ? Value(speakDueDatesAloud!) : const Value.absent(),
      autoDialEmergency: autoDialEmergency != null ? Value(autoDialEmergency!) : const Value.absent(),
      shareGpsOnSos: shareGpsOnSos != null ? Value(shareGpsOnSos!) : const Value.absent(),
      speakIncomingSms: speakIncomingSms != null ? Value(speakIncomingSms!) : const Value.absent(),
      voiceChimeHalfway: voiceChimeHalfway != null ? Value(voiceChimeHalfway!) : const Value.absent(),
      vibrateOnSessionFinish: vibrateOnSessionFinish != null ? Value(vibrateOnSessionFinish!) : const Value.absent(),
      syncAlarmsWithAndroidClock: syncAlarmsWithAndroidClock != null ? Value(syncAlarmsWithAndroidClock!) : const Value.absent(),
      visionInspectionDetail: visionInspectionDetail != null ? Value(visionInspectionDetail!) : const Value.absent(),
      autoFlashlightInDark: autoFlashlightInDark != null ? Value(autoFlashlightInDark!) : const Value.absent(),
      preferredCurrency: preferredCurrency != null ? Value(preferredCurrency!) : const Value.absent(),
      isSynced: isSynced != null ? Value(isSynced!) : const Value.absent(),
    );
  }
}