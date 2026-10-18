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
              ? 'Broadcasting SOS Distress Signal to Ledger...'
              : 'Household distress beacon & Arbitrum L2',
          icon: Icons.emergency_rounded,
          accentColor: colors.error,
          onSelect: cubit.triggerEmergencySos,
          child: Row(
            children: [
              CircleAvatar(
                radius: 28, // 👈 تكبير الأيقونة لتكون بارزة على الشاشة
                backgroundColor: colors.error.withValues(
                  alpha: state.isBroadcasting ? 0.35 : 0.15,
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
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
                    if (state.isBroadcasting)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: colors.error,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'RADAR ACTIVE • BROADCASTING GPS',
                          style: TextStyle(
                            color: colors.surface,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    Text(
                      state.isBroadcasting
                          ? 'Distress beacon is broadcasting live GPS coordinates to Arbitrum Sepolia ledger and sounding alarm across home.'
                          : 'Triple-tapping phone sounds household distress alarm and anchors immutable GPS beacon to Arbitrum Sepolia ledger.',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: 13.5, // 👈 خط مريح جداً للقراءة من مسافة 3 أمتار
                        height: 1.35,
                        fontWeight: FontWeight.w600,
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