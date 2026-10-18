// packages/local_vault_api/lib/src/daos/ring_dao.dart
import 'package:drift/drift.dart';
import 'package:local_vault_api/src/app_database.dart';
import 'package:local_vault_api/src/tables/ring_devices_table.dart';
import 'package:local_vault_api/src/tables/ring_events_table.dart';

part 'ring_dao.g.dart';

@DriftAccessor(tables: [RingDevices, RingEvents])
class RingDao extends DatabaseAccessor<AppDatabase> with _$RingDaoMixin {
  RingDao(super.db);

  // --- Devices ---
  Stream<List<RingDeviceEntry>> watchAllDevices() =>
      (select(ringDevices)
            ..where((d) => d.deletedAt.isNull())
            ..orderBy([(d) => OrderingTerm.asc(d.label)]))
          .watch();

  Future<List<RingDeviceEntry>> getAllDevices() =>
      (select(ringDevices)
            ..where((d) => d.deletedAt.isNull()))
          .get();

  Future<RingDeviceEntry?> getDeviceById(String id) =>
      (select(ringDevices)
            ..where((d) => d.id.equals(id) & d.deletedAt.isNull()))
          .getSingleOrNull();

  Future<void> upsertDevice(RingDevicesCompanion device) {
    final nowUtc = DateTime.now().toUtc();
    return into(ringDevices).insertOnConflictUpdate(
      device.copyWith(
        updatedAt: Value(nowUtc),
      ),
    );
  }

  Future<void> updateDeviceActivity({
    required String id,
    DateTime? lastDingAt,
    DateTime? lastMotionAt,
  }) {
    final nowUtc = DateTime.now().toUtc();
    return (update(ringDevices)..where((d) => d.id.equals(id))).write(
      RingDevicesCompanion(
        lastDingAt: lastDingAt != null ? Value(lastDingAt.toUtc()) : const Value.absent(),
        lastMotionAt: lastMotionAt != null ? Value(lastMotionAt.toUtc()) : const Value.absent(),
        updatedAt: Value(nowUtc),
      ),
    );
  }

  /// 🔔 تفعيل أو تعطيل مستشعر الحركة للكاميرا وحفظها في الخزنة
  Future<void> toggleDeviceMotion({
    required String id,
    required bool isMotionEnabled,
  }) {
    return (update(ringDevices)..where((d) => d.id.equals(id))).write(
      RingDevicesCompanion(
        isMotionEnabled: Value(isMotionEnabled),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  /// 🌐 تحديث حالة اتصال الكاميرا (أونلاين / أوفلاين)
  Future<void> toggleDeviceOnlineStatus({
    required String id,
    required bool isOnline,
  }) {
    return (update(ringDevices)..where((d) => d.id.equals(id))).write(
      RingDevicesCompanion(
        isOnline: Value(isOnline),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  // --- Events ---
  Stream<List<RingEventEntry>> watchRecentEvents({int limit = 30}) =>
      (select(ringEvents)
            ..orderBy([(e) => OrderingTerm.desc(e.timestamp)])
            ..limit(limit))
          .watch();

  Future<void> insertEvent(RingEventsCompanion event) {
    final nowUtc = DateTime.now().toUtc();
    return into(ringEvents).insert(
      event.copyWith(
        timestamp: event.timestamp.present
            ? Value(event.timestamp.value.toUtc())
            : Value(nowUtc),
        createdAt: event.createdAt.present
            ? Value(event.createdAt.value.toUtc())
            : Value(nowUtc),
      ),
    );
  }

  Future<void> markEventAsRead(String eventId) {
    return (update(ringEvents)..where((e) => e.id.equals(eventId)))
        .write(const RingEventsCompanion(isRead: Value(true)));
  }
}