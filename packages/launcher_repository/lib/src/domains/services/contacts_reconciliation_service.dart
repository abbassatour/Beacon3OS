// packages/launcher_repository/lib/src/domains/services/contacts_reconciliation_service.dart
import 'dart:developer';
import 'dart:math' as math;

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
    this.totalProcessed = 0,
  });

  final int addedCount;
  final int updatedCount;
  final int deletedCount;
  final int totalProcessed;
}

/// خدمة تفاضلية ذكية لمطابقة جهات اتصال الهاتف وتسويتها داخل الخزنة المحلية
/// دون مسح جهات الاتصال اليدوية أو السحابية (Non-Destructive Smart Reconciliation).
class ContactsReconciliationService {
  ContactsReconciliationService({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  Future<ContactsReconciliationResult> reconcile({
    required List<DeviceContactRecord> deviceRecords,
    required AppDatabase database,
  }) async {
    if (deviceRecords.isEmpty) {
      log('ContactsReconciliationService: No device records provided for reconciliation.');
      return const ContactsReconciliationResult(
        addedCount: 0,
        updatedCount: 0,
        deletedCount: 0,
      );
    }

    try {
      // 1. جلب كافة جهات الاتصال النشطة في الخزنة
      final existingContacts = await (database.select(database.contacts)
            ..where((c) => c.deletedAt.isNull()))
          .get();

      // بناء خريطة فهرسة للأرقام والأسماء
      final Map<String, Contact> phoneIndex = {};
      final Map<String, Contact> nameIndex = {};

      for (final c in existingContacts) {
        final digits = cleanDigits(c.phoneNumber);
        if (digits.isNotEmpty) {
          phoneIndex[digits] = c;
          if (digits.length >= 7) {
            phoneIndex[digits.substring(digits.length - 7)] = c;
          }
        }
        nameIndex[c.name.trim().toLowerCase()] = c;
      }

      var addedCount = 0;
      var updatedCount = 0;
      final Set<String> matchedExistingIds = {};
      final Set<String> processedNumbersInRun = {};

      await database.batch((batch) {
        for (final record in deviceRecords) {
          final cleanPrimaryPhone = sanitizeNumber(record.phoneNumber);
          final primaryDigits = cleanDigits(cleanPrimaryPhone);

          if (primaryDigits.length < 3) continue;

          // تجنب تكرار نفس الرقم في نفس جلسة المزامنة
          if (processedNumbersInRun.contains(primaryDigits)) continue;
          processedNumbersInRun.add(primaryDigits);

          // 2. البحث عن جهة اتصال مطابقة بالرقم الأساسي أو الأرقام البديلة أو الاسم
          Contact? matched;

          // فحص الرقم الأساسي والأرقام البديلة التابعة لنفس الشخص
          final candidateNumbers = [
            cleanPrimaryPhone,
            ...record.allPhoneNumbers.map(sanitizeNumber),
          ];

          for (final phone in candidateNumbers) {
            final digits = cleanDigits(phone);
            if (phoneIndex.containsKey(digits)) {
              matched = phoneIndex[digits];
              break;
            }
            if (digits.length >= 7) {
              final suffix7 = digits.substring(digits.length - 7);
              if (phoneIndex.containsKey(suffix7)) {
                matched = phoneIndex[suffix7];
                break;
              }
            }
          }

          // إذا لم نجد تطابقاً بالرقم، نفحص تطابق الاسم بدقة
          matched ??= nameIndex[record.name.trim().toLowerCase()];

          // 3. اتخاذ القرار (تحديث السجل الحالي أم إضافة جديد)
          if (matched != null) {
            matchedExistingIds.add(matched.id);

            final nameChanged = matched.name.trim() != record.name.trim();
            final phoneChanged = !numbersMatch(matched.phoneNumber, cleanPrimaryPhone);

            // تحديث جهة الاتصال إن تغير اسمها أو رقمها في دفتر الهاتف
            if (nameChanged || phoneChanged) {
              batch.update(
                database.contacts,
                ContactsCompanion(
                  name: Value(record.name.trim()),
                  phoneNumber: Value(cleanPrimaryPhone),
                  updatedAt: Value(DateTime.now()),
                  isSynced: const Value(false),
                ),
                where: (tbl) => tbl.id.equals(matched!.id),
              );
              updatedCount++;
            }
          } else {
            // إضافة جهة اتصال جديدة لم تكن موجودة في الخزنة
            final newId = _uuid.v4();
            batch.insert(
              database.contacts,
              ContactsCompanion.insert(
                id: newId,
                name: record.name.trim(),
                phoneNumber: cleanPrimaryPhone,
                isEmergency: const Value(false),
                isSynced: const Value(false),
              ),
            );
            addedCount++;

            // تحديث الفهرس اللحظي لمنع التكرار في نفس الدورة
            phoneIndex[primaryDigits] = Contact(
              id: newId,
              name: record.name.trim(),
              phoneNumber: cleanPrimaryPhone,
              isEmergency: false,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              isSynced: false,
            );
          }
        }

        // 🛡️ ملاحظة معمارية حاسمة:
        // تم إلغاء حلقة الحذف التلقائي التي كانت تمسح جهات اتصال الخزنة غير الموجودة بالهاتف!
        // جهات اتصال الخزنة (المدخلة يدوياً أو المسترجعة من السحابة/الكمبيوتر) تظل محفوظة دائماً.
      });

      log('ContactsReconciliationService: Reconciled. Added: $addedCount, Updated: $updatedCount, Preserved Existing: ${existingContacts.length}');

      return ContactsReconciliationResult(
        addedCount: addedCount,
        updatedCount: updatedCount,
        deletedCount: 0,
        totalProcessed: deviceRecords.length,
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

  /// تطهير الرموز والفواصل غير الرقمية
  static String sanitizeNumber(String phone) {
    return phone.replaceAll(RegExp(r'[\s\(\)\-\.]'), '').trim();
  }

  /// استخراج الأرقام فقط (Digits Only)
  static String cleanDigits(String phone) {
    return phone.replaceAll(RegExp(r'\D'), '');
  }

  /// مطابقة ذكية بين رقمين تتجاوز بادئات الدول وصيغ الاتصال المحلية
  static bool numbersMatch(String a, String b) {
    final da = cleanDigits(a);
    final db = cleanDigits(b);
    if (da == db) return true;
    if (da.isEmpty || db.isEmpty) return false;

    // إذا كان كلاهما يحتوي 7 أرقام فأكثر، نقارن آخر 7 إلى 9 أرقام
    if (da.length >= 7 && db.length >= 7) {
      final minLen = math.min(math.min(da.length, db.length), 9);
      for (var len = minLen; len >= 7; len--) {
        final subA = da.substring(da.length - len);
        final subB = db.substring(db.length - len);
        if (subA == subB) return true;
      }
    }
    return false;
  }
}