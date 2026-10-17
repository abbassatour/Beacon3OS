// lib/mobile/onboarding/cubit/accessible_onboarding_cubit.dart
import 'dart:developer';
import 'package:beacon_os/core/audio/sound_controller.dart';
import 'package:beacon_os/core/audio/sound_cue.dart';
import 'package:beacon_os/core/haptics/haptic_manager.dart';
import 'package:beacon_os/core/services/camera_service.dart';
import 'package:beacon_os/mobile/shell/models/spatial_gestures.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:launcher_repository/launcher_repository.dart';

enum AccessibleStep { audioTuning, compassTraining, visionTest, sosSetup }

enum AccessibleFlowStatus {
  initial,
  active,
  testingVision,
  completing,
  completed,
  error,
}

class AccessibleOnboardingState extends Equatable {
  const AccessibleOnboardingState({
    this.status = AccessibleFlowStatus.initial,
    this.currentStep = AccessibleStep.audioTuning,
    this.speechRate = 0.65,
    this.hasMasteredNorthSwipe = false,
    this.hasMasteredSouthSwipe = false,
    this.hasMasteredPinch = false,
    this.visionTestResult = '',
    this.isCameraBusy = false,
    this.errorMessage,
  });

  final AccessibleFlowStatus status;
  final AccessibleStep currentStep;
  final double speechRate;
  final bool hasMasteredNorthSwipe;
  final bool hasMasteredSouthSwipe;
  final bool hasMasteredPinch;
  final String visionTestResult;
  final bool isCameraBusy;
  final String? errorMessage;

  bool get isCompassTrainingDone =>
      hasMasteredNorthSwipe && hasMasteredSouthSwipe;

  AccessibleOnboardingState copyWith({
    AccessibleFlowStatus? status,
    AccessibleStep? currentStep,
    double? speechRate,
    bool? hasMasteredNorthSwipe,
    bool? hasMasteredSouthSwipe,
    bool? hasMasteredPinch,
    String? visionTestResult,
    bool? isCameraBusy,
    String? errorMessage,
  }) {
    return AccessibleOnboardingState(
      status: status ?? this.status,
      currentStep: currentStep ?? this.currentStep,
      speechRate: speechRate ?? this.speechRate,
      hasMasteredNorthSwipe:
          hasMasteredNorthSwipe ?? this.hasMasteredNorthSwipe,
      hasMasteredSouthSwipe:
          hasMasteredSouthSwipe ?? this.hasMasteredSouthSwipe,
      hasMasteredPinch: hasMasteredPinch ?? this.hasMasteredPinch,
      visionTestResult: visionTestResult ?? this.visionTestResult,
      isCameraBusy: isCameraBusy ?? this.isCameraBusy,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        currentStep,
        speechRate,
        hasMasteredNorthSwipe,
        hasMasteredSouthSwipe,
        hasMasteredPinch,
        visionTestResult,
        isCameraBusy,
        errorMessage,
      ];
}

class AccessibleOnboardingCubit extends Cubit<AccessibleOnboardingState> {
  AccessibleOnboardingCubit({
    required AssistantRepository assistantRepository,
    required SettingsRepository settingsRepository,
    CameraService? cameraService,
    HapticManager? hapticManager,
    SoundController? soundController,
  })  : _assistant = assistantRepository,
        _settings = settingsRepository,
        _camera = cameraService ?? CameraService.instance,
        _haptics = hapticManager ?? HapticManager.instance,
        _sound = soundController ?? SoundController.instance,
        super(const AccessibleOnboardingState()) {
    announceCurrentStep(AccessibleStep.audioTuning);
  }

  final AssistantRepository _assistant;
  final SettingsRepository _settings;
  final CameraService _camera;
  final HapticManager _haptics;
  final SoundController _sound;

  Future<void> increaseSpeechRate() async {
    final nextRate = (state.speechRate + 0.05).clamp(0.4, 1.0);
    emit(state.copyWith(speechRate: nextRate));
    await _haptics.successNotification();
    await _assistant.setSpeechRate(nextRate);
    final speedMultiplier = (nextRate * 2).toStringAsFixed(1);
    await _assistant.speak('Speech speed: $speedMultiplier times.');
  }

  Future<void> decreaseSpeechRate() async {
    final nextRate = (state.speechRate - 0.05).clamp(0.4, 1.0);
    emit(state.copyWith(speechRate: nextRate));
    await _haptics.successNotification();
    await _assistant.setSpeechRate(nextRate);
    final speedMultiplier = (nextRate * 2).toStringAsFixed(1);
    await _assistant.speak('Speech speed: $speedMultiplier times.');
  }

  Future<void> handleTrainingSwipeUp() async {
    await _sound.play(SoundCue.navNorth);
    await _haptics.successNotification();
    emit(state.copyWith(hasMasteredNorthSwipe: true));
    await _assistant.speak(
      'Excellent. That is the North Focus & Alarms chime. Now, swipe down to discover Communications.',
    );
  }

  Future<void> handleTrainingSwipeDown() async {
    await _sound.play(SoundCue.navSouth);
    await _haptics.successNotification();
    emit(state.copyWith(hasMasteredSouthSwipe: true));
    await _assistant.speak(
      'Great job! That is the South Communications chime. '
      'Now spread your fingers apart to test the elevator, or tap continue to proceed.',
    );
  }

