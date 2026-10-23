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
        final accent = isPinging ? colors.secondary : colors.primary;

        return TvFocusableCard(
          focusNode: focusNode,
          title: 'ACOUSTIC PHONE LOCATOR',
          subtitle: isPinging ? 'Broadcasting Siren & Strobe...' : null,
          icon: Icons.radar_rounded,
          accentColor: accent,
          onSelect: cubit.pingPhone,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TvPulsingRadarIcon(
                      icon: isPinging
                          ? Icons.volume_up_rounded
                          : Icons.phonelink_ring_rounded,
                      color: accent,
                      radius: 26,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isPinging ? 'SIREN & STROBE ACTIVE' : 'FIND MY PHONE',
                      style: TextStyle(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w900,
                        fontSize: 16.5,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.35),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPinging
                                ? Icons.graphic_eq_rounded
                                : Icons.bolt_rounded,
                            size: 13,
                            color: accent,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isPinging
                                ? 'Hardware Siren Pinging'
                                : 'Press [SELECT] • LAN Direct < 2ms',
                            style: TextStyle(
                              color: accent,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}