// lib/onboarding/view/minimalist_onboarding_page.dart
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/core/voice_bus/voice_bus.dart'; // 👈 تم التصحيح
import 'package:beacon_os/onboarding/cubit/minimalist_onboarding_cubit.dart';
import 'package:beacon_os/onboarding/view/steps/minimalist_cockpit_step.dart';
import 'package:beacon_os/onboarding/view/steps/minimalist_focus_step.dart';
import 'package:beacon_os/onboarding/view/steps/minimalist_launcher_step.dart';
import 'package:beacon_os/onboarding/view/steps/minimalist_manifesto_step.dart';
import 'package:beacon_os/spatial_shell/spatial_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';

class MinimalistOnboardingPage extends StatelessWidget {
  const MinimalistOnboardingPage({super.key});

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const MinimalistOnboardingPage());

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => MinimalistOnboardingCubit(
        settingsRepository: context.read<SettingsRepository>(),
        voiceDispatcher: context.read<VoiceCommandDispatcher>(),
      ),
      child: const _MinimalistScaffold(),
    );
  }
}

class _MinimalistScaffold extends StatelessWidget {
  const _MinimalistScaffold();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<MinimalistOnboardingCubit, MinimalistOnboardingState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == MinimalistStatus.completed) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => const SpatialShellPage(),
            ),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: AppTheme.warmPaper,
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(context, state),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: _buildStep(state.currentStep),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, MinimalistOnboardingState state) {
    final cubit = context.read<MinimalistOnboardingCubit>();
    final stepNum = state.currentStep.index + 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'BEACON OS • INTENTIONALITY $stepNum/4',
                style: const TextStyle(
                  color: AppTheme.terracotta,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
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
            onPressed: cubit.finishMinimalistOnboarding,
            child: const Text(
              'Skip to Cockpit',
              style: TextStyle(
                color: AppTheme.mutedInk,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(MinimalistStep step) {
    switch (step) {
      case MinimalistStep.manifesto:
        return const MinimalistManifestoStep(key: ValueKey('manifesto'));
      case MinimalistStep.focusTuning:
        return const MinimalistFocusStep(key: ValueKey('focus'));
      case MinimalistStep.voiceCockpit:
        return const MinimalistCockpitStep(key: ValueKey('cockpit'));
      case MinimalistStep.launcherSetup:
        return const MinimalistLauncherStep(key: ValueKey('launcher'));
    }
  }
}