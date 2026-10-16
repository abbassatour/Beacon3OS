// packages/local_vault_api/lib/src/tables/ring_devices_table.dart
import 'package:drift/drift.dart';

@DataClassName('RingDeviceEntry')
class RingDevices extends Table {
  TextColumn get id => text()();
  TextColumn get label => text()();
  TextColumn get deviceType => text()(); // doorbell, stickUpCam, indoorCam, floodlightCam
  TextColumn get location => text()();   // frontDoor, backyard, nursery, garage, custom
  IntColumn get spatialX => integer().withDefault(const Constant(0))();
  IntColumn get spatialY => integer().withDefault(const Constant(2))();
  IntColumn get spatialFloor => integer().withDefault(const Constant(0))();
  IntColumn get batteryLevel => integer().withDefault(const Constant(100))();
  BoolColumn get isOnline => boolean().withDefault(const Constant(true))();
  BoolColumn get isMotionEnabled => boolean().withDefault(const Constant(true))();
  DateTimeColumn get lastDingAt => dateTime().nullable()();
  DateTimeColumn get lastMotionAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}