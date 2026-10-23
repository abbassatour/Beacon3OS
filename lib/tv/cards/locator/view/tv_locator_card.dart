// lib/tv/cards/locator/view/tv_locator_card.dart
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/tv/cards/locator/cubit/tv_locator_cubit.dart';
import 'package:beacon_os/tv/cards/locator/cubit/tv_locator_state.dart';
import 'package:beacon_os/tv/shared/widgets/tv_focusable_card.dart';
import 'package:beacon_os/tv/shared/widgets/tv_pulsing_radar_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TvLocatorCard extends StatelessWidget {
  const TvLocatorCard({
    required this.focusNode,
    super.key,
  });

  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cubit = context.read<TvLocatorCubit>();

    return BlocBuilder<TvLocatorCubit, TvLocatorState>(
      builder: (context, state) {
        final isPinging = state.isPinging;

        return TvFocusableCard(
          focusNode: focusNode,
          title: 'ACOUSTIC PHONE LOCATOR',
          subtitle: isPinging
              ? 'Broadcasting siren & hardware strobe strobe...'
              : 'Locate misplaced phone in living room instantly',
          icon: Icons.radar_rounded,
          accentColor: isPinging ? colors.secondary : colors.primary,
          onSelect: cubit.pingPhone,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TvPulsingRadarIcon(
                  icon: isPinging ? Icons.volume_up_rounded : Icons.phonelink_ring_rounded,
                  color: isPinging ? colors.secondary : colors.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  isPinging ? 'HARDWARE PING ACTIVE' : 'PING PHONE HARDWARE',
                  style: TextStyle(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isPinging ? colors.secondary : colors.primary).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: (isPinging ? colors.secondary : colors.primary).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    isPinging ? 'Triggering Siren, Haptics & Flashlight' : 'Press [SELECT] • LAN Direct < 2ms',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isPinging ? colors.secondary : colors.primary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
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
}