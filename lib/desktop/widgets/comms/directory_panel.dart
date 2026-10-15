import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/desktop/cubit/desktop_comms_cubit.dart';
import 'package:beacon_os/desktop/cubit/desktop_comms_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class DirectoryPanel extends StatelessWidget {
  const DirectoryPanel({required this.state, super.key});

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
                              child: Icon(
                                Icons.person_rounded,
                                size: 16,
                                color: colors.onSurfaceVariant,
                              ),
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
                                    style: TextStyle(
                                      color: colors.onSurface,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    contact.phoneNumber,
                                    style: TextStyle(
                                      color: colors.onSurfaceVariant,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.shield_outlined,
                                color: colors.onSurfaceVariant,
                                size: 18,
                              ),
                              tooltip: 'Promote to Emergency Contact',
                              onPressed: () => cubit.toggleEmergencyStatus(contact),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.delete_outline_rounded,
                                color: colors.error,
                                size: 16,
                              ),
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