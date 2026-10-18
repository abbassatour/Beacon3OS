// lib/desktop/agenda/widgets/quick_task_composer_bar.dart
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outline.withValues(alpha: 0.8)),
      ),
      child: Row(
        children: [
          Icon(Icons.add_task_rounded, color: colors.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _controller,
              onSubmitted: (_) => _submit(),
              style: TextStyle(color: colors.onSurface, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Type a priority task and press [Enter]...',
                hintStyle: TextStyle(
                  color: colors.onSurfaceVariant.withValues(alpha: 0.8),
                  fontSize: 12,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 6),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedPriority,
              isDense: true,
              dropdownColor: colors.surface,
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 11.5,
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
          const SizedBox(width: 6),
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: colors.onSurfaceVariant,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: Icon(
              Icons.event_rounded,
              size: 15,
              color: _selectedDueDate != null ? colors.primary : colors.onSurfaceVariant,
            ),
            label: Text(
              _selectedDueDate == null
                  ? 'Due'
                  : DateFormat('MMM d').format(_selectedDueDate!),
              style: TextStyle(
                fontSize: 11.5,
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: _submit,
            child: const Text(
              'Add',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }
}