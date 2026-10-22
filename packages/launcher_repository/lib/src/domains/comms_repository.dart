// packages/launcher_repository/lib/src/domains/comms_repository.dart
import 'dart:async';
import 'dart:developer';

import 'package:cloud_sync_api/cloud_sync_api.dart';
import 'package:drift/drift.dart';
import 'package:local_vault_api/local_vault_api.dart' as db;
import 'package:system_hardware_api/system_hardware_api.dart';

import '../mappers/comms_mapper.dart';
import '../models/contact_entity.dart';
import '../models/message_entity.dart';
import 'services/contacts_reconciliation_service.dart';
import 'vault_sync_coordinator.dart';

export '../models/contact_entity.dart';
export '../models/message_entity.dart';

/// العقد النطاقي المخصص لإدارة جهات الاتصال والرسائل
abstract class CommsRepository {
  // ===========================================================================
  // 📇 جهات الاتصال
  // ===========================================================================
  Stream<List<ContactEntity>> watchContacts();
  Future<List<ContactEntity>> getEmergencyContacts();
  Future<ContactEntity?> findContact(String query);
  
  Future<String> saveContact({
    required String name,
    required String phoneNumber,
    String? relationship,
    bool isEmergency = false,
  });
  
  Future<void> toggleEmergencyStatus(String contactId, {bool? isEmergency});
  Future<void> deleteContact(dynamic contactOrId);

  /// مزامنة جهات اتصال الهاتف وتسويتها داخل الخزنة المحلية عبر خوارزمية تفاضلية غير تدميرية
  Future<({
    int addedCount,
    int updatedCount,
    int deletedCount,
    bool permissionDenied,
  })> syncDeviceContactsToVault();

  // ===========================================================================
  // 💬 الرسائل (Messages Vault)
  // ===========================================================================
  Stream<List<MessageEntity>> watchMessages(String contactIdentifier);
  Future<List<MessageEntity>> getUnreadMessages();
  Future<void> markMessagesAsRead(String contactIdentifier);
  
  Future<String> recordMessage({
    required String contactIdentifier,
    required String senderName,
    required String messageText,
    String platform = 'sms',
    bool isOutgoing = false,
  });

  // ===========================================================================
  // 🔄 المزامنة (Sync)
  // ===========================================================================
  Future<void> restoreCommsFromCloud();
  Future<void> syncPendingComms();
  
  /// 🛰️ بدء الاستماع اللحظي للسحابة وتحديث الخزنة فوراً
  void initializeRealtimeSync();
  
  /// 🛑 إيقاف الاشتراكات اللحظية بأمان
  void dispose();
}

class CommsRepositoryImpl implements CommsRepository {
  CommsRepositoryImpl({
    required db.AppDatabase database,
    required CloudSyncClient cloudSync,
    required HardwareClient hardware,
    required VaultSyncCoordinator vaultSyncCoordinator,
    ContactsReconciliationService? reconciliationService,
  })  : _db = database,
        _cloud = cloudSync,
        _hardware = hardware,
        _vaultSync = vaultSyncCoordinator,
        _reconciliationService = reconciliationService ?? ContactsReconciliationService();

  final db.AppDatabase _db;
  final CloudSyncClient _cloud;
  final HardwareClient _hardware;
  final VaultSyncCoordinator _vaultSync;
  final ContactsReconciliationService _reconciliationService;

  StreamSubscription<dynamic>? _authSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _realtimeContactsSubscription;

  // ===========================================================================
  // 📇 جهات الاتصال
  // ===========================================================================

  @override
  Stream<List<ContactEntity>> watchContacts() {
    return _db.watchAllContacts().map(
          (list) => list.map((c) => c.toEntity()).toList(),
        );
  }

  @override
  Future<List<ContactEntity>> getEmergencyContacts() async {
    final list = await _db.getEmergencyContacts();
    return list.map((c) => c.toEntity()).toList();
  }

  @override
  Future<ContactEntity?> findContact(String query) async {
    final contact = await _db.findContactByNameOrRelation(query);
    return contact?.toEntity();
  }

