import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AddTaskDialog extends StatefulWidget {
  const AddTaskDialog({required this.onSave, super.key});

  final void Function({
    required String title,
    required String priority,
    DateTime? dueDate,
  }) onSave;

  @override
  State<AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<AddTaskDialog> {
  final _titleController = TextEditingController();
  String _priority = 'medium';
  DateTime? _selectedDateTime;

  @override
  void dispose() {
    _titleController.dispose();
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
        'New Task',
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
              autofocus: true,
              style: TextStyle(color: colors.onSurface),
              decoration: InputDecoration(
                labelText: 'Task title...',
                labelStyle: TextStyle(color: colors.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _priority,
              dropdownColor: colors.surface,
              style: TextStyle(color: colors.onSurface),
              decoration: InputDecoration(
                labelText: 'Priority',
                labelStyle: TextStyle(color: colors.onSurfaceVariant),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'high',
                  child: Text('High Priority 🔴'),
                ),
                DropdownMenuItem(
                  value: 'medium',
                  child: Text('Medium Priority 🟡'),
                ),
                DropdownMenuItem(
                  value: 'low',
                  child: Text('Low Priority ⚪'),
                ),
              ],
              onChanged: (val) =>
                  setState(() => _priority = val ?? 'medium'),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: colors.outline),
                foregroundColor: colors.onSurface,
                minimumSize: const Size(double.infinity, 44),
              ),
              icon: Icon(
                Icons.event_rounded,
                size: 18,
                color: colors.primary,
              ),
              label: Text(
                _selectedDateTime == null
                    ? 'Set Deadline (Optional)'
                    : 'Due: ${DateFormat('MMM d • h:mm a').format(_selectedDateTime!)}',
                style: const TextStyle(fontSize: 13),
              ),
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null && context.mounted) {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (time != null) {
                    setState(() {
                      _selectedDateTime = DateTime(
                        date.year,
                        date.month,
                        date.day,
                        time.hour,
                        time.minute,
                      );
                    });
                  }
                }
              },
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
            backgroundColor: colors.primary,
            foregroundColor: colors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () {
            final text = _titleController.text.trim();
            if (text.isNotEmpty) {
              widget.onSave(
                title: text,
                priority: _priority,
                dueDate: _selectedDateTime,
              );
              Navigator.of(context).pop();
            }
          },
          child: const Text(
            'Create Task',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}