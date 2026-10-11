// lib/comms/cubit/comms_state.dart
import 'package:equatable/equatable.dart';
import 'package:local_vault_api/local_vault_api.dart';

enum CommsStatus { initial, loading, success, error }

class CommsState extends Equatable {
  const CommsState({
    this.status = CommsStatus.initial,
    this.contacts = const [],
    this.recentMessages = const [],
    this.isSosBroadcasting = false,
    this.isSyncingContacts = false,
    this.errorMessage,
  });

  final CommsStatus status;
  final List<Contact> contacts;
  final List<MessagesVaultData> recentMessages;
  final bool isSosBroadcasting;
  final bool isSyncingContacts;
  final String? errorMessage;

  /// جهات اتصال الطوارئ مرتبة أبجدياً
  List<Contact> get emergencyContacts {
    final list = contacts.where((c) => c.isEmergency).toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  /// جهات الاتصال العادية مرتبة أبجدياً
  List<Contact> get regularContacts {
    final list = contacts.where((c) => !c.isEmergency).toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  CommsState copyWith({
    CommsStatus? status,
    List<Contact>? contacts,
    List<MessagesVaultData>? recentMessages,
    bool? isSosBroadcasting,
    bool? isSyncingContacts,
    String? errorMessage,
  }) {
    return CommsState(
      status: status ?? this.status,
      contacts: contacts ?? this.contacts,
      recentMessages: recentMessages ?? this.recentMessages,
      isSosBroadcasting: isSosBroadcasting ?? this.isSosBroadcasting,
      isSyncingContacts: isSyncingContacts ?? this.isSyncingContacts,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        contacts,
        recentMessages,
        isSosBroadcasting,
        isSyncingContacts,
        errorMessage,
      ];
}

// 🛡️ أسماء توافقية لمنع انكسار الكود القديم
typedef CommunicationsState = CommsState;
typedef CommunicationsStatus = CommsStatus;