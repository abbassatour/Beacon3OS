// lib/mobile/comms/view/comms_floor_0_view.dart
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/mobile/comms/cubit/comms_cubit.dart';
import 'package:beacon_os/mobile/comms/cubit/comms_state.dart';
import 'package:beacon_os/mobile/comms/widgets/add_contact_dialog.dart';
import 'package:beacon_os/mobile/shell/spatial_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';
import 'package:local_vault_api/local_vault_api.dart';

/// واجهة الطابق الأرضي للتواصل والرادار (Floor 0: Communications & Safety Radar)
class CommsFloor0View extends StatelessWidget {
  const CommsFloor0View({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final returnHint = CompassDirection.south.returnGestureHint;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: SafeArea(
        child: BlocBuilder<CommsCubit, CommsState>(
          builder: (context, state) {
            final cubit = context.read<CommsCubit>();

            if (state.status == CommsStatus.loading) {
              return Center(
                child: CircularProgressIndicator(color: colors.primary),
              );
            }

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 60, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'COMMUNICATIONS',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colors.onSurface,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton.filledTonal(
                                  style: IconButton.styleFrom(
                                    backgroundColor: colors.surface,
                                    foregroundColor: colors.onSurface,
                                    side: BorderSide(color: colors.outline),
                                    minimumSize: const Size(40, 40),
                                    padding: EdgeInsets.zero,
                                  ),
                                  icon: state.isSyncingContacts
                                      ? SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: colors.primary,
                                          ),
                                        )
                                      : const Icon(Icons.sync_rounded, size: 20),
                                  tooltip: 'Sync Device Contacts',
                                  onPressed: state.isSyncingContacts
                                      ? null
                                      : cubit.syncDeviceContacts,
                                ),
                                const SizedBox(width: 6),
                                IconButton.filledTonal(
                                  style: IconButton.styleFrom(
                                    backgroundColor: colors.surface,
                                    foregroundColor: colors.onSurface,
                                    side: BorderSide(color: colors.outline),
                                    minimumSize: const Size(40, 40),
                                    padding: EdgeInsets.zero,
                                  ),
                                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
                                  tooltip: 'Add Contact',
                                  onPressed: () => _showAddDialog(context, cubit),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$returnHint or double-tap to return to Cockpit.',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Semantics(
                      label: 'Emergency SOS Radar. Tap to trigger distress broadcast and call primary contact.',
                      button: true,
                      child: Material(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: cubit.triggerEmergencySos,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: colors.error, width: 2),
                              color: colors.error.withValues(alpha: state.isSosBroadcasting ? 0.15 : 0.04),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: colors.error,
                                  child: Icon(
                                    state.isSosBroadcasting
                                        ? Icons.wifi_tethering_rounded
                                        : Icons.warning_amber_rounded,
                                    color: colors.surface,
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        state.isSosBroadcasting
                                            ? 'BROADCASTING SOS RADAR...'
                                            : 'EMERGENCY RADAR & SOS',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: colors.error,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Tap to sound alarm, stream GPS & call emergency primary.',
                                        style: TextStyle(
                                          color: colors.onSurface,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(Icons.emergency_rounded, color: colors.error),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (state.emergencyContacts.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(Icons.shield_rounded, color: colors.error, size: 18),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'EMERGENCY CONTACTS (${state.emergencyContacts.length})',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: colors.error,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Swipe left to delete',
                            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildDismissibleEmergencyCard(
                          context,
                          state.emergencyContacts[index],
                          cubit,
                        ),
                        childCount: state.emergencyContacts.length,
                      ),
                    ),
                  ),
                ],
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Row(
                      children: [
                        Icon(Icons.mark_chat_unread_rounded, color: colors.primary, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'UNREAD MESSAGES (${state.recentMessages.length})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.onSurface,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (state.recentMessages.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: colors.outline),
                        ),
                        child: Text(
                          'No unread messages. Your messaging vault is completely quiet.',
                          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildMessageTile(
                          context,
                          state.recentMessages[index],
                          cubit,
                        ),
                        childCount: state.recentMessages.length,
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(Icons.contacts_rounded, color: colors.primary, size: 18),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'PHONE DIRECTORY (${state.regularContacts.length})',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: colors.onSurface,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Swipe left to delete',
                          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
                if (state.regularContacts.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: colors.outline),
                        ),
                        child: Text(
                          'No standard contacts saved. Tap + above to add one.',
                          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildDismissibleRegularCard(
                          context,
                          state.regularContacts[index],
                          cubit,
                        ),
                        childCount: state.regularContacts.length,
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 60)),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showAddDialog(BuildContext context, CommsCubit cubit) {
    showDialog<void>(
      context: context,
      builder: (_) => AddContactDialog(
        onSave: ({
          required name,
          required phoneNumber,
          relationship,
          required isEmergency,
        }) {
          cubit.addNewContact(
            name: name,
            phoneNumber: phoneNumber,
            relationship: relationship,
            isEmergency: isEmergency,
          );
        },
      ),
    );
  }

  Widget _buildDismissibleEmergencyCard(
    BuildContext context,
    Contact contact,
    CommsCubit cubit,
  ) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: Key(contact.id),
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
        onDismissed: (_) => cubit.deleteContact(contact),
        child: Semantics(
          label:
              'Emergency contact ${contact.name}, relationship ${contact.relationship ?? 'None'}. Tap to hear details, or tap phone icon to dial.',
          button: true,
          child: Material(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => cubit.readContactDetailsAloud(contact),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.error, width: 1.5),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: colors.error.withValues(alpha: 0.15),
                      child: Icon(
                        Icons.phone_in_talk_rounded,
                        color: colors.error,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            contact.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.onSurface,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '${contact.relationship ?? 'Emergency'} • ${contact.phoneNumber}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.volume_up_rounded,
                        color: colors.primary,
                        size: 20,
                      ),
                      onPressed: () => cubit.readContactDetailsAloud(contact),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.call_rounded,
                        color: colors.error,
                        size: 22,
                      ),
                      onPressed: () => cubit.callContact(contact),
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

  Widget _buildMessageTile(
    BuildContext context,
    MessagesVaultData msg,
    CommsCubit cubit,
  ) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        label:
            'Unread message from ${msg.senderName} on ${msg.platform}. Tap to listen and mark as read.',
        button: true,
        child: Material(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => cubit.readMessageAloud(msg),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.outline, width: 1.2),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: colors.primary.withValues(alpha: 0.12),
                    child: Icon(
                      msg.platform == 'whatsapp'
                          ? Icons.chat_rounded
                          : Icons.sms_rounded,
                      color: colors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                msg.senderName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colors.onSurface,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              msg.platform.toUpperCase(),
                              style: TextStyle(
                                color: colors.primary,
                                fontWeight: FontWeight.w900,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          msg.messageText,
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
                  const SizedBox(width: 8),
                  Icon(Icons.volume_up_rounded, color: colors.primary, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDismissibleRegularCard(
    BuildContext context,
    Contact contact,
    CommsCubit cubit,
  ) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: Key(contact.id),
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
        onDismissed: (_) => cubit.deleteContact(contact),
        child: Semantics(
          label:
              'Contact ${contact.name}, ${contact.relationship ?? ''}. Tap to hear details, or call icon to dial.',
          button: true,
          child: Material(
            color: colors.surface,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => cubit.readContactDetailsAloud(contact),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.outline, width: 1.2),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: context.scaffoldBg,
                      child: Icon(
                        Icons.person_rounded,
                        color: colors.onSurfaceVariant,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            contact.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.onSurface,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            contact.relationship != null
                                ? '${contact.relationship} • ${contact.phoneNumber}'
                                : contact.phoneNumber,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.call_rounded,
                        color: colors.primary,
                        size: 20,
                      ),
                      onPressed: () => cubit.callContact(contact),
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

/// Standalone Wrapper
class CommsFloor0StandaloneView extends StatelessWidget {
  const CommsFloor0StandaloneView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CommsCubit(
        commsRepository: context.read<CommsRepository>(),
        hardwareRepository: context.read<SystemHardwareRepository>(),
        assistantRepository: context.read<AssistantRepository>(),
      ),
      child: const CommsFloor0View(),
    );
  }
}
