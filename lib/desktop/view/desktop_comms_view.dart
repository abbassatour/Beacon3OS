// lib/desktop/view/desktop_comms_view.dart
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/desktop/cubit/desktop_comms_cubit.dart';
import 'package:beacon_os/desktop/cubit/desktop_comms_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:launcher_repository/launcher_repository.dart';
import 'package:local_vault_api/local_vault_api.dart';
import 'package:url_launcher/url_launcher.dart';

class DesktopCommsView extends StatelessWidget {
  const DesktopCommsView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DesktopCommsCubit(
        commsRepository: context.read<CommsRepository>(),
      ),
      child: const _DesktopCommsContent(),
    );
  }
}

class _DesktopCommsContent extends StatelessWidget {
  const _DesktopCommsContent();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return BlocBuilder<DesktopCommsCubit, DesktopCommsState>(
      builder: (context, state) {
        if (state.status == DesktopCommsStatus.loading && state.contacts.isEmpty) {
          return Center(
            child: CircularProgressIndicator(color: colors.primary),
          );
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. رأس الصفحة: العناوين وأزرار العمليات
                _CommsHeader(state: state),
                const SizedBox(height: 20),

                // 2. المحتوى المقسوم على 3 لوحات
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // اللوحة 1: جهات اتصال الطوارئ والرادار
                      Expanded(
                        flex: 5,
                        child: _EmergencyRadarPanel(state: state),
                      ),
                      const SizedBox(width: 18),

                      // اللوحة 2: دليل جهات الاتصال الشامل
                      Expanded(
                        flex: 4,
                        child: _DirectoryPanel(state: state),
                      ),
                      const SizedBox(width: 18),

                      // اللوحة 3: رسائل الخزنة الواردة
                      Expanded(
                        flex: 3,
                        child: _UnreadMessagesPanel(state: state),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CommsHeader extends StatelessWidget {
  const _CommsHeader({required this.state});

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
                  'SAFETY RADAR & COMMUNICATIONS',
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
              'Emergency SOS contacts priority, phonebook synchronization, and encrypted message vault.',
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
        Row(
          children: [
            // حقل البحث
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
                  prefixIcon: Icon(Icons.search_rounded, size: 18, color: colors.onSurfaceVariant),
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

            // زر المزامنة التفاضلية لجهات الاتصال
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
              label: const Text('Sync Phonebook', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              onPressed: state.isSyncingContacts ? null : cubit.syncDeviceContacts,
            ),
            const SizedBox(width: 10),

            // زر إضافة جهة اتصال
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              icon: const Icon(Icons.person_add_rounded, size: 18),
              label: const Text('Add Contact', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name (e.g. John, Mom)')),
              const SizedBox(height: 10),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone Number')),
              const SizedBox(height: 10),
              TextField(controller: relationCtrl, decoration: const InputDecoration(labelText: 'Relationship (Optional)')),
              const SizedBox(height: 14),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Mark as Emergency SOS Contact', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                activeColor: colors.error,
                value: isEmergency,
                onChanged: (val) => setDialogState(() => isEmergency = val),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: colors.primary, foregroundColor: colors.surface),
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

class _EmergencyRadarPanel extends StatelessWidget {
  const _EmergencyRadarPanel({required this.state});

  final DesktopCommsState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cubit = context.read<DesktopCommsCubit>();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.error.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // شريط تنبيه الرادار
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.error.withValues(alpha: state.isBroadcastingSos ? 0.15 : 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.error.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: colors.error,
                  child: Icon(
                    state.isBroadcastingSos ? Icons.wifi_tethering_rounded : Icons.warning_amber_rounded,
                    color: colors.surface,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.isBroadcastingSos ? 'BROADCASTING TEST RADAR...' : 'EMERGENCY RADAR ACTIVE',
                        style: TextStyle(
                          color: colors.error,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Triple-tap on phone sounds alarm & streams GPS to contacts.',
                        style: TextStyle(color: colors.onSurface, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.error,
                    foregroundColor: colors.surface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  icon: const Icon(Icons.satellite_alt_rounded, size: 16),
                  label: const Text('Test SOS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  onPressed: state.isBroadcastingSos ? null : cubit.triggerTestSosBroadcast,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // قائمة جهات الطوارئ
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'EMERGENCY DISPATCH CONTACTS (${state.emergencyContacts.length})',
                style: TextStyle(
                  color: colors.error,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
              Text(
                'Receives live GPS alert',
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Expanded(
            child: state.emergencyContacts.isEmpty
                ? Center(
                    child: Text(
                      'No emergency contacts registered.\nPromote standard contacts to emergency priority.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    itemCount: state.emergencyContacts.length,
                    itemBuilder: (context, index) {
                      final contact = state.emergencyContacts[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: colors.error.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: colors.error.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: colors.error.withValues(alpha: 0.15),
                              child: Icon(Icons.shield_rounded, color: colors.error, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    contact.name,
                                    style: TextStyle(
                                      color: colors.onSurface,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    '${contact.relationship ?? 'Emergency Primary'} • ${contact.phoneNumber}',
                                    style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.phone_rounded, color: colors.primary, size: 18),
                              tooltip: 'Dial Number',
                              onPressed: () => launchUrl(Uri.parse('tel:${contact.phoneNumber}')),
                            ),
                            IconButton(
                              icon: Icon(Icons.star_rounded, color: colors.error, size: 20),
                              tooltip: 'Demote to regular contact',
                              onPressed: () => cubit.toggleEmergencyStatus(contact),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline_rounded, color: colors.error, size: 18),
                              onPressed: () => cubit.deleteContact(contact),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _DirectoryPanel extends StatelessWidget {
  const _DirectoryPanel({required this.state});

  final DesktopCommsState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cubit = context.read<DesktopCommsCubit>();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outline.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'STANDARD PHONEBOOK (${state.regularContacts.length})',
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
              Icon(Icons.contacts_rounded, size: 16, color: colors.onSurfaceVariant),
            ],
          ),
          const SizedBox(height: 12),

          Expanded(
            child: state.regularContacts.isEmpty
                ? Center(
                    child: Text(
                      'No standard contacts found.\nSync device contacts or add one above.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                    ),
                  )
                : ListView.builder(
                    itemCount: state.regularContacts.length,
                    itemBuilder: (context, index) {
                      final contact = state.regularContacts[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: context.scaffoldBg.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colors.outline.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: colors.surface,
                              child: Icon(Icons.person_rounded, size: 16, color: colors.onSurfaceVariant),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    contact.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: colors.onSurface, fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    contact.phoneNumber,
                                    style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.shield_outlined, color: colors.onSurfaceVariant, size: 18),
                              tooltip: 'Promote to Emergency Contact',
                              onPressed: () => cubit.toggleEmergencyStatus(contact),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline_rounded, color: colors.error, size: 16),
                              onPressed: () => cubit.deleteContact(contact),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _UnreadMessagesPanel extends StatelessWidget {
  const _UnreadMessagesPanel({required this.state});

  final DesktopCommsState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cubit = context.read<DesktopCommsCubit>();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outline.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'MESSAGES VAULT (${state.unreadMessages.length})',
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
              Icon(Icons.mark_chat_unread_rounded, size: 16, color: colors.primary),
            ],
          ),
          const SizedBox(height: 12),

          Expanded(
            child: state.unreadMessages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 32),
                        const SizedBox(height: 8),
                        Text(
                          'Quiet Vault\nZero unread messages.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: state.unreadMessages.length,
                    itemBuilder: (context, index) {
                      final msg = state.unreadMessages[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: context.scaffoldBg.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colors.outline.withValues(alpha: 0.4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  msg.senderName,
                                  style: TextStyle(color: colors.onSurface, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: colors.primary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    msg.platform.toUpperCase(),
                                    style: TextStyle(color: colors.primary, fontSize: 9, fontWeight: FontWeight.w900),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              msg.messageText,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
                            ),
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () => cubit.markMessageAsRead(msg),
                                child: Text(
                                  'Mark as Read',
                                  style: TextStyle(color: colors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}