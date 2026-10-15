// packages/local_vault_api/lib/src/daos/contacts_dao.dart
import 'package:drift/drift.dart';
import 'package:local_vault_api/src/app_database.dart';
import 'package:uuid/uuid.dart';

class ContactsDao extends DatabaseAccessor<AppDatabase> {
  ContactsDao(super.db);

  final _uuid = const Uuid();

  // --- Contacts ---
  Stream<List<Contact>> watchAllContacts() =>
      (select(attachedDatabase.contacts)
            ..where((c) => c.deletedAt.isNull())
            ..orderBy([(c) => OrderingTerm.asc(c.name)]))
          .watch();

  Future<List<Contact>> getEmergencyContacts() =>
      (select(attachedDatabase.contacts)
            ..where((c) => c.deletedAt.isNull() & c.isEmergency.equals(true)))
          .get();

  Future<Contact?> findContactByNameOrRelation(String query) {
    final clean = query.trim().toLowerCase();
    return (select(attachedDatabase.contacts)
          ..where((c) =>
              c.deletedAt.isNull() &
              (c.name.lower().equals(clean) |
                  c.relationship.lower().equals(clean) |
                  c.name.lower().like('%$clean%') |
                  c.relationship.lower().like('%$clean%')))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<String> insertContact({
    required String name,
    required String phoneNumber,
    String? relationship,
    bool isEmergency = false,
    String? id,
  }) async {
    final contactId = id ?? _uuid.v4();
    await into(attachedDatabase.contacts).insert(
      ContactsCompanion.insert(
        id: contactId,
        name: name,
        phoneNumber: phoneNumber,
        relationship: Value(relationship),
        isEmergency: Value(isEmergency),
      ),
    );
    return contactId;
  }

  Future<void> softDeleteContact(String contactId) {
    return (update(attachedDatabase.contacts)
          ..where((c) => c.id.equals(contactId)))
        .write(
      ContactsCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
        isSynced: const Value(false),
      ),
    );
  }

  Future<int> deleteContact(String id) =>
      (delete(attachedDatabase.contacts)..where((c) => c.id.equals(id))).go();

  // --- Messages Vault ---
  Stream<List<MessagesVaultData>> watchMessagesForContact(
    String contactIdentifier,
  ) {
    return (select(attachedDatabase.messagesVault)
          ..where((m) =>
              m.deletedAt.isNull() &
              m.contactIdentifier.equals(contactIdentifier))
          ..orderBy([(m) => OrderingTerm.asc(m.timestamp)]))
        .watch();
  }

  Future<List<MessagesVaultData>> getRecentMessages({int limit = 50}) =>
      (select(attachedDatabase.messagesVault)
            ..where((m) => m.deletedAt.isNull())
            ..orderBy([(m) => OrderingTerm.desc(m.timestamp)])
            ..limit(limit))
          .get();

  Future<List<MessagesVaultData>> getUnreadMessages() =>
      (select(attachedDatabase.messagesVault)
            ..where((m) => m.deletedAt.isNull() & m.isRead.equals(false)))
          .get();

  Future<String> insertMessage({
    required String contactIdentifier,
    required String senderName,
    required String messageText,
    String platform = 'sms',
    bool isOutgoing = false,
  }) async {
    final msgId = _uuid.v4();
    await into(attachedDatabase.messagesVault).insert(
      MessagesVaultCompanion.insert(
        id: msgId,
        contactIdentifier: contactIdentifier,
        senderName: senderName,
        messageText: messageText,
        platform: Value(platform),
        isOutgoing: Value(isOutgoing),
      ),
    );
    return msgId;
  }

  Future<void> markMessagesAsRead(String contactIdentifier) {
    return (update(attachedDatabase.messagesVault)
          ..where((m) => m.contactIdentifier.equals(contactIdentifier)))
        .write(
      const MessagesVaultCompanion(
        isRead: Value(true),
        isSynced: Value(false),
      ),
    );
  }

  // --- Notifications Digest ---
  Future<List<NotificationsDigestData>> getUnreadNotifications() =>
      (select(attachedDatabase.notificationsDigest)
            ..where((t) => t.isRead.equals(false)))
          .get();

  Future<int> insertNotification(NotificationsDigestCompanion notif) =>
      into(attachedDatabase.notificationsDigest).insert(notif);

  Future<void> markAllNotificationsAsRead() =>
      (update(attachedDatabase.notificationsDigest)
            ..where((t) => t.isRead.equals(false)))
          .write(
        const NotificationsDigestCompanion(isRead: Value(true)),
      );
}