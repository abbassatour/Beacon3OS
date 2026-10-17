// packages/launcher_repository/lib/src/mappers/comms_mapper.dart
import 'package:local_vault_api/local_vault_api.dart' as db;
import '../models/contact_entity.dart';
import '../models/message_entity.dart';

extension ContactDataToEntity on db.Contact {
  ContactEntity toEntity() {
    return ContactEntity(
      id: id,
      name: name,
      phoneNumber: phoneNumber,
      relationship: relationship,
      isEmergency: isEmergency,
    );
  }
}

extension MessagesVaultDataToEntity on db.MessagesVaultData {
  MessageEntity toEntity() {
    return MessageEntity(
      id: id,
      contactIdentifier: contactIdentifier,
      senderName: senderName,
      messageText: messageText,
      platform: platform,
      isOutgoing: isOutgoing,
      timestamp: timestamp,
      isRead: isRead,
    );
  }
}