// lib/mobile/onboarding/view/steps/vision_test_step.dart
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/mobile/onboarding/cubit/accessible_onboarding_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class VisionTestStep extends StatelessWidget {
  const VisionTestStep({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AccessibleOnboardingCubit>();

    return BlocBuilder<AccessibleOnboardingCubit, AccessibleOnboardingState>(
      builder: (context, state) {
        final isBusy = state.isCameraBusy;
        final hasResult = state.visionTestResult.isNotEmpty;

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Text(
                'AI VISION ENGINE SIMULATOR',
                style: TextStyle(
                  color: AppTheme.cyanHighlight,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Point camera forward and tap the radar to inspect your surroundings',
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: AppTheme.highContrastMuted, fontSize: 13),
              ),
              const Spacer(),
              GestureDetector(
                onTap: isBusy ? null : cubit.captureAndTestVision,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: isBusy ? 180 : 150,
                  height: isBusy ? 180 : 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.cyanHighlight
                        .withValues(alpha: isBusy ? 0.25 : 0.08),
                    border:
                        Border.all(color: AppTheme.cyanHighlight, width: 2.5),
                  ),
                  child: Center(
                    child: Icon(
                      isBusy
                          ? Icons.hourglass_top_rounded
                          : Icons.camera_rounded,
                      color: AppTheme.cyanHighlight,
                      size: 54,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isBusy
                    ? 'Gemini 2.0 is inspecting scene...'
                    : 'TAP CIRCLE TO SCAN',
                style: const TextStyle(
                  color: AppTheme.yellowHighlight,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
              if (hasResult) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.voidCardSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.cyanHighlight),
                  ),
                  child: Text(
                    state.visionTestResult,
                    style: const TextStyle(
                        color: AppTheme.highContrastText, fontSize: 14),
                  ),
                ),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasResult
                        ? AppTheme.cyanHighlight
                        : AppTheme.voidCardSurface,
                    foregroundColor: hasResult
                        ? AppTheme.pureBlack
                        : AppTheme.highContrastMuted,
                  ),
                  onPressed: cubit.nextStep,
                  child: const Text(
                    'Next: Safety & SOS Setup ➡️',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

typedef BlindVisionStep = VisionTestStep;