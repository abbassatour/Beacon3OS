// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ring_dao.dart';

// ignore_for_file: type=lint
mixin _$RingDaoMixin on DatabaseAccessor<AppDatabase> {
  $RingDevicesTable get ringDevices => attachedDatabase.ringDevices;
  $RingEventsTable get ringEvents => attachedDatabase.ringEvents;
  RingDaoManager get managers => RingDaoManager(this);
}

class RingDaoManager {
  final _$RingDaoMixin _db;
  RingDaoManager(this._db);
  $$RingDevicesTableTableManager get ringDevices =>
      $$RingDevicesTableTableManager(_db.attachedDatabase, _db.ringDevices);
  $$RingEventsTableTableManager get ringEvents =>
      $$RingEventsTableTableManager(_db.attachedDatabase, _db.ringEvents);
}
