import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/desktop/cubit/desktop_agenda_cubit.dart';
import 'package:beacon_os/desktop/widgets/agenda/board_column_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:local_vault_api/local_vault_api.dart';

class MemosColumn extends StatelessWidget {
  const MemosColumn({required this.memos, super.key});

  final List<VoiceMemo> memos;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cubit = context.read<DesktopAgendaCubit>();

    return BoardColumnContainer(
      title: 'VOICE & AI NOTES',
      count: memos.length,
      icon: Icons.notes_rounded,
      accentColor: colors.secondary,
      headerAction: IconButton(
        icon: const Icon(Icons.note_add_rounded, size: 18),
        tooltip: 'New Note',
        onPressed: () => _showAddMemoDialog(context, cubit),
      ),
      child: memos.isEmpty
          ? buildEmptyColumnPlaceholder(
              icon: Icons.mic_none_rounded,
              message: 'No voice notes in vault.',
              colors: colors,
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: memos.length,
              itemBuilder: (context, index) {
                final memo = memos[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.outline.withValues(alpha: 0.6)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              memo.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.onSurface,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline_rounded, size: 16, color: colors.error),
                            onPressed: () => cubit.deleteMemo(memo),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        memo.content,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        DateFormat('MMM d, h:mm a').format(memo.createdAt),
                        style: TextStyle(
                          color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  void _showAddMemoDialog(BuildContext context, DesktopAgendaCubit cubit) {
    final colors = context.colors;
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'New Quick Note',
          style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contentCtrl,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Content'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.surface,
            ),
            onPressed: () {
              cubit.addNewMemo(title: titleCtrl.text, content: contentCtrl.text);
              Navigator.of(ctx).pop();
            },
            child: const Text('Save Note'),
          ),
        ],
      ),
    );
  }
}