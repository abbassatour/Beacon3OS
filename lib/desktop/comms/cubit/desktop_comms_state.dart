// lib/desktop/cubit/desktop_comms_state.dart
import 'package:equatable/equatable.dart';
import 'package:local_vault_api/local_vault_api.dart';

enum DesktopCommsStatus { initial, loading, success, error }

class DesktopCommsState extends Equatable {
  const DesktopCommsState({
    this.status = DesktopCommsStatus.initial,
    this.contacts = const [],
    this.unreadMessages = const [],
    this.searchQuery = '',
    this.isBroadcastingSos = false,
    this.isSyncingContacts = false,
    this.lastSosAlertId,
    this.errorMessage,
  });

  final DesktopCommsStatus status;
  final List<Contact> contacts;
  final List<MessagesVaultData> unreadMessages;
  final String searchQuery;
  final bool isBroadcastingSos;
  final bool isSyncingContacts;
  final String? lastSosAlertId;
  final String? errorMessage;

  /// Ø¬Ù‡Ø§Øª Ø§ØªØµØ§Ù„ Ø§Ù„Ø·ÙˆØ§Ø±Ø¦ Ù…ÙÙ„ØªØ±Ø© ÙˆÙ…Ø±ØªØ¨Ø© Ø£Ø¨Ø¬Ø¯ÙŠØ§Ù‹
  List<Contact> get emergencyContacts {
    final list = contacts.where((c) => c.isEmergency).toList();
    return _filterAndSort(list);
  }

  /// Ø¬Ù‡Ø§Øª Ø§Ù„Ø§ØªØµØ§Ù„ Ø§Ù„Ø¹Ø§Ø¯ÙŠØ© Ù…ÙÙ„ØªØ±Ø© ÙˆÙ…Ø±ØªØ¨Ø© Ø£Ø¨Ø¬Ø¯ÙŠØ§Ù‹
  List<Contact> get regularContacts {
    final list = contacts.where((c) => !c.isEmergency).toList();
    return _filterAndSort(list);
  }

  List<Contact> _filterAndSort(List<Contact> list) {
    return list.where((c) {
      if (searchQuery.isEmpty) return true;
      final q = searchQuery.toLowerCase();
      final matchName = c.name.toLowerCase().contains(q);
      final matchPhone = c.phoneNumber.contains(q);
      final matchRel = c.relationship?.toLowerCase().contains(q) ?? false;
      return matchName || matchPhone || matchRel;
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  DesktopCommsState copyWith({
    DesktopCommsStatus? status,
    List<Contact>? contacts,
    List<MessagesVaultData>? unreadMessages,
    String? searchQuery,
    bool? isBroadcastingSos,
    bool? isSyncingContacts,
    String? lastSosAlertId,
    String? errorMessage,
  }) {
    return DesktopCommsState(
      status: status ?? this.status,
      contacts: contacts ?? this.contacts,
      unreadMessages: unreadMessages ?? this.unreadMessages,
      searchQuery: searchQuery ?? this.searchQuery,
      isBroadcastingSos: isBroadcastingSos ?? this.isBroadcastingSos,
      isSyncingContacts: isSyncingContacts ?? this.isSyncingContacts,
      lastSosAlertId: lastSosAlertId ?? this.lastSosAlertId,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        contacts,
        unreadMessages,
        searchQuery,
        isBroadcastingSos,
        isSyncingContacts,
        lastSosAlertId,
        errorMessage,
      ];
}
