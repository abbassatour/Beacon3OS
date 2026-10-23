// lib/tv/shared/widgets/tv_focusable_card.dart
import 'package:beacon_os/core/audio/sound_controller.dart';
import 'package:beacon_os/core/audio/sound_cue.dart';
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TvFocusableCard extends StatefulWidget {
  const TvFocusableCard({
    required this.focusNode,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.child,
    this.onSelect,
    super.key,
  });

  final FocusNode focusNode;
  final String title;
  final String? subtitle;
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
    if (mounted) {
      setState(() => _isFocused = hasFocus);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isOled = Theme.of(context).brightness == Brightness.dark;

    // تدرج لوني سينمائي ناعم يبرز عند تحديد البطاقة بالريموت
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
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
      },
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
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _isFocused ? null : colors.surface,
            gradient: backgroundGradient,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isFocused
                  ? widget.accentColor
                  : colors.outline.withValues(alpha: 0.35),
              width: _isFocused ? 2.5 : 1.2,
            ),
            boxShadow: [
              if (_isFocused) ...[
                BoxShadow(
                  color: widget.accentColor.withValues(alpha: 0.35),
                  blurRadius: 24,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.30),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // هيدر البطاقة المدمج والمحمي من الطفح
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: widget.accentColor.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: widget.accentColor.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Icon(
                      widget.icon,
                      color: widget.accentColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w900,
                            fontSize: 14.5,
                            letterSpacing: 1.0,
                          ),
                        ),
                        if (widget.subtitle != null &&
                            widget.subtitle!.trim().isNotEmpty) ...[
                          const SizedBox(height: 1),
                          Text(
                            widget.subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_isFocused)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: widget.accentColor,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: widget.accentColor.withValues(alpha: 0.4),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Text(
                        'SELECT',
                        style: TextStyle(
                          color: colors.surface,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              // مساحة المحتوى المرنة
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