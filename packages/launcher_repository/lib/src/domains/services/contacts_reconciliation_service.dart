// packages/launcher_repository/lib/src/domains/services/contacts_reconciliation_service.dart
import 'dart:developer';

import 'package:drift/drift.dart';
import 'package:local_vault_api/local_vault_api.dart';
import 'package:system_hardware_api/system_hardware_api.dart';
import 'package:uuid/uuid.dart';

/// نتيجة عملية تسوية جهات الاتصال التفاضلية
class ContactsReconciliationResult {
  const ContactsReconciliationResult({
    required this.addedCount,
    required this.updatedCount,
    required this.deletedCount,
  });

  final int addedCount;
  final int updatedCount;
  final int deletedCount;
}

/// خدمة تفاضلية ذكية لمطابقة جهات اتصال الهاتف وتسويتها داخل الخزنة المحلية
class ContactsReconciliationService {
  ContactsReconciliationService({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  Future<ContactsReconciliationResult> reconcile({
    required List<DeviceContactRecord> deviceRecords,
    required AppDatabase database,
  }) async {
    if (deviceRecords.isEmpty) {
      log('ContactsReconciliationService: No records provided.');
      return const ContactsReconciliationResult(
        addedCount: 0,
        updatedCount: 0,
        deletedCount: 0,
      );
    }

    try {
      final existingContacts = await (database.select(database.contacts)
            ..where((c) => c.deletedAt.isNull()))
          .get();

      final Map<String, Contact> map9 = {};
      final Map<String, Contact> map8 = {};

      for (final c in existingContacts) {
        final digits = c.phoneNumber.replaceAll(RegExp(r'\D'), '');
        if (digits.isEmpty) continue;

        if (digits.length >= 9) {
          map9[digits.substring(digits.length - 9)] = c;
        } else {
          map9[digits] = c;
        }

        if (digits.length >= 8) {
          map8[digits.substring(digits.length - 8)] = c;
        }
      }

      var addedCount = 0;
      var updatedCount = 0;
      var deletedCount = 0;

      final Set<String> matchedExistingIds = {};
      final Set<String> processedDeviceKeys = {};

      await database.batch((batch) {
        for (final record in deviceRecords) {
          final cleanPhone = sanitizeNumber(record.phoneNumber);
          final digits = cleanPhone.replaceAll(RegExp(r'\D'), '');
          if (digits.length < 3) continue;

          final key9 = digits.length >= 9
              ? digits.substring(digits.length - 9)
              : digits;
          final key8 = digits.length >= 8
              ? digits.substring(digits.length - 8)
              : null;

          if (processedDeviceKeys.contains(key9)) continue;
          processedDeviceKeys.add(key9);

          final existing = map9[key9] ?? (key8 != null ? map8[key8] : null);

          if (existing != null) {
            matchedExistingIds.add(existing.id);

            final nameChanged = existing.name != record.name;
            final phoneChanged = existing.phoneNumber != cleanPhone;

            if (nameChanged || phoneChanged) {
              batch.update(
                database.contacts,
                ContactsCompanion(
                  name: Value(record.name),
                  phoneNumber: Value(cleanPhone),
                  updatedAt: Value(DateTime.now()),
                  isSynced: const Value(false),
                ),
                where: (tbl) => tbl.id.equals(existing.id),
              );
              updatedCount++;
            }
          } else {
            final newId = _uuid.v4();
            batch.insert(
              database.contacts,
              ContactsCompanion.insert(
                id: newId,
                name: record.name,
                phoneNumber: cleanPhone,
                isEmergency: const Value(false),
                isSynced: const Value(false),
              ),
            );
            addedCount++;
          }
        }

        for (final existing in existingContacts) {
          if (!matchedExistingIds.contains(existing.id)) {
            if (existing.isEmergency) continue;

            batch.update(
              database.contacts,
              ContactsCompanion(
                deletedAt: Value(DateTime.now()),
                updatedAt: Value(DateTime.now()),
                isSynced: const Value(false),
              ),
              where: (tbl) => tbl.id.equals(existing.id),
            );
            deletedCount++;
          }
        }
      });

      return ContactsReconciliationResult(
        addedCount: addedCount,
        updatedCount: updatedCount,
        deletedCount: deletedCount,
      );
    } catch (e, st) {
      log('ContactsReconciliationService: Error reconciling contacts: $e',
          stackTrace: st);
      return const ContactsReconciliationResult(
        addedCount: 0,
        updatedCount: 0,
        deletedCount: 0,
      );
    }
  }

  static String sanitizeNumber(String phone) {
    return phone.replaceAll(RegExp(r'[\s\(\)\-\.]'), '').trim();
  }
}