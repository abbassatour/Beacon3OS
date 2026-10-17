// lib/mobile/preferences/cubit/preferences_cubit.dart
import 'dart:async';
import 'package:beacon_os/core/audio/sound_controller.dart';
import 'package:beacon_os/core/haptics/haptic_manager.dart';
import 'package:beacon_os/mobile/preferences/cubit/preferences_state.dart';
import 'package:bloc/bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';

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
  StreamSubscription<AppSettingEntity>? _settingsSubscription;

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

  Future<void> setSpeechRate(double rate) async {
    await _assistantRepo.setSpeechRate(rate);
    await _settingsRepo.updateSettings(
      AppSettingUpdatePayload(speechRate: rate),
    );
  }

  Future<void> toggleHaptics(bool enabled) async {
    HapticManager.instance.isEnabled = enabled;
    await _settingsRepo.updateSettings(
      AppSettingUpdatePayload(hapticsEnabled: enabled),
    );
  }

  Future<void> toggleSoundCues(bool enabled) async {
    SoundController.instance.isEnabled = enabled;
    await _settingsRepo.updateSettings(
      AppSettingUpdatePayload(soundCuesEnabled: enabled),
    );
  }

  Future<void> toggleHighContrast(bool enabled) async {
    await _settingsRepo.updateSettings(
      AppSettingUpdatePayload(isHighContrast: enabled),
    );
    await _assistantRepo.speak(
      enabled ? 'High contrast display enabled.' : 'Standard display restored.',
    );
  }

  Future<void> setDefaultPriority(String priority) async {
    await _settingsRepo.updateSettings(
      AppSettingUpdatePayload(defaultPriority: priority),
    );
    await _assistantRepo.speak('Default priority set to $priority.');
  }

  Future<void> toggleAutoArchive(bool enabled) async {
    await _settingsRepo.updateSettings(
      AppSettingUpdatePayload(autoArchiveCompleted: enabled),
    );
  }

  Future<void> toggleSpeakDueDates(bool enabled) async {
    await _settingsRepo.updateSettings(
      AppSettingUpdatePayload(speakDueDatesAloud: enabled),
    );
  }

  Future<void> toggleAutoDialEmergency(bool enabled) async {
    await _settingsRepo.updateSettings(
      AppSettingUpdatePayload(autoDialEmergency: enabled),
    );
  }

  Future<void> toggleShareGpsOnSos(bool enabled) async {
    await _settingsRepo.updateSettings(
      AppSettingUpdatePayload(shareGpsOnSos: enabled),
    );
  }

  Future<void> toggleSpeakIncomingSms(bool enabled) async {
    await _settingsRepo.updateSettings(
      AppSettingUpdatePayload(speakIncomingSms: enabled),
    );
  }

  Future<void> toggleVoiceChimeHalfway(bool enabled) async {
    await _settingsRepo.updateSettings(
      AppSettingUpdatePayload(voiceChimeHalfway: enabled),
    );
  }

  Future<void> toggleVibrateOnFinish(bool enabled) async {
    await _settingsRepo.updateSettings(
      AppSettingUpdatePayload(vibrateOnSessionFinish: enabled),
    );
  }

  Future<void> toggleSyncAlarmsWithAndroid(bool enabled) async {
    await _settingsRepo.updateSettings(
      AppSettingUpdatePayload(syncAlarmsWithAndroidClock: enabled),
    );
  }

  Future<void> setVisionInspectionDetail(String detail) async {
    await _settingsRepo.updateSettings(
      AppSettingUpdatePayload(visionInspectionDetail: detail),
    );
    await _assistantRepo.speak('Vision verbosity set to $detail.');
  }

  Future<void> toggleAutoFlashlight(bool enabled) async {
    await _settingsRepo.updateSettings(
      AppSettingUpdatePayload(autoFlashlightInDark: enabled),
    );
  }

  Future<void> setPreferredCurrency(String currency) async {
    await _settingsRepo.updateSettings(
      AppSettingUpdatePayload(preferredCurrency: currency),
    );
  }

  @override
  Future<void> close() {
    _settingsSubscription?.cancel();
    return super.close();
  }
}