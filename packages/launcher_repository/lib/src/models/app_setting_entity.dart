// packages/launcher_repository/lib/src/models/app_setting_entity.dart
import 'package:equatable/equatable.dart';

/// الكيان النقي الخاص بإعدادات النظام الذي ستتعامل معه واجهة المستخدم (UI)
class AppSettingEntity extends Equatable {
  const AppSettingEntity({
    required this.id,
    required this.userPersona,
    required this.hasCompletedOnboarding,
    required this.speechRate,
    required this.hapticsEnabled,
    required this.soundCuesEnabled,
    required this.isHighContrast,
    required this.defaultPriority,
    required this.autoArchiveCompleted,
    required this.speakDueDatesAloud,
    required this.autoDialEmergency,
    required this.shareGpsOnSos,
    required this.speakIncomingSms,
    required this.voiceChimeHalfway,
    required this.vibrateOnSessionFinish,
    required this.syncAlarmsWithAndroidClock,
    required this.visionInspectionDetail,
    required this.autoFlashlightInDark,
    required this.preferredCurrency,
    required this.updatedAt,
    required this.isSynced,
  });

  final String id;
  final String userPersona;
  final bool hasCompletedOnboarding;
  final double speechRate;
  final bool hapticsEnabled;
  final bool soundCuesEnabled;
  final bool isHighContrast;
  final String defaultPriority;
  final bool autoArchiveCompleted;
  final bool speakDueDatesAloud;
  final bool autoDialEmergency;
  final bool shareGpsOnSos;
  final bool speakIncomingSms;
  final bool voiceChimeHalfway;
  final bool vibrateOnSessionFinish;
  final bool syncAlarmsWithAndroidClock;
  final String visionInspectionDetail;
  final bool autoFlashlightInDark;
  final String preferredCurrency;
  final DateTime updatedAt;
  final bool isSynced;

  @override
  List<Object?> get props => [
        id, userPersona, hasCompletedOnboarding, speechRate, hapticsEnabled,
        soundCuesEnabled, isHighContrast, defaultPriority, autoArchiveCompleted,
        speakDueDatesAloud, autoDialEmergency, shareGpsOnSos, speakIncomingSms,
        voiceChimeHalfway, vibrateOnSessionFinish, syncAlarmsWithAndroidClock,
        visionInspectionDetail, autoFlashlightInDark, preferredCurrency,
        updatedAt, isSynced,
      ];
}

/// كائن حمولة التحديث النقي (يستبدل AppSettingsCompanion الخاص بـ Drift)
class AppSettingUpdatePayload {
  const AppSettingUpdatePayload({
    this.userPersona,
    this.hasCompletedOnboarding,
    this.speechRate,
    this.hapticsEnabled,
    this.soundCuesEnabled,
    this.isHighContrast,
    this.defaultPriority,
    this.autoArchiveCompleted,
    this.speakDueDatesAloud,
    this.autoDialEmergency,
    this.shareGpsOnSos,
    this.speakIncomingSms,
    this.voiceChimeHalfway,
    this.vibrateOnSessionFinish,
    this.syncAlarmsWithAndroidClock,
    this.visionInspectionDetail,
    this.autoFlashlightInDark,
    this.preferredCurrency,
    this.isSynced,
  });

  final String? userPersona;
  final bool? hasCompletedOnboarding;
  final double? speechRate;
  final bool? hapticsEnabled;
  final bool? soundCuesEnabled;
  final bool? isHighContrast;
  final String? defaultPriority;
  final bool? autoArchiveCompleted;
  final bool? speakDueDatesAloud;
  final bool? autoDialEmergency;
  final bool? shareGpsOnSos;
  final bool? speakIncomingSms;
  final bool? voiceChimeHalfway;
  final bool? vibrateOnSessionFinish;
  final bool? syncAlarmsWithAndroidClock;
  final String? visionInspectionDetail;
  final bool? autoFlashlightInDark;
  final String? preferredCurrency;
  final bool? isSynced;
}