  @override
  Future<String> saveContact({
    required String name,
    required String phoneNumber,
    String? relationship,
    bool isEmergency = false,
  }) async {
    final id = await _db.insertContact(
      name: name,
      phoneNumber: phoneNumber,
      relationship: relationship,
      isEmergency: isEmergency,
    );

    _hardware.saveDeviceContact(
      name: name,
      phoneNumber: phoneNumber,
    ).catchError((Object error) {
      log('CommsRepository: Device contact write skipped/failed: $error');
      return false;
    });

    _cloud.syncContact(
      id: id,
      name: name,
      phoneNumber: phoneNumber,
      relationship: relationship,
      isEmergency: isEmergency,
    ).catchError((Object error) {
      log('CommsRepository: Cloud contact sync deferred: $error');
    });

    _vaultSync.broadcastVaultMutation(
      table: 'contacts',
      action: 'INSERT',
      data: {
        'id': id,
        'name': name,
        'phone_number': phoneNumber,
        'relationship': relationship,
        'is_emergency': isEmergency,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
    );

    return id;
  }

  @override
  Future<void> toggleEmergencyStatus(String contactId, {bool? isEmergency}) async {
    final contacts = await _db.getAllContacts();
    final existing = contacts.where((c) => c.id == contactId).firstOrNull;
    if (existing == null) return;

    final nextStatus = isEmergency ?? !existing.isEmergency;
    final nowUtc = DateTime.now().toUtc();

    await (_db.update(_db.contacts)..where((tbl) => tbl.id.equals(contactId))).write(
      db.ContactsCompanion(
        isEmergency: Value(nextStatus),
        updatedAt: Value(nowUtc),
        isSynced: const Value(false),
      ),
    );

    _cloud.syncContact(
      id: existing.id,
      name: existing.name,
      phoneNumber: existing.phoneNumber,
      relationship: existing.relationship,
      isEmergency: nextStatus,
    ).catchError((Object err) {
      log('CommsRepository: Cloud emergency toggle deferred: $err');
    });

    _vaultSync.broadcastVaultMutation(
      table: 'contacts',
      action: 'UPDATE',
      data: {
        'id': existing.id,
        'name': existing.name,
        'phone_number': existing.phoneNumber,
        'relationship': existing.relationship,
        'is_emergency': nextStatus,
        'updated_at': nowUtc.toIso8601String(),
      },
    );
  }

  @override
  Future<void> deleteContact(dynamic contactOrId) async {
    final String id =
        contactOrId is ContactEntity ? contactOrId.id : contactOrId.toString();
    await _db.softDeleteContact(id);

    _cloud.softDeleteContactInCloud(id).catchError((Object error) {
      log('CommsRepository: Cloud contact delete deferred: $error');
    });

    _vaultSync.broadcastVaultMutation(
      table: 'contacts',
      action: 'DELETE',
      data: {
        'id': id,
        'deleted_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  @override
  Future<({int addedCount, int updatedCount, int deletedCount, bool permissionDenied})> syncDeviceContactsToVault() async {
    final hasPerm = await _hardware.hasContactsPermission();
    if (!hasPerm) {
      log('CommsRepository: Cannot sync contacts. Permission not granted.');
      return (addedCount: 0, updatedCount: 0, deletedCount: 0, permissionDenied: true);
    }

    final deviceRecords = await _hardware.getDeviceContacts();
    final result = await _reconciliationService.reconcile(
      deviceRecords: deviceRecords,
      database: _db,
    );

    if (result.addedCount > 0 || result.updatedCount > 0) {
      _vaultSync.broadcastVaultMutation(
        table: 'contacts',
        action: 'RECONCILE',
        data: {
          'added': result.addedCount,
          'updated': result.updatedCount,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
      );
    }

    syncPendingComms().catchError((Object err) {
      log('CommsRepository: Cloud sync deferred after diffing: $err');
    });

    return (
      addedCount: result.addedCount,
      updatedCount: result.updatedCount,
      deletedCount: result.deletedCount,
      permissionDenied: false,
    );
  }

  // ===========================================================================
  // 💬 الرسائل
  // ===========================================================================

  @override
  Stream<List<MessageEntity>> watchMessages(String contactIdentifier) {
    return _db.watchMessagesForContact(contactIdentifier).map(
          (list) => list.map((m) => m.toEntity()).toList(),
        );
  }

  @override
  Future<List<MessageEntity>> getUnreadMessages() async {
    final list = await _db.getUnreadMessages();
    return list.map((m) => m.toEntity()).toList();
  }

  @override
  Future<void> markMessagesAsRead(String contactIdentifier) async {
    await _db.markMessagesAsRead(contactIdentifier);
    _cloud.markMessagesAsReadInCloud(contactIdentifier).catchError((Object error) {
      log('CommsRepository: Cloud mark read deferred: $error');
    });
  }

  @override
  Future<String> recordMessage({
    required String contactIdentifier,
    required String senderName,
    required String messageText,
    String platform = 'sms',
    bool isOutgoing = false,
  }) async {
    final id = await _db.insertMessage(
      contactIdentifier: contactIdentifier,
      senderName: senderName,
      messageText: messageText,
      platform: platform,
      isOutgoing: isOutgoing,
    );

    _cloud.syncMessage(
      id: id,
      contactIdentifier: contactIdentifier,
      senderName: senderName,
      messageText: messageText,
      platform: platform,
      isOutgoing: isOutgoing,
    ).catchError((Object error) {
      log('CommsRepository: Cloud message sync deferred: $error');
    });

    return id;
  }

  // ===========================================================================
  // 🔄 المزامنة
  // ===========================================================================

  @override
  void initializeRealtimeSync() {
    _authSubscription?.cancel();
    _authSubscription = _cloud.authStateChanges?.listen((authState) {
      if (_cloud.isAuthenticated) {
        _subscribeToRealtimeContacts();
      } else {
        _realtimeContactsSubscription?.cancel();
        _realtimeContactsSubscription = null;
      }
    });

    if (_cloud.isAuthenticated) {
      _subscribeToRealtimeContacts();
    }
  }

  void _subscribeToRealtimeContacts() {
    _realtimeContactsSubscription?.cancel();
    try {
      final stream = _cloud.streamContacts();
      if (stream != null) {
        _realtimeContactsSubscription = stream.listen(
          _handleCloudRealtimeContacts,
          onError: (Object error) {
            log('CommsRepository: Realtime contacts stream error (offline handled): $error');
          },
          cancelOnError: false,
        );
        log('CommsRepository: 🛰️ Subscribed to Supabase Realtime contacts stream.');
      }
    } catch (e) {
      log('CommsRepository: Safe catch on streamContacts init: $e');
    }
  }

  Future<void> _handleCloudRealtimeContacts(List<Map<String, dynamic>> cloudContacts) async {
    try {
      if (cloudContacts.isEmpty) return;

      final localContacts = await (_db.select(_db.contacts)).get();
      final Map<String, db.Contact> localMap = {
        for (final c in localContacts) c.id: c,
      };

      await _db.batch((batch) {
        for (final cloudItem in cloudContacts) {
          final id = cloudItem['id'] as String?;
          if (id == null || id.isEmpty) continue;

          final cloudUpdated = cloudItem['updated_at'] != null
              ? DateTime.tryParse(cloudItem['updated_at'] as String)
              : null;
          final deletedAtStr = cloudItem['deleted_at'] as String?;
          final DateTime? deletedAt =
              deletedAtStr != null ? DateTime.tryParse(deletedAtStr) : null;

          final local = localMap[id];
          final shouldApply = local == null ||
              (cloudUpdated != null && cloudUpdated.isAfter(local.updatedAt)) ||
              (local.isSynced);

          if (!shouldApply) continue;

          if (deletedAt != null) {
            if (local != null) {
              batch.delete(_db.contacts, db.ContactsCompanion(id: Value(id)));
            }
          } else {
            final name = (cloudItem['name'] as String? ?? '').trim();
            final phone = (cloudItem['phone_number'] as String? ?? '').trim();
            if (name.isEmpty || phone.isEmpty) continue;

            final relationship = cloudItem['relationship'] as String?;
            final isEmergency = cloudItem['is_emergency'] as bool? ?? false;

            batch.insert(
              _db.contacts,
              db.ContactsCompanion.insert(
                id: id,
                name: name,
                phoneNumber: phone,
                relationship: Value(relationship),
                isEmergency: Value(isEmergency),
                updatedAt: Value(cloudUpdated ?? DateTime.now().toUtc()),
                isSynced: const Value(true),
              ),
              mode: InsertMode.insertOrReplace,
            );
          }
        }
      });
      log('CommsRepository: ⚡ Reconciled ${cloudContacts.length} realtime cloud contacts with LWW.');
    } catch (e, st) {
      log('CommsRepository: Error reconciling realtime contacts: $e', stackTrace: st);
    }
  }

  @override
  Future<void> restoreCommsFromCloud() async {
    if (!_cloud.isAuthenticated) return;
    try {
      final cloudContacts = await _cloud.fetchContactsDelta();
      if (cloudContacts.isEmpty) return;

      final localContacts = await _db.getAllContacts();
      final localMap = {for (final c in localContacts) c.id: c};

      await _db.batch((batch) {
        for (final c in cloudContacts) {
          final id = c['id'] as String?;
          if (id == null) continue;

          final deletedAtStr = c['deleted_at'] as String?;
          final DateTime? deletedAt =
              deletedAtStr != null ? DateTime.tryParse(deletedAtStr) : null;
          final updatedStr = c['updated_at'] as String?;
          final DateTime? updatedAt =
              updatedStr != null ? DateTime.tryParse(updatedStr) : null;

          final local = localMap[id];

          if (deletedAt != null) {
            if (local != null) {
              batch.delete(_db.contacts, db.ContactsCompanion(id: Value(id)));
            }
          } else {
            final shouldApply = local == null ||
                (updatedAt != null && updatedAt.isAfter(local.updatedAt)) ||
                (local.isSynced);

            if (shouldApply) {
              batch.insert(
                _db.contacts,
                db.ContactsCompanion.insert(
                  id: id,
                  name: c['name'] as String,
                  phoneNumber: c['phone_number'] as String,
                  relationship: Value(c['relationship'] as String?),
                  isEmergency: Value(c['is_emergency'] as bool? ?? false),
                  updatedAt: Value(updatedAt ?? DateTime.now().toUtc()),
                  isSynced: const Value(true),
                ),
                mode: InsertMode.insertOrReplace,
              );
            }
          }
        }
      });
      log('CommsRepository: ⚡ Restored and reconciled ${cloudContacts.length} contacts from cloud in batch.');
    } catch (e, st) {
      log('CommsRepository: Contacts cloud restore error: $e', stackTrace: st);
    }
  }

  @override
  Future<void> syncPendingComms() async {
    if (!_cloud.isAuthenticated) return;
    try {
      final pending = await (_db.select(_db.contacts)
            ..where((c) => c.isSynced.equals(false)))
          .get();
      if (pending.isEmpty) return;

      final toDelete = pending.where((c) => c.deletedAt != null).toList();
      final toUpsert = pending.where((c) => c.deletedAt == null).toList();

      if (toDelete.isNotEmpty) {
        final deleteIds = toDelete.map((c) => c.id).toList();
        await _cloud.softDeleteContactsBatchInCloud(deleteIds);
        await (_db.delete(_db.contacts)..where((tbl) => tbl.id.isIn(deleteIds))).go();
      }

      if (toUpsert.isNotEmpty) {
        final upsertPayload = toUpsert.map((c) => {
              'id': c.id,
              'name': c.name,
              'phone_number': c.phoneNumber,
              'relationship': c.relationship,
              'is_emergency': c.isEmergency,
              'updated_at': c.updatedAt.toUtc().toIso8601String(),
            }).toList();

        await _cloud.syncContactsBatch(upsertPayload);

        final upsertIds = toUpsert.map((c) => c.id).toList();
        await (_db.update(_db.contacts)
              ..where((tbl) => tbl.id.isIn(upsertIds)))
            .write(const db.ContactsCompanion(isSynced: Value(true)));
      }
    } catch (e, st) {
      log('CommsRepository: Pending batch sync error: $e', stackTrace: st);
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _realtimeContactsSubscription?.cancel();
  }
}

extension on db.AppDatabase {
  Future<List<db.Contact>> getAllContacts() {
    return (select(contacts)..where((c) => c.deletedAt.isNull())).get();
  }
}