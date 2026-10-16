// lib/onboarding/view/steps/minimalist_launcher_step.dart
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/onboarding/cubit/minimalist_onboarding_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class MinimalistLauncherStep extends StatelessWidget {
  const MinimalistLauncherStep({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MinimalistOnboardingCubit>();

    return BlocBuilder<MinimalistOnboardingCubit, MinimalistOnboardingState>(
      builder: (context, state) {
        final isCompleting = state.status == MinimalistStatus.completing;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'YOUR DEFAULT COCKPIT',
                style: TextStyle(
                  color: AppTheme.terracotta,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Replace infinite feeds with intentional focus',
                style: TextStyle(
                  color: AppTheme.carbonInk,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: AppTheme.cardSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.softBorder),
                ),
                child: Column(
                  children: const [
                    Icon(Icons.home_max_rounded,
                        color: AppTheme.terracotta, size: 54),
                    SizedBox(height: 16),
                    Text(
                      'Default Home Launcher',
                      style: TextStyle(
                        color: AppTheme.carbonInk,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'To lock in your focus, set BeaconOS as your Android Home app in System Settings. Whenever you press Home, your calm cockpit will be waiting.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.mutedInk,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.terracotta,
                    foregroundColor: AppTheme.cardSurface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: isCompleting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.rocket_launch_rounded, size: 22),
                  label: Text(
                    isCompleting
                        ? 'Finalizing Setup...'
                        : 'Enter Calm Cockpit 🚀',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  onPressed:
                      isCompleting ? null : cubit.finishMinimalistOnboarding,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}