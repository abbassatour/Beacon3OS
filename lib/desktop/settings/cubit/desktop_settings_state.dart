// lib/desktop/settings/cubit/desktop_settings_state.dart
import 'package:equatable/equatable.dart';
import 'package:launcher_repository/launcher_repository.dart';

enum DesktopSettingsStatus { initial, loading, success, syncing, error }

class DesktopSettingsState extends Equatable {
  const DesktopSettingsState({
    this.status = DesktopSettingsStatus.initial,
    this.settings,
    this.isOnline = false,
    this.userEmail,
    this.isSyncing = false,
    this.lastSyncMessage,
    this.errorMessage,
  });

  final DesktopSettingsStatus status;
  final AppSettingEntity? settings; // ✅ استخدام الكيان النقي
  final bool isOnline;
  final String? userEmail;
  final bool isSyncing;
  final String? lastSyncMessage;
  final String? errorMessage;

  String get userPersona => settings?.userPersona ?? 'digital_minimalist';
  bool get isHighContrast => settings?.isHighContrast ?? false;
  double get speechRate => settings?.speechRate ?? 0.5;
  bool get hapticsEnabled => settings?.hapticsEnabled ?? true;
  bool get soundCuesEnabled => settings?.soundCuesEnabled ?? true;

  String get defaultPriority => settings?.defaultPriority ?? 'medium';
  bool get autoArchiveCompleted => settings?.autoArchiveCompleted ?? true;
  bool get speakDueDatesAloud => settings?.speakDueDatesAloud ?? true;

  bool get voiceChimeHalfway => settings?.voiceChimeHalfway ?? true;
  bool get vibrateOnSessionFinish => settings?.vibrateOnSessionFinish ?? true;
  bool get syncAlarmsWithAndroidClock => settings?.syncAlarmsWithAndroidClock ?? true;

  String get visionInspectionDetail => settings?.visionInspectionDetail ?? 'concise';
  bool get autoFlashlightInDark => settings?.autoFlashlightInDark ?? true;
  String get preferredCurrency => settings?.preferredCurrency ?? 'USD / Local';

  bool get autoDialEmergency => settings?.autoDialEmergency ?? true;
  bool get shareGpsOnSos => settings?.shareGpsOnSos ?? true;

  DesktopSettingsState copyWith({
    DesktopSettingsStatus? status,
    AppSettingEntity? settings,
    bool? isOnline,
    String? userEmail,
    bool? isSyncing,
    String? lastSyncMessage,
    String? errorMessage,
  }) {
    return DesktopSettingsState(
      status: status ?? this.status,
      settings: settings ?? this.settings,
      isOnline: isOnline ?? this.isOnline,
      userEmail: userEmail ?? this.userEmail,
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncMessage: lastSyncMessage ?? this.lastSyncMessage,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        settings,
        isOnline,
        userEmail,
        isSyncing,
        lastSyncMessage,
        errorMessage,
      ];
}