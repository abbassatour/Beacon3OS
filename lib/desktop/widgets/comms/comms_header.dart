import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/desktop/cubit/desktop_comms_cubit.dart';
import 'package:beacon_os/desktop/cubit/desktop_comms_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CommsHeader extends StatelessWidget {
  const CommsHeader({required this.state, super.key});

  final DesktopCommsState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cubit = context.read<DesktopCommsCubit>();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shield_rounded, color: colors.error, size: 26),
                const SizedBox(width: 10),
                Text(
                  'SAFETY RADAR & ON-CHAIN DISPATCH',
                  style: TextStyle(
                    color: colors.onSurface,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Arbitrum Sepolia immutable SOS attestations, phonebook sync, and encrypted message vault.',
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
        Row(
          children: [
            SizedBox(
              width: 220,
              height: 38,
              child: TextField(
                onChanged: cubit.setSearchQuery,
                decoration: InputDecoration(
                  hintText: 'Search contacts...',
                  hintStyle: TextStyle(
                    color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: colors.onSurfaceVariant,
                  ),
                  filled: true,
                  fillColor: colors.surface,
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: colors.outline.withValues(alpha: 0.6)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: colors.outline.withValues(alpha: 0.6)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                backgroundColor: colors.surface,
                foregroundColor: colors.onSurface,
                side: BorderSide(color: colors.outline),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              icon: state.isSyncingContacts
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary),
                    )
                  : const Icon(Icons.sync_rounded, size: 18),
              label: const Text(
                'Sync Phonebook',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              onPressed: state.isSyncingContacts ? null : cubit.syncDeviceContacts,
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              icon: const Icon(Icons.person_add_rounded, size: 18),
              label: const Text(
                'Add Contact',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              onPressed: () => _showAddContactDialog(context, cubit),
            ),
          ],
        ),
      ],
    );
  }

  void _showAddContactDialog(BuildContext context, DesktopCommsCubit cubit) {
    final colors = context.colors;
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final relationCtrl = TextEditingController();
    bool isEmergency = false;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: colors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            'New Contact',
            style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name (e.g. John, Mom)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Phone Number'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: relationCtrl,
                decoration: const InputDecoration(labelText: 'Relationship (Optional)'),
              ),
              const SizedBox(height: 14),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Mark as Emergency SOS Contact',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                activeColor: colors.error,
                value: isEmergency,
                onChanged: (val) => setDialogState(() => isEmergency = val),
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
                if (nameCtrl.text.isNotEmpty && phoneCtrl.text.isNotEmpty) {
                  cubit.addNewContact(
                    name: nameCtrl.text,
                    phoneNumber: phoneCtrl.text,
                    relationship: relationCtrl.text.isEmpty ? null : relationCtrl.text,
                    isEmergency: isEmergency,
                  );
                  Navigator.of(ctx).pop();
                }
              },
              child: const Text('Save Contact'),
            ),
          ],
        ),
      ),
    );
  }
}