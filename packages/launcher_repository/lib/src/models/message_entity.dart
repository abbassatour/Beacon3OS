// packages/launcher_repository/lib/src/models/message_entity.dart
import 'package:equatable/equatable.dart';

class MessageEntity extends Equatable {
  const MessageEntity({
    required this.id,
    required this.contactIdentifier,
    required this.senderName,
    required this.messageText,
    this.platform = 'sms',
    this.isOutgoing = false,
    required this.timestamp,
    this.isRead = false,
  });

  final String id;
  final String contactIdentifier;
  final String senderName;
  final String messageText;
  final String platform;
  final bool isOutgoing;
  final DateTime timestamp;
  final bool isRead;

  @override
  List<Object?> get props => [
        id,
        contactIdentifier,
        senderName,
        messageText,
        platform,
        isOutgoing,
        timestamp,
        isRead,
      ];
}