// lib/preferences/cubit/preferences_state.dart
import 'package:equatable/equatable.dart';
import 'package:local_vault_api/local_vault_api.dart';

enum PreferencesStatus { initial, loading, success, error }

class PreferencesState extends Equatable {
  const PreferencesState({
    this.status = PreferencesStatus.initial,
    this.settings,
    this.errorMessage,
  });

  final PreferencesStatus status;
  final AppSetting? settings;
  final String? errorMessage;

  // ===========================================================================
  // 🎛️ Getters مساعدة ومحمية بقيم افتراضية لجميع الطوابق والغرف
  // ===========================================================================
  double get speechRate => settings?.speechRate ?? 0.5;
  bool get hapticsEnabled => settings?.hapticsEnabled ?? true;
  bool get soundCuesEnabled => settings?.soundCuesEnabled ?? true;
  bool get isHighContrast => settings?.isHighContrast ?? false;

  String get defaultPriority => settings?.defaultPriority ?? 'medium';
  bool get autoArchiveCompleted => settings?.autoArchiveCompleted ?? true;
  bool get speakDueDatesAloud => settings?.speakDueDatesAloud ?? true;

  bool get autoDialEmergency => settings?.autoDialEmergency ?? true;
  bool get shareGpsOnSos => settings?.shareGpsOnSos ?? true;
  bool get speakIncomingSms => settings?.speakIncomingSms ?? true;

  bool get voiceChimeHalfway => settings?.voiceChimeHalfway ?? true;
  bool get vibrateOnSessionFinish => settings?.vibrateOnSessionFinish ?? true;
  bool get syncAlarmsWithAndroidClock =>
      settings?.syncAlarmsWithAndroidClock ?? true;

  String get visionInspectionDetail =>
      settings?.visionInspectionDetail ?? 'concise';
  bool get autoFlashlightInDark => settings?.autoFlashlightInDark ?? true;
  String get preferredCurrency => settings?.preferredCurrency ?? 'USD / Local';

  PreferencesState copyWith({
    PreferencesStatus? status,
    AppSetting? settings,
    String? errorMessage,
  }) {
    return PreferencesState(
      status: status ?? this.status,
      settings: settings ?? this.settings,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, settings, errorMessage];
}
