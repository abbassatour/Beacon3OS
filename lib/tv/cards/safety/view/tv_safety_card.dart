// lib/tv/cards/safety/view/tv_safety_card.dart
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/tv/cards/safety/cubit/tv_safety_cubit.dart';
import 'package:beacon_os/tv/cards/safety/cubit/tv_safety_state.dart';
import 'package:beacon_os/tv/shared/widgets/tv_focusable_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TvSafetyCard extends StatelessWidget {
  const TvSafetyCard({
    required this.focusNode,
    super.key,
  });

  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cubit = context.read<TvSafetyCubit>();

    return BlocBuilder<TvSafetyCubit, TvSafetyState>(
      builder: (context, state) {
        return TvFocusableCard(
          focusNode: focusNode,
          title: 'FAMILY SAFETY RADAR (SOS)',
          subtitle: state.isBroadcasting
              ? 'Broadcasting SOS Distress Signal...'
              : 'Household distress beacon & Arbitrum L2',
          icon: Icons.emergency_rounded,
          accentColor: colors.error,
          onSelect: cubit.triggerEmergencySos,
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: colors.error.withValues(
                  alpha: state.isBroadcasting ? 0.35 : 0.15,
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  size: 26,
                  color: colors.error,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  state.isBroadcasting
                      ? 'Distress beacon is broadcasting live GPS coordinates to Arbitrum Sepolia ledger and triggering alerts across all home devices.'
                      : 'Triple-tapping phone sounds household distress alarm and anchors immutable GPS beacon to Arbitrum Sepolia ledger.',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
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