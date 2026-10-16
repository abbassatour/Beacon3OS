// lib/preferences/cubit/preferences_cubit.dart
import 'dart:async';
import 'package:beacon_os/core/audio/sound_controller.dart';
import 'package:beacon_os/core/haptics/haptic_manager.dart';
import 'package:beacon_os/preferences/cubit/preferences_state.dart';
import 'package:bloc/bloc.dart';
import 'package:drift/drift.dart';
import 'package:launcher_repository/launcher_repository.dart';
import 'package:local_vault_api/local_vault_api.dart';

class PreferencesCubit extends Cubit<PreferencesState> {
  PreferencesCubit({
    required SettingsRepository settingsRepository,
    required AssistantRepository assistantRepository,
  })  : _settingsRepo = settingsRepository,
        _assistantRepo = assistantRepository,
        super(const PreferencesState()) {
    _initSettingsStream();
  }

  final SettingsRepository _settingsRepo;
  final AssistantRepository _assistantRepo;
  StreamSubscription<AppSetting>? _settingsSubscription;

  void _initSettingsStream() {
    emit(state.copyWith(status: PreferencesStatus.loading));

    _settingsSubscription = _settingsRepo.watchSettings().listen(
      (appSettings) {
        SoundController.instance.isEnabled = appSettings.soundCuesEnabled;
        HapticManager.instance.isEnabled = appSettings.hapticsEnabled;
        unawaited(_assistantRepo.setSpeechRate(appSettings.speechRate));

        emit(
          state.copyWith(
            status: PreferencesStatus.success,
            settings: appSettings,
          ),
        );
      },
      onError: (Object error) {
        emit(
          state.copyWith(
            status: PreferencesStatus.error,
            errorMessage: 'Failed to load system preferences: $error',
          ),
        );
      },
    );
  }

  // ===========================================================================
  // 🎛️ 1. إعدادات الغرفة المركزية (Cockpit - Floor 1)
  // ===========================================================================

  Future<void> setSpeechRate(double rate) async {
    await _assistantRepo.setSpeechRate(rate);
    await _settingsRepo.updateSettings(
      AppSettingsCompanion(speechRate: Value(rate)),
    );
  }

  Future<void> toggleHaptics(bool enabled) async {
    HapticManager.instance.isEnabled = enabled;
    await _settingsRepo.updateSettings(
      AppSettingsCompanion(hapticsEnabled: Value(enabled)),
    );
  }

  Future<void> toggleSoundCues(bool enabled) async {
    SoundController.instance.isEnabled = enabled;
    await _settingsRepo.updateSettings(
      AppSettingsCompanion(soundCuesEnabled: Value(enabled)),
    );
  }

  Future<void> toggleHighContrast(bool enabled) async {
    await _settingsRepo.updateSettings(
      AppSettingsCompanion(isHighContrast: Value(enabled)),
    );
    await _assistantRepo.speak(
      enabled ? 'High contrast display enabled.' : 'Standard display restored.',
    );
  }

  // ===========================================================================
  // 📅 2. إعدادات الأجندة والمهام (Agenda - Floor 1)
  // ===========================================================================

  Future<void> setDefaultPriority(String priority) async {
    await _settingsRepo.updateSettings(
      AppSettingsCompanion(defaultPriority: Value(priority)),
    );
    await _assistantRepo.speak('Default priority set to $priority.');
  }

  Future<void> toggleAutoArchive(bool enabled) async {
    await _settingsRepo.updateSettings(
      AppSettingsCompanion(autoArchiveCompleted: Value(enabled)),
    );
  }

  Future<void> toggleSpeakDueDates(bool enabled) async {
    await _settingsRepo.updateSettings(
      AppSettingsCompanion(speakDueDatesAloud: Value(enabled)),
    );
  }

  // ===========================================================================
  // 🛡️ 3. إعدادات الطوارئ والتواصل (Comms - Floor 1)
  // ===========================================================================

  Future<void> toggleAutoDialEmergency(bool enabled) async {
    await _settingsRepo.updateSettings(
      AppSettingsCompanion(autoDialEmergency: Value(enabled)),
    );
  }

  Future<void> toggleShareGpsOnSos(bool enabled) async {
    await _settingsRepo.updateSettings(
      AppSettingsCompanion(shareGpsOnSos: Value(enabled)),
    );
  }

  Future<void> toggleSpeakIncomingSms(bool enabled) async {
    await _settingsRepo.updateSettings(
      AppSettingsCompanion(speakIncomingSms: Value(enabled)),
    );
  }

  // ===========================================================================
  // ⏳ 4. إعدادات جلسات التركيز والمنبهات (Focus - Floor 1)
  // ===========================================================================

  Future<void> toggleVoiceChimeHalfway(bool enabled) async {
    await _settingsRepo.updateSettings(
      AppSettingsCompanion(voiceChimeHalfway: Value(enabled)),
    );
  }

  Future<void> toggleVibrateOnFinish(bool enabled) async {
    await _settingsRepo.updateSettings(
      AppSettingsCompanion(vibrateOnSessionFinish: Value(enabled)),
    );
  }

  Future<void> toggleSyncAlarmsWithAndroid(bool enabled) async {
    await _settingsRepo.updateSettings(
      AppSettingsCompanion(syncAlarmsWithAndroidClock: Value(enabled)),
    );
  }

  // ===========================================================================
  // 👁️ 5. إعدادات الرؤية والذكاء الاصطناعي (Vision - Floor 1)
  // ===========================================================================

  Future<void> setVisionInspectionDetail(String detail) async {
    await _settingsRepo.updateSettings(
      AppSettingsCompanion(visionInspectionDetail: Value(detail)),
    );
    await _assistantRepo.speak('Vision verbosity set to $detail.');
  }

  Future<void> toggleAutoFlashlight(bool enabled) async {
    await _settingsRepo.updateSettings(
      AppSettingsCompanion(autoFlashlightInDark: Value(enabled)),
    );
  }

  Future<void> setPreferredCurrency(String currency) async {
    await _settingsRepo.updateSettings(
      AppSettingsCompanion(preferredCurrency: Value(currency)),
    );
  }

  @override
  Future<void> close() {
    _settingsSubscription?.cancel();
    return super.close();
  }
}

// 🛡️ اسم توافقي لمنع انكسار أي كود قديم
typedef SettingsCubit = PreferencesCubit;