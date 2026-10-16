// lib/mobile/onboarding/view/steps/sos_setup_step.dart
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/mobile/onboarding/cubit/accessible_onboarding_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SosSetupStep extends StatelessWidget {
  const SosSetupStep({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AccessibleOnboardingCubit>();

    return BlocBuilder<AccessibleOnboardingCubit, AccessibleOnboardingState>(
      builder: (context, state) {
        final isCompleting = state.status == AccessibleFlowStatus.completing;

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'RADAR & EMERGENCY SAFETY',
                style: TextStyle(
                  color: AppTheme.yellowHighlight,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.voidCardSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.errorRed, width: 2),
                ),
                child: Column(
                  children: const [
                    Icon(Icons.warning_amber_rounded,
                        color: AppTheme.errorRed, size: 56),
                    SizedBox(height: 16),
                    Text(
                      'TRIPLE TAP EMERGENCY GESTURE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.highContrastText,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Anywhere in the system, tapping rapidly 3 times triggers your loud alarm and sends your live GPS coordinates to your primary contact.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.highContrastMuted,
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.cyanHighlight,
                    foregroundColor: AppTheme.pureBlack,
                  ),
                  icon: isCompleting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const Icon(Icons.rocket_launch_rounded, size: 24),
                  label: Text(
                    isCompleting
                        ? 'Finalizing Setup...'
                        : 'Enter Spatial Cockpit',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 17),
                  ),
                  onPressed:
                      isCompleting ? null : cubit.finishAccessibleOnboarding,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

typedef BlindSosStep = SosSetupStep;