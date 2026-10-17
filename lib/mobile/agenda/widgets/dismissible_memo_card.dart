// lib/mobile/agenda/widgets/dismissible_memo_card.dart
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:launcher_repository/launcher_repository.dart'; // ✅ الاستيراد النقي

class DismissibleMemoCard extends StatelessWidget {
  const DismissibleMemoCard({
    required this.memo,
    required this.onDismissed,
    required this.onReadAloud,
    super.key,
  });

  final VoiceMemoEntity memo; // ✅ الكيان النقي
  final VoidCallback onDismissed;
  final VoidCallback onReadAloud;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: Key(memo.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: colors.error.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.delete_outline_rounded, color: colors.error),
        ),
        onDismissed: (_) => onDismissed(),
        child: Semantics(
          label: 'Note titled ${memo.title}. Tap to listen.',
          button: true,
          child: Material(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onReadAloud,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.outline, width: 1.2),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor:
                          colors.secondary.withValues(alpha: 0.15),
                      child: Icon(
                        Icons.notes_rounded,
                        color: colors.secondary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            memo.title,
                            style: TextStyle(
                              color: colors.onSurface,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            memo.content,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.volume_up_rounded,
                      color: colors.primary,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}