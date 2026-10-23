// lib/tv/modes/ambient/tv_ambient_screensaver.dart
import 'dart:math' as math;
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/tv/shell/cubit/tv_shell_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

class TvAmbientScreensaver extends StatelessWidget {
  const TvAmbientScreensaver({
    required this.currentTime,
    super.key,
  });

  final DateTime currentTime;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final timeStr = DateFormat('h:mm').format(currentTime);
    final periodStr = DateFormat('a').format(currentTime);
    final dateStr = DateFormat('EEEE, MMMM d').format(currentTime);

    // 🛡️ حماية شاشات OLED من التطبيع (Burn-in Offset Shift)
    final minuteSeed = currentTime.minute;
    final shiftX = (math.sin(minuteSeed) * 16.0);
    final shiftY = (math.cos(minuteSeed) * 12.0);

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          context.read<TvShellCubit>().wakeFromAmbient();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Center(
        key: const ValueKey('tv_ambient_screensaver'),
        child: Transform.translate(
          offset: Offset(shiftX, shiftY),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    timeStr,
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 110,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -4,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    periodStr,
                    style: TextStyle(
                      color: colors.primary,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                dateStr,
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: 0.60),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: colors.outline.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Living Room Bridge Active • Press any remote button to wake',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}