// lib/mobile/onboarding/cubit/minimalist_onboarding_cubit.dart
import 'package:beacon_os/core/audio/sound_controller.dart';
import 'package:beacon_os/core/audio/sound_cue.dart';
import 'package:beacon_os/core/haptics/haptic_manager.dart';
import 'package:beacon_os/core/voice_bus/voice_bus.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:launcher_repository/launcher_repository.dart';

enum MinimalistStep { manifesto, focusTuning, voiceCockpit, launcherSetup }

enum MinimalistStatus {
  initial,
  active,
  testingCommand,
  completing,
  completed,
  error,
}

class MinimalistOnboardingState extends Equatable {
  const MinimalistOnboardingState({
    this.status = MinimalistStatus.initial,
    this.currentStep = MinimalistStep.manifesto,
    this.selectedFocusDurationMinutes = 25,
    this.autoArchiveCompletedTasks = true,
    this.testedVoiceResponse = '',
    this.isTestingVoice = false,
    this.errorMessage,
  });

  final MinimalistStatus status;
  final MinimalistStep currentStep;
  final int selectedFocusDurationMinutes;
  final bool autoArchiveCompletedTasks;
  final String testedVoiceResponse;
  final bool isTestingVoice;
  final String? errorMessage;

  MinimalistOnboardingState copyWith({
    MinimalistStatus? status,
    MinimalistStep? currentStep,
    int? selectedFocusDurationMinutes,
    bool? autoArchiveCompletedTasks,
    String? testedVoiceResponse,
    bool? isTestingVoice,
    String? errorMessage,
  }) {
    return MinimalistOnboardingState(
      status: status ?? this.status,
      currentStep: currentStep ?? this.currentStep,
      selectedFocusDurationMinutes:
          selectedFocusDurationMinutes ?? this.selectedFocusDurationMinutes,
      autoArchiveCompletedTasks:
          autoArchiveCompletedTasks ?? this.autoArchiveCompletedTasks,
      testedVoiceResponse: testedVoiceResponse ?? this.testedVoiceResponse,
      isTestingVoice: isTestingVoice ?? this.isTestingVoice,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        currentStep,
        selectedFocusDurationMinutes,
        autoArchiveCompletedTasks,
        testedVoiceResponse,
        isTestingVoice,
        errorMessage,
      ];
}

class MinimalistOnboardingCubit extends Cubit<MinimalistOnboardingState> {
  MinimalistOnboardingCubit({
    required SettingsRepository settingsRepository,
    required VoiceCommandDispatcher voiceDispatcher,
    HapticManager? hapticManager,
    SoundController? soundController,
  })  : _settings = settingsRepository,
        _voiceDispatcher = voiceDispatcher,
        _haptics = hapticManager ?? HapticManager.instance,
        _sound = soundController ?? SoundController.instance,
        super(const MinimalistOnboardingState());

  final SettingsRepository _settings;
  final VoiceCommandDispatcher _voiceDispatcher;
  final HapticManager _haptics;
  final SoundController _sound;

  void selectFocusDuration(int minutes) {
    emit(state.copyWith(selectedFocusDurationMinutes: minutes));
    _haptics.successNotification();
    _sound.play(SoundCue.navCenter);
  }

  void toggleAutoArchive(bool enabled) {
    emit(state.copyWith(autoArchiveCompletedTasks: enabled));
    _haptics.successNotification();
  }

  Future<void> testSampleCommand(String command) async {
    emit(state.copyWith(isTestingVoice: true));
    await _sound.play(SoundCue.processing);

    final result = await _voiceDispatcher.dispatch(command);

    await _sound.play(SoundCue.success);
    await _haptics.successNotification();

    emit(
      state.copyWith(
        isTestingVoice: false,
        testedVoiceResponse: result.spokenResponse,
      ),
    );
  }

  void goToStep(MinimalistStep step) {
    emit(state.copyWith(currentStep: step));
    _sound.play(SoundCue.navCenter);
  }

  void nextStep() {
    switch (state.currentStep) {
      case MinimalistStep.manifesto:
        goToStep(MinimalistStep.focusTuning);
        break;
      case MinimalistStep.focusTuning:
        goToStep(MinimalistStep.voiceCockpit);
        break;
      case MinimalistStep.voiceCockpit:
        goToStep(MinimalistStep.launcherSetup);
        break;
      case MinimalistStep.launcherSetup:
        finishMinimalistOnboarding();
        break;
    }
  }

  void previousStep() {
    switch (state.currentStep) {
      case MinimalistStep.manifesto:
        break;
      case MinimalistStep.focusTuning:
        goToStep(MinimalistStep.manifesto);
        break;
      case MinimalistStep.voiceCockpit:
        goToStep(MinimalistStep.focusTuning);
        break;
      case MinimalistStep.launcherSetup:
        goToStep(MinimalistStep.voiceCockpit);
        break;
    }
  }

  Future<void> finishMinimalistOnboarding() async {
    emit(state.copyWith(status: MinimalistStatus.completing));
    try {
      // 🌟 ميزة الهمس مطفأة تلقائياً للمستخدم المينيماليست لمنع ثقل السحب
      await _settings.completeOnboarding(
        persona: 'digital_minimalist',
        isHighContrast: false,
        speechRate: 0.5,
        spatialWhisperEnabled: false,
      );

      await _sound.play(SoundCue.success);
      await _haptics.successNotification();

      emit(state.copyWith(status: MinimalistStatus.completed));
    } catch (e) {
      emit(
        state.copyWith(
          status: MinimalistStatus.error,
          errorMessage: 'Failed to complete setup: $e',
        ),
      );
    }
  }
}