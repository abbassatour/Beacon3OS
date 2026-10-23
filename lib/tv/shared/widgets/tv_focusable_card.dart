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
    final isOled = Theme.of(context).brightness == Brightness.dark;

    // تدرج لوني سينمائي ناعم يبرز عند تحديد البطاقة
    final backgroundGradient = _isFocused
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              widget.accentColor.withValues(alpha: isOled ? 0.22 : 0.12),
              colors.surface,
              colors.surface,
            ],
          )
        : null;

    return FocusableActionDetector(
      focusNode: widget.focusNode,
      onFocusChange: _onFocusChanged,
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) => widget.onSelect?.call(),
        ),
      },
      child: AnimatedScale(
        scale: _isFocused ? 1.035 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: _isFocused ? null : colors.surface,
            gradient: backgroundGradient,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _isFocused
                  ? widget.accentColor
                  : colors.outline.withValues(alpha: 0.4),
              width: _isFocused ? 3.0 : 1.2,
            ),
            boxShadow: [
              if (_isFocused) ...[
                // هالة توهج علوية
                BoxShadow(
                  color: widget.accentColor.withValues(alpha: 0.40),
                  blurRadius: 32,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
                // ظل عمق ثلاثي الأبعاد
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // رأس البطاقة
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.accentColor.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: widget.accentColor.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Icon(
                      widget.icon,
                      color: widget.accentColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
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
                            fontSize: 17,
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
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isFocused)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: widget.accentColor,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: widget.accentColor.withValues(alpha: 0.5),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Text(
                        'PRESS [SELECT]',
                        style: TextStyle(
                          color: colors.surface,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                ],
              ),
              const Divider(height: 24, thickness: 1.0),
              Expanded(
                child: Focus(
                  canRequestFocus: false,
                  descendantsAreFocusable: false,
                  child: widget.child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}