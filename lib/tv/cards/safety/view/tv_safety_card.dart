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
        final isBroadcasting = state.isBroadcasting;

        return TvFocusableCard(
          focusNode: focusNode,
          title: 'HOUSEHOLD SAFETY RADAR',
          subtitle: isBroadcasting
              ? 'Broadcasting SOS distress telemetry...'
              : 'Immutable distress beacon & Arbitrum L2',
          icon: Icons.shield_rounded,
          accentColor: colors.error,
          onSelect: cubit.triggerEmergencySos,
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.error.withValues(alpha: isBroadcasting ? 0.35 : 0.14),
                  border: Border.all(color: colors.error, width: 2),
                ),
                child: Icon(
                  isBroadcasting ? Icons.cell_tower_rounded : Icons.warning_amber_rounded,
                  size: 32,
                  color: colors.error,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Text(
                          isBroadcasting ? 'EMERGENCY ACTIVE' : 'ARBITRUM VERIFIED',
                          style: TextStyle(
                            color: colors.error,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.green, width: 0.8),
                          ),
                          child: const Text(
                            'ON-CHAIN',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isBroadcasting
                          ? 'Broadcasting live GPS beacon to emergency contacts and Arbitrum Sepolia ledger.'
                          : 'Press [SELECT] to broadcast immediate distress alarm and stream GPS to rescue radar.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}