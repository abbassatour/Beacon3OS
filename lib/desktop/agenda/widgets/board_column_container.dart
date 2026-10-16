import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class BoardColumnContainer extends StatelessWidget {
  const BoardColumnContainer({
    required this.title,
    required this.count,
    required this.icon,
    required this.accentColor,
    required this.child,
    this.headerAction,
    super.key,
  });

  final String title;
  final int count;
  final IconData icon;
  final Color accentColor;
  final Widget child;
  final Widget? headerAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      decoration: BoxDecoration(
        color: context.scaffoldBg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outline.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icon, color: accentColor, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      '$title ($count)',
                      style: TextStyle(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
                if (headerAction != null) headerAction!,
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

Widget buildEmptyColumnPlaceholder({
  required IconData icon,
  required String message,
  required ColorScheme colors,
}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: colors.onSurfaceVariant.withValues(alpha: 0.4),
            size: 36,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}
