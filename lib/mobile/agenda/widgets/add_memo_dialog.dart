import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class AddMemoDialog extends StatefulWidget {
  const AddMemoDialog({required this.onSave, super.key});

  final void Function({
    required String title,
    required String content,
  }) onSave;

  @override
  State<AddMemoDialog> createState() => _AddMemoDialogState();
}

class _AddMemoDialogState extends State<AddMemoDialog> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AlertDialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.outline, width: 1.5),
      ),
      title: Text(
        'New Voice / Quick Note',
        style: TextStyle(
          color: colors.onSurface,
          fontWeight: FontWeight.w900,
          fontSize: 20,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              style: TextStyle(color: colors.onSurface),
              decoration: InputDecoration(
                labelText: 'Title (e.g. Ideas, Project memo)...',
                labelStyle: TextStyle(color: colors.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contentController,
              maxLines: 4,
              style: TextStyle(color: colors.onSurface),
              decoration: InputDecoration(
                labelText: 'Note content...',
                labelStyle: TextStyle(color: colors.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.secondary,
            foregroundColor: colors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () {
            final title = _titleController.text.trim();
            final content = _contentController.text.trim();
            if (title.isNotEmpty || content.isNotEmpty) {
              widget.onSave(
                title: title.isEmpty ? 'Untitled Note' : title,
                content: content.isEmpty ? title : content,
              );
              Navigator.of(context).pop();
            }
          },
          child: const Text(
            'Save Note',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}