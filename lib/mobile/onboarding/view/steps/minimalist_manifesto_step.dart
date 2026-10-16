// lib/mobile/onboarding/view/steps/minimalist_manifesto_step.dart
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/mobile/onboarding/cubit/minimalist_onboarding_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class MinimalistManifestoStep extends StatelessWidget {
  const MinimalistManifestoStep({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MinimalistOnboardingCubit>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          const Text(
            'RECLAIM\nYOUR FOCUS.',
            style: TextStyle(
              color: AppTheme.carbonInk,
              fontSize: 42,
              fontWeight: FontWeight.w900,
              height: 1.05,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'The average human checks their phone over 140 times a day. Red badges, endless algorithmic feeds, and visual clutter fracture our deep thinking.\n\nBeaconOS is an invisible operating system: no app icons, no infinite scroll, just a voice-first spatial cockpit designed to put your phone back in your pocket.',
            style: TextStyle(
              color: AppTheme.mutedInk,
              fontSize: 16,
              height: 1.55,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.softBorder),
            ),
            child: Row(
              children: const [
                Icon(Icons.spa_rounded, color: AppTheme.terracotta, size: 28),
                SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Zero Feeds • Zero Red Badges • Pure Intention',
                    style: TextStyle(
                      color: AppTheme.carbonInk,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
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
                'Begin Intentional Setup ➔',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}