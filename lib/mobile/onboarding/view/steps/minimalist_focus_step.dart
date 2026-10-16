// lib/onboarding/view/steps/minimalist_focus_step.dart
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/onboarding/cubit/minimalist_onboarding_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class MinimalistFocusStep extends StatelessWidget {
  const MinimalistFocusStep({super.key});

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
                'DEEP WORK RHYTHM',
                style: TextStyle(
                  color: AppTheme.terracotta,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tune your default study and focus interval',
                style: TextStyle(
                  color: AppTheme.carbonInk,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'PREFERRED FOCUS CYCLE',
                style: TextStyle(
                  color: AppTheme.mutedInk,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [15, 25, 45, 60].map((mins) {
                  final isSelected =
                      state.selectedFocusDurationMinutes == mins;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: InkWell(
                        onTap: () => cubit.selectFocusDuration(mins),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.terracotta
                                : AppTheme.cardSurface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.terracotta
                                  : AppTheme.softBorder,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '${mins}m',
                                style: TextStyle(
                                  color: isSelected
                                      ? AppTheme.cardSurface
                                      : AppTheme.carbonInk,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                mins == 25 ? 'Pomodoro' : 'Focus',
                                style: TextStyle(
                                  color: isSelected
                                      ? AppTheme.cardSurface
                                          .withValues(alpha: 0.8)
                                      : AppTheme.mutedInk,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 28),
              Material(
                color: AppTheme.cardSurface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppTheme.softBorder),
                ),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Auto-Archive Completed Priorities',
                      style: TextStyle(
                        color: AppTheme.carbonInk,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: const Text(
                      'Clear completed tasks instantly to maintain visual zen.',
                      style: TextStyle(color: AppTheme.mutedInk, fontSize: 12),
                    ),
                    activeColor: AppTheme.terracotta,
                    value: state.autoArchiveCompletedTasks,
                    onChanged: cubit.toggleAutoArchive,
                  ),
                ),
              ),
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
                    'Confirm Rhythm ➔',
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