  Future<void> handleTrainingPinch() async {
    if (state.hasMasteredPinch) return;
    await _sound.play(SoundCue.elevatorUp);
    await _haptics.successNotification();
    emit(state.copyWith(hasMasteredPinch: true));
    await _assistant.speak(SpatialGesture.ascendToSettings.spokenPrompt);
  }

  Future<void> captureAndTestVision() async {
    if (state.isCameraBusy) return;

    try {
      emit(
        state.copyWith(
          isCameraBusy: true,
          status: AccessibleFlowStatus.testingVision,
        ),
      );

      final permState = await _camera.getPermissionState();
      if (permState == CameraPermissionState.permanentlyDenied) {
        emit(
          state.copyWith(
            isCameraBusy: false,
            status: AccessibleFlowStatus.active,
          ),
        );
        await _sound.play(SoundCue.error);
        await _haptics.errorAlert();
        await _assistant.speak(
          'Camera permission is permanently denied. Please enable camera in device settings.',
        );
        return;
      }

      if (permState == CameraPermissionState.denied) {
        await _assistant.speak('Please allow camera access on your screen.');
      } else {
        await _sound.play(SoundCue.processing);
        await _haptics.successNotification();
        await _assistant.speak('Inspecting scene with Gemini...');
      }

      final base64 = await _camera.captureAsBase64();
      if (base64 == null || base64.isEmpty) {
        emit(
          state.copyWith(
            isCameraBusy: false,
            status: AccessibleFlowStatus.active,
          ),
        );
        await _sound.play(SoundCue.error);
        await _haptics.errorAlert();
        await _assistant.speak(
          'Camera capture failed or permission was denied. Tap again to retry.',
        );
        return;
      }

      final result = await _assistant.analyzeVisionFrame(
        base64Image: base64,
        prompt:
            'You are the eyes for a blind user. In 1 short sentence, describe what is directly in front of this phone camera.',
      );

      emit(
        state.copyWith(
          isCameraBusy: false,
          visionTestResult: result,
          status: AccessibleFlowStatus.active,
        ),
      );

      await _sound.play(SoundCue.success);
      await _assistant.speak(result);

      await Future<void>.delayed(const Duration(seconds: 2));
      await _assistant.speak(
        'AI vision is verified. Double tap anywhere to move to the final Safety step.',
      );
    } catch (e, st) {
      log('AccessibleOnboarding: Vision error: $e', stackTrace: st);
      emit(
        state.copyWith(
          isCameraBusy: false,
          status: AccessibleFlowStatus.active,
        ),
      );
      await _sound.play(SoundCue.error);
      await _assistant.speak(
        'Could not complete visual inspection. Tap again to retry.',
      );
    }
  }

  void nextStep() {
    switch (state.currentStep) {
      case AccessibleStep.audioTuning:
        goToStep(AccessibleStep.compassTraining);
        break;
      case AccessibleStep.compassTraining:
        goToStep(AccessibleStep.visionTest);
        break;
      case AccessibleStep.visionTest:
        goToStep(AccessibleStep.sosSetup);
        break;
      case AccessibleStep.sosSetup:
        finishAccessibleOnboarding();
        break;
    }
  }

  void goToStep(AccessibleStep step) {
    emit(state.copyWith(currentStep: step));
    announceCurrentStep(step);
  }

  Future<void> announceCurrentStep(AccessibleStep step) async {
    await _sound.stopAll();
    await _assistant.stopSpeaking();

    switch (step) {
      case AccessibleStep.audioTuning:
        await _assistant.speak(
          'Step 1: Audio Tuning. Tap the top half of the screen to increase reading speed. '
          'Tap the bottom half to decrease. Double tap anywhere with two fingers to confirm.',
        );
        break;
      case AccessibleStep.compassTraining:
        await _assistant.speak(
          'Step 2: Spatial Navigation Training. '
          'Swipe up now to hear the North Focus chime.',
        );
        break;
      case AccessibleStep.visionTest:
        await _assistant.speak(
          'Step 3: AI Digital Eyes. Point your phone in front of you and tap anywhere on the screen to perform a test scan.',
        );
        break;
      case AccessibleStep.sosSetup:
        await _assistant.speak(
          'Final Step: Emergency SOS. Remember: three rapid taps anywhere on screen will trigger your loud emergency radar. '
          'Double tap now with two fingers to enter your spatial cockpit.',
        );
        break;
    }
  }

  Future<void> finishAccessibleOnboarding() async {
    emit(state.copyWith(status: AccessibleFlowStatus.completing));
    try {
      // 🌟 ميزة الهمس الصوتي مفعلة تلقائياً للمكفوفين لتوجيههم عبر البوصلة
      await _settings.completeOnboarding(
        persona: 'blind_accessible',
        isHighContrast: true,
        speechRate: state.speechRate,
        spatialWhisperEnabled: true,
      );

      await _sound.play(SoundCue.success);
      await _haptics.emergencyAlarmPulse();
      await _assistant.speak(
        'Beacon OS is fully configured. Welcome home to your Cockpit.',
      );

      emit(state.copyWith(status: AccessibleFlowStatus.completed));
    } catch (e) {
      emit(
        state.copyWith(
          status: AccessibleFlowStatus.error,
          errorMessage: 'Failed to complete setup: $e',
        ),
      );
    }
  }
}