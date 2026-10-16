// lib/onboarding/view/steps/minimalist_cockpit_step.dart
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/onboarding/cubit/minimalist_onboarding_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class MinimalistCockpitStep extends StatelessWidget {
  const MinimalistCockpitStep({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MinimalistOnboardingCubit>();

    return BlocBuilder<MinimalistOnboardingCubit, MinimalistOnboardingState>(
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ZERO-FRICTION COCKPIT',
                style: TextStyle(
                  color: AppTheme.terracotta,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Capture ideas at the speed of thought',
                style: TextStyle(
                  color: AppTheme.carbonInk,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Never open an app to write a reminder or check battery again. Tap any sample below to experience instant voice-to-vault execution:',
                style: TextStyle(
                    color: AppTheme.mutedInk, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 24),
              _buildPromptChip(
                cubit: cubit,
                label: 'Remind me to read at 9 PM',
                icon: Icons.alarm_rounded,
                isBusy: state.isTestingVoice,
              ),
              const SizedBox(height: 10),
              _buildPromptChip(
                cubit: cubit,
                label: 'Note: Design concept for project',
                icon: Icons.notes_rounded,
                isBusy: state.isTestingVoice,
              ),
              const SizedBox(height: 10),
              _buildPromptChip(
                cubit: cubit,
                label: 'What is my battery level?',
                icon: Icons.battery_charging_full_rounded,
                isBusy: state.isTestingVoice,
              ),
              if (state.testedVoiceResponse.isNotEmpty) ...[
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.cardSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.terracotta),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: AppTheme.terracotta, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          state.testedVoiceResponse,
                          style: const TextStyle(
                            color: AppTheme.carbonInk,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.terracotta,
                    foregroundColor: AppTheme.cardSurface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: cubit.nextStep,
                  child: const Text(
                    'Next: Make it Permanent ➔',
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

  Widget _buildPromptChip({
    required MinimalistOnboardingCubit cubit,
    required String label,
    required IconData icon,
    required bool isBusy,
  }) {
    return InkWell(
      onTap: isBusy ? null : () => cubit.testSampleCommand(label),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.cardSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.softBorder),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.terracotta, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '"$label"',
                style: const TextStyle(
                  color: AppTheme.carbonInk,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const Icon(Icons.play_circle_outline_rounded,
                color: AppTheme.mutedInk, size: 18),
          ],
        ),
      ),
    );
  }
}