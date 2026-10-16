// lib/mobile/onboarding/view/gateway_page.dart
import 'package:beacon_os/core/audio/sound_controller.dart';
import 'package:beacon_os/core/audio/sound_cue.dart';
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/core/theme/cubit/theme_cubit.dart';
import 'package:beacon_os/mobile/onboarding/view/accessible_onboarding_page.dart';
import 'package:beacon_os/mobile/onboarding/view/minimalist_onboarding_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';

class GatewayPage extends StatefulWidget {
  const GatewayPage({super.key});

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const GatewayPage());

  @override
  State<GatewayPage> createState() => _GatewayPageState();
}

class _GatewayPageState extends State<GatewayPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announceGatewayInstructions();
    });
  }

  Future<void> _announceGatewayInstructions() async {
    final assistant = context.read<AssistantRepository>();
    await SoundController.instance.play(SoundCue.wake);
    await HapticFeedback.mediumImpact();
    await assistant.speak(
      'Welcome to Beacon OS. Tap the top half of your screen for Vision and Accessibility Mode. '
      'Tap the bottom half for Digital Minimalist Mode.',
    );
  }

  void _selectAccessibleFlow() {
    final assistant = context.read<AssistantRepository>();
    assistant.stopSpeaking();

    context.read<ThemeCubit>().toggleTheme(isHighContrast: true);
    SoundController.instance.play(SoundCue.navCenter);
    HapticFeedback.heavyImpact();

    Navigator.of(context).pushReplacement(AccessibleOnboardingPage.route());
  }

  void _selectMinimalistFlow() {
    final assistant = context.read<AssistantRepository>();
    assistant.stopSpeaking();

    context.read<ThemeCubit>().toggleTheme(isHighContrast: false);
    SoundController.instance.play(SoundCue.navCenter);
    HapticFeedback.mediumImpact();

    Navigator.of(context).pushReplacement(MinimalistOnboardingPage.route());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: Semantics(
                label:
                    'Vision and Accessibility Mode. Tap anywhere on the upper half of the screen to choose this path.',
                button: true,
                child: Material(
                  color: AppTheme.pureBlack,
                  child: InkWell(
                    onTap: _selectAccessibleFlow,
                    splashColor: AppTheme.cyanHighlight.withValues(alpha: 0.25),
                    highlightColor:
                        AppTheme.cyanHighlight.withValues(alpha: 0.12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 20,
                      ),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: AppTheme.cyanHighlight,
                            width: 2.5,
                          ),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppTheme.cyanHighlight,
                                width: 2,
                              ),
                              color: AppTheme.cyanHighlight
                                  .withValues(alpha: 0.12),
                            ),
                            child: const Icon(
                              Icons.visibility_rounded,
                              size: 48,
                              color: AppTheme.cyanHighlight,
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'VISION & ACCESSIBILITY',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.highContrastText,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'High-contrast OLED display, voice guidance, spatial camera vision, and emergency radar.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.highContrastMuted,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: AppTheme.cyanHighlight
                                  .withValues(alpha: 0.15),
                              border: Border.all(color: AppTheme.cyanHighlight),
                            ),
                            child: const Text(
                              'TAP TOP HALF TO SELECT',
                              style: TextStyle(
                                color: AppTheme.cyanHighlight,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Semantics(
                label:
                    'Digital Minimalist Mode. Tap anywhere on the lower half of the screen to choose this path.',
                button: true,
                child: Material(
                  color: AppTheme.warmPaper,
                  child: InkWell(
                    onTap: _selectMinimalistFlow,
                    splashColor: AppTheme.terracotta.withValues(alpha: 0.15),
                    highlightColor: AppTheme.terracotta.withValues(alpha: 0.08),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 20,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppTheme.softBorder,
                                width: 2,
                              ),
                              color: AppTheme.cardSurface,
                            ),
                            child: const Icon(
                              Icons.spa_rounded,
                              size: 48,
                              color: AppTheme.terracotta,
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'DIGITAL MINIMALIST',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.carbonInk,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Calm editorial canvas, intentional eyes-free productivity, focus sessions, and zero distractions.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.mutedInk,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: AppTheme.terracotta.withValues(alpha: 0.1),
                              border: Border.all(color: AppTheme.terracotta),
                            ),
                            child: const Text(
                              'TAP BOTTOM HALF TO SELECT',
                              style: TextStyle(
                                color: AppTheme.terracotta,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
