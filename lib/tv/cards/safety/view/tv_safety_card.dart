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
          title: 'EMERGENCY DISTRESS BEACON',
          subtitle: isBroadcasting ? 'Broadcasting live GPS distress radar...' : null,
          icon: Icons.shield_rounded,
          accentColor: colors.error,
          onSelect: cubit.triggerEmergencySos,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  // أيقونة الطوارئ النبضية
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.error.withValues(
                        alpha: isBroadcasting ? 0.35 : 0.15,
                      ),
                      border: Border.all(
                        color: colors.error,
                        width: isBroadcasting ? 2.5 : 1.5,
                      ),
                    ),
                    child: Icon(
                      isBroadcasting
                          ? Icons.cell_tower_rounded
                          : Icons.warning_amber_rounded,
                      size: 24,
                      color: colors.error,
                    ),
                  ),
                  const SizedBox(width: 14),
                  // معلومات الاستغاثة المباشرة
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isBroadcasting
                                ? 'DISTRESS BROADCAST ACTIVE'
                                : 'SOS RADAR READY',
                            style: TextStyle(
                              color: colors.error,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: Colors.green.withValues(alpha: 0.5),
                                width: 0.8,
                              ),
                            ),
                            child: const Text(
                              'ARBITRUM L2',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isBroadcasting
                            ? 'Streaming real-time coordinates to rescue radar.'
                            : 'Press [SELECT] to sound siren & dispatch live GPS.',
                        style: TextStyle(
                          color: colors.onSurface,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
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