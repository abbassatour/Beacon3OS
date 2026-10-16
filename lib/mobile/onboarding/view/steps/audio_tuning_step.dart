// lib/mobile/onboarding/view/steps/audio_tuning_step.dart
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/mobile/onboarding/cubit/accessible_onboarding_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AudioTuningStep extends StatelessWidget {
  const AudioTuningStep({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AccessibleOnboardingCubit>();

    return BlocBuilder<AccessibleOnboardingCubit, AccessibleOnboardingState>(
      builder: (context, state) {
        final speedMultiplier = (state.speechRate * 2).toStringAsFixed(1);

        return Column(
          children: [
            Expanded(
              child: Semantics(
                label: 'Increase speech speed. Tap to speed up reading voice.',
                button: true,
                child: InkWell(
                  onTap: cubit.increaseSpeechRate,
                  child: Container(
                    width: double.infinity,
                    color: AppTheme.voidCardSurface,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.arrow_upward_rounded,
                            size: 54, color: AppTheme.cyanHighlight),
                        SizedBox(height: 8),
                        Text(
                          'FASTER (+)',
                          style: TextStyle(
                            color: AppTheme.highContrastText,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                        Text(
                          'Tap anywhere on top',
                          style: TextStyle(
                              color: AppTheme.highContrastMuted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              color: AppTheme.pureBlack,
              child: Center(
                child: Text(
                  'Current Speed: ${speedMultiplier}x',
                  style: const TextStyle(
                    color: AppTheme.yellowHighlight,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Semantics(
                label: 'Decrease speech speed. Tap to slow down reading voice.',
                button: true,
                child: InkWell(
                  onTap: cubit.decreaseSpeechRate,
                  child: Container(
                    width: double.infinity,
                    color: AppTheme.voidCardSurface,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.arrow_downward_rounded,
                            size: 54, color: AppTheme.cyanHighlight),
                        SizedBox(height: 8),
                        Text(
                          'SLOWER (-)',
                          style: TextStyle(
                            color: AppTheme.highContrastText,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                        Text(
                          'Tap anywhere on bottom',
                          style: TextStyle(
                              color: AppTheme.highContrastMuted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.cyanHighlight,
                    foregroundColor: AppTheme.pureBlack,
                  ),
                  icon: const Icon(Icons.check_rounded, size: 28),
                  label: const Text(
                    'Confirm Speed & Continue',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  onPressed: cubit.nextStep,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

typedef BlindAudioStep = AudioTuningStep;