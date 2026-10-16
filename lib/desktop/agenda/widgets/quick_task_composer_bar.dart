import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/desktop/agenda/cubit/desktop_agenda_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

class QuickTaskComposerBar extends StatefulWidget {
  const QuickTaskComposerBar({super.key});

  @override
  State<QuickTaskComposerBar> createState() => _QuickTaskComposerBarState();
}

class _QuickTaskComposerBarState extends State<QuickTaskComposerBar> {
  final _controller = TextEditingController();
  String _selectedPriority = 'medium';
  DateTime? _selectedDueDate;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    context.read<DesktopAgendaCubit>().addNewTask(
          title: text,
          priority: _selectedPriority,
          dueDate: _selectedDueDate,
        );

    _controller.clear();
    setState(() {
      _selectedDueDate = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outline.withValues(alpha: 0.8)),
      ),
      child: Row(
        children: [
          Icon(Icons.add_task_rounded, color: colors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _controller,
              onSubmitted: (_) => _submit(),
              style: TextStyle(color: colors.onSurface, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Type a priority task and press [Enter] to create...',
                hintStyle: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
                border: InputBorder.none,
              ),
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedPriority,
              dropdownColor: colors.surface,
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              items: const [
                DropdownMenuItem(value: 'high', child: Text('High')),
                DropdownMenuItem(value: 'medium', child: Text('Medium')),
                DropdownMenuItem(value: 'low', child: Text('Low')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedPriority = val);
              },
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: colors.onSurfaceVariant,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            icon: Icon(
              Icons.event_rounded,
              size: 16,
              color: _selectedDueDate != null ? colors.primary : colors.onSurfaceVariant,
            ),
            label: Text(
              _selectedDueDate == null
                  ? 'Due Date'
                  : DateFormat('MMM d').format(_selectedDueDate!),
              style: TextStyle(
                fontSize: 12,
                color: _selectedDueDate != null ? colors.primary : colors.onSurfaceVariant,
                fontWeight: _selectedDueDate != null ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) {
                setState(() => _selectedDueDate = picked);
              }
            },
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.surface,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _submit,
            child: const Text(
              'Add Task',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
