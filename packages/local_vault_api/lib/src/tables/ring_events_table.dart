// packages/local_vault_api/lib/src/tables/ring_events_table.dart
import 'package:drift/drift.dart';

@DataClassName('RingEventEntry')
class RingEvents extends Table {
  TextColumn get id => text()();
  TextColumn get deviceId => text()();
  TextColumn get deviceLabel => text()();
  TextColumn get eventType => text()(); // ding, motion, offline
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
  TextColumn get snapshotPath => text().nullable()();
  TextColumn get aiSceneDescription => text().nullable()();
  BoolColumn get isRead => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}