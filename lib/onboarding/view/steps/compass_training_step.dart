// lib/onboarding/view/steps/compass_training_step.dart
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/onboarding/cubit/accessible_onboarding_cubit.dart';
import 'package:beacon_os/spatial_shell/models/spatial_gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CompassTrainingStep extends StatelessWidget {
  const CompassTrainingStep({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AccessibleOnboardingCubit>();

    return BlocBuilder<AccessibleOnboardingCubit, AccessibleOnboardingState>(
      builder: (context, state) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleUpdate: (details) {
            if (details.pointerCount >= 2 && details.scale > 1.15) {
              cubit.handleTrainingPinch();
            }
          },
          onScaleEnd: (details) {
            if (details.pointerCount >= 2) {
              cubit.handleTrainingPinch();
            }
          },
          onVerticalDragEnd: (details) {
            final vy = details.primaryVelocity ?? 0;
            if (vy < -250) {
              cubit.handleTrainingSwipeUp();
            } else if (vy > 250) {
              cubit.handleTrainingSwipeDown();
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'SPATIAL SOUND TRAINING',
                  style: TextStyle(
                    color: AppTheme.cyanHighlight,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Column(
                  children: [
                    _buildCheckTile(
                      label: SpatialGesture.swipeToFocus.onboardingStepLabel,
                      isMastered: state.hasMasteredNorthSwipe,
                    ),
                    const SizedBox(height: 14),
                    _buildCheckTile(
                      label: SpatialGesture.swipeToComms.onboardingStepLabel,
                      isMastered: state.hasMasteredSouthSwipe,
                    ),
                    const SizedBox(height: 14),
                    _buildCheckTile(
                      label: SpatialGesture.ascendToSettings.onboardingStepLabel,
                      isMastered: state.hasMasteredPinch,
                    ),
                  ],
                ),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: state.hasMasteredNorthSwipe
                          ? AppTheme.cyanHighlight
                          : AppTheme.voidCardSurface,
                      foregroundColor: state.hasMasteredNorthSwipe
                          ? AppTheme.pureBlack
                          : AppTheme.highContrastMuted,
                    ),
                    onPressed:
                        state.hasMasteredNorthSwipe ? cubit.nextStep : null,
                    child: Text(
                      state.hasMasteredNorthSwipe
                          ? 'Next: Test Camera Eyes ➡️'
                          : 'Swipe UP to practice',
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCheckTile({required String label, required bool isMastered}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.voidCardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMastered
              ? AppTheme.cyanHighlight
              : AppTheme.highContrastBorder,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isMastered
                    ? AppTheme.highContrastText
                    : AppTheme.highContrastMuted,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
          Icon(
            isMastered
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked,
            color: isMastered
                ? AppTheme.cyanHighlight
                : AppTheme.highContrastBorder,
          ),
        ],
      ),
    );
  }
}

typedef BlindCompassStep = CompassTrainingStep;