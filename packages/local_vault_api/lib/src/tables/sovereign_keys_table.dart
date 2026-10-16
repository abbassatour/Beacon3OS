// packages/local_vault_api/lib/src/tables/sovereign_keys_table.dart
import 'package:drift/drift.dart';

/// جدول تخزين مفاتيح الهوية السيادية المشفرة (DID Private Keys)
class SovereignKeys extends Table {
  TextColumn get id => text()();
  TextColumn get keyHex => text()();

  @override
  Set<Column> get primaryKey => {id};
}