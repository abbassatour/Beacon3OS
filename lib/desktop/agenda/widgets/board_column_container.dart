// lib/desktop/agenda/widgets/board_column_container.dart
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // 🌟 جعل العنوان مرناً لمنع الطفح عند صغر عرض العمود
                Expanded(
                  child: Row(
                    children: [
                      Icon(icon, color: accentColor, size: 15),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '$title ($count)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w900,
                            fontSize: 10.5,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
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
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: colors.onSurfaceVariant.withValues(alpha: 0.4),
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11.5),
          ),
        ],
      ),
    ),
  );
}