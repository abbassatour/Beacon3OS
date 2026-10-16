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
        return TvFocusableCard(
          focusNode: focusNode,
          title: 'ACOUSTIC PHONE LOCATOR',
          subtitle: state.isPinging
              ? 'Pinging Phone Siren Now...'
              : 'Press [SELECT] to ping missing phone',
          icon: Icons.radar_rounded,
          accentColor: state.isPinging ? colors.secondary : colors.primary,
          onSelect: cubit.pingPhone,
          child: Center(
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TvPulsingRadarIcon(
                    icon: Icons.phonelink_ring_rounded,
                    color: state.isPinging ? colors.secondary : colors.primary,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    state.isPinging
                        ? 'SIREN & STROBE ACTIVE'
                        : 'PING PHONE HARDWARE',
                    style: TextStyle(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Pings phone instantly via Local LAN (< 2ms)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}