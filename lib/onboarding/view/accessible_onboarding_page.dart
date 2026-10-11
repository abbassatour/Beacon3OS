// lib/onboarding/view/accessible_onboarding_page.dart
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/onboarding/cubit/accessible_onboarding_cubit.dart';
import 'package:beacon_os/onboarding/view/steps/audio_tuning_step.dart';
import 'package:beacon_os/onboarding/view/steps/compass_training_step.dart';
import 'package:beacon_os/onboarding/view/steps/sos_setup_step.dart';
import 'package:beacon_os/onboarding/view/steps/vision_test_step.dart';
import 'package:beacon_os/spatial_shell/spatial_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';

class AccessibleOnboardingPage extends StatelessWidget {
  const AccessibleOnboardingPage({super.key});

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const AccessibleOnboardingPage());

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AccessibleOnboardingCubit(
        assistantRepository: context.read<AssistantRepository>(),
        settingsRepository: context.read<SettingsRepository>(),
      ),
      child: const _AccessibleOnboardingScaffold(),
    );
  }
}

class _AccessibleOnboardingScaffold extends StatelessWidget {
  const _AccessibleOnboardingScaffold();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AccessibleOnboardingCubit, AccessibleOnboardingState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == AccessibleFlowStatus.completed) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => const SpatialShellPage(),
            ),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: AppTheme.pureBlack,
          body: SafeArea(
            child: Column(
              children: [
                _buildHeaderBar(context, state),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: _buildCurrentStep(state.currentStep),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderBar(BuildContext context, AccessibleOnboardingState state) {
    final stepIndex = state.currentStep.index + 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.highContrastBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'ACCESSIBILITY SETUP • STEP $stepIndex OF 4',
                style: const TextStyle(
                  color: AppTheme.cyanHighlight,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => context
                .read<AccessibleOnboardingCubit>()
                .finishAccessibleOnboarding(),
            child: const Text(
              'Skip to Cockpit',
              style: TextStyle(
                color: AppTheme.highContrastMuted,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep(AccessibleStep step) {
    switch (step) {
      case AccessibleStep.audioTuning:
        return const AudioTuningStep(key: ValueKey('audio_step'));
      case AccessibleStep.compassTraining:
        return const CompassTrainingStep(key: ValueKey('compass_step'));
      case AccessibleStep.visionTest:
        return const VisionTestStep(key: ValueKey('vision_step'));
      case AccessibleStep.sosSetup:
        return const SosSetupStep(key: ValueKey('sos_step'));
    }
  }
}

// 🛡️ اسم توافقي
typedef BlindOnboardingPage = AccessibleOnboardingPage;