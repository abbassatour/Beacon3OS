// lib/mobile/comms/cubit/comms_state.dart
import 'package:equatable/equatable.dart';
import 'package:launcher_repository/launcher_repository.dart';

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
  final List<ContactEntity> contacts;
  final List<MessageEntity> recentMessages;
  final bool isSosBroadcasting;
  final bool isSyncingContacts;
  final String? errorMessage;

  /// جهات اتصال الطوارئ مرتبة أبجدياً
  List<ContactEntity> get emergencyContacts {
    final list = contacts.where((c) => c.isEmergency).toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  /// جهات الاتصال العادية مرتبة أبجدياً
  List<ContactEntity> get regularContacts {
    final list = contacts.where((c) => !c.isEmergency).toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  CommsState copyWith({
    CommsStatus? status,
    List<ContactEntity>? contacts,
    List<MessageEntity>? recentMessages,
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