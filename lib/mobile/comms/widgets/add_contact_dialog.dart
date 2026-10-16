// lib/comms/widgets/add_contact_dialog.dart
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class AddContactDialog extends StatefulWidget {
  const AddContactDialog({required this.onSave, super.key});

  final void Function({
    required String name,
    required String phoneNumber,
    String? relationship,
    required bool isEmergency,
  }) onSave;

  @override
  State<AddContactDialog> createState() => _AddContactDialogState();
}

class _AddContactDialogState extends State<AddContactDialog> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _relationController = TextEditingController();
  bool _isEmergency = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _relationController.dispose();
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
        'Add Contact',
        style: TextStyle(
          color: colors.onSurface,
          fontWeight: FontWeight.w900,
          fontSize: 20,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              style: TextStyle(color: colors.onSurface),
              decoration: InputDecoration(
                labelText: 'Name (e.g. John Doe, Mom)',
                labelStyle: TextStyle(color: colors.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: TextStyle(color: colors.onSurface),
              decoration: InputDecoration(
                labelText: 'Phone Number',
                labelStyle: TextStyle(color: colors.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _relationController,
              style: TextStyle(color: colors.onSurface),
              decoration: InputDecoration(
                labelText: 'Relationship (e.g. Father, Doctor)',
                labelStyle: TextStyle(color: colors.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Emergency SOS Contact',
                style: TextStyle(
                  color: colors.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                'Auto-receive GPS radar when SOS triggers',
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
              ),
              activeColor: colors.error,
              value: _isEmergency,
              onChanged: (val) => setState(() => _isEmergency = val),
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
            backgroundColor: _isEmergency ? colors.error : colors.primary,
            foregroundColor: colors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () {
            final name = _nameController.text.trim();
            final phone = _phoneController.text.trim();
            if (name.isNotEmpty && phone.isNotEmpty) {
              widget.onSave(
                name: name,
                phoneNumber: phone,
                relationship: _relationController.text.trim().isEmpty
                    ? null
                    : _relationController.text.trim(),
                isEmergency: _isEmergency,
              );
              Navigator.of(context).pop();
            }
          },
          child: const Text(
            'Save Contact',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}