// lib/tv/shared/widgets/tv_focusable_card.dart
import 'package:beacon_os/core/audio/sound_controller.dart';
import 'package:beacon_os/core/audio/sound_cue.dart';
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class TvFocusableCard extends StatefulWidget {
  const TvFocusableCard({
    required this.focusNode,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.child,
    this.onSelect,
    super.key,
  });

  final FocusNode focusNode;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final Widget child;
  final VoidCallback? onSelect;

  @override
  State<TvFocusableCard> createState() => _TvFocusableCardState();
}

class _TvFocusableCardState extends State<TvFocusableCard> {
  bool _isFocused = false;
  static DateTime _lastSoundTime = DateTime.fromMillisecondsSinceEpoch(0);

  void _onFocusChanged(bool hasFocus) {
    if (hasFocus) {
      final now = DateTime.now();
      if (now.difference(_lastSoundTime).inMilliseconds > 120) {
        _lastSoundTime = now;
        SoundController.instance.play(SoundCue.navMove);
      }
    }
    setState(() => _isFocused = hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return FocusableActionDetector(
      focusNode: widget.focusNode,
      onFocusChange: _onFocusChanged,
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) => widget.onSelect?.call(),
        ),
      },
      child: AnimatedScale(
        scale: _isFocused ? 1.025 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isFocused
                  ? widget.accentColor
                  : colors.outline.withValues(alpha: 0.5),
              width: _isFocused ? 3.2 : 1.4,
            ),
            boxShadow: [
              if (_isFocused)
                BoxShadow(
                  color: widget.accentColor.withValues(alpha: 0.35),
                  blurRadius: 24,
                  spreadRadius: 3,
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(widget.icon, color: widget.accentColor, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w900,
                            fontSize: 17, // 👈 متوافق مع شاشات 10-Foot UI
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 13.5, // 👈 وضوح القراءة عن بعد
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isFocused)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: widget.accentColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'PRESS [SELECT]',
                        style: TextStyle(
                          color: colors.surface,
                          fontSize: 11.5, // 👈 وضوح شارة الريموت
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                ],
              ),
              const Divider(height: 20, thickness: 1.2),
              Expanded(child: widget.child),
            ],
          ),
        ),
      ),
    );
  }
}