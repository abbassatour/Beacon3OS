// packages/local_vault_api/lib/src/tables/device_pairing_meta_table.dart
import 'package:drift/drift.dart';

/// جدول بيانات اقتران الأجهزة وغرفة المعيشة (Device Pairing & Linked Vault DID)
class DevicePairingMeta extends Table {
  TextColumn get key => text()();
  TextColumn get val => text()();

  @override
  Set<Column> get primaryKey => {key};
}