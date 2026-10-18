// packages/local_vault_api/lib/src/daos/focus_dao.dart
import 'package:drift/drift.dart';
import 'package:local_vault_api/src/app_database.dart';
import 'package:uuid/uuid.dart';

class FocusDao extends DatabaseAccessor<AppDatabase> {
  FocusDao(super.db);

  final _uuid = const Uuid();

  // --- Alarms ---
  Stream<List<Alarm>> watchAllAlarms() => (select(attachedDatabase.alarms)
        ..where((a) => a.deletedAt.isNull())
        ..orderBy([
          (a) => OrderingTerm.asc(a.hour),
          (a) => OrderingTerm.asc(a.minute),
        ]))
      .watch();

  Future<String> insertAlarm({
    required int hour,
    required int minute,
    String label = 'Beacon Alarm',
    String? id,
  }) async {
    final alarmId = id ?? _uuid.v4();
    final nowUtc = DateTime.now().toUtc();

    await into(attachedDatabase.alarms).insert(
      AlarmsCompanion.insert(
        id: alarmId,
        hour: hour,
        minute: minute,
        label: Value(label),
        createdAt: Value(nowUtc),
        updatedAt: Value(nowUtc),
      ),
    );
    return alarmId;
  }

  Future<void> toggleAlarmStatus(String alarmId, bool isActive) {
    return (update(attachedDatabase.alarms)..where((a) => a.id.equals(alarmId)))
        .write(
      AlarmsCompanion(
        isActive: Value(isActive),
        updatedAt: Value(DateTime.now().toUtc()),
        isSynced: const Value(false),
      ),
    );
  }

  Future<void> softDeleteAlarm(String alarmId) {
    final nowUtc = DateTime.now().toUtc();
    return (update(attachedDatabase.alarms)..where((a) => a.id.equals(alarmId)))
        .write(
      AlarmsCompanion(
        deletedAt: Value(nowUtc),
        updatedAt: Value(nowUtc),
        isSynced: const Value(false),
      ),
    );
  }

  Future<int> deleteAlarm(String id) =>
      (delete(attachedDatabase.alarms)..where((a) => a.id.equals(id))).go();

  // --- Focus Sessions ---
  Stream<List<FocusSession>> watchTodayFocusSessions() {
    // حساب بداية اليوم حسب توقيت المستخدم المحلي، ثم تحويل النقطة الزمنية إلى UTC
    final nowLocal = DateTime.now();
    final startOfLocalDay = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
    final startOfDayUtc = startOfLocalDay.toUtc();

    return (select(attachedDatabase.focusSessions)
          ..where((s) =>
              s.deletedAt.isNull() &
              s.completedAt.isBiggerOrEqualValue(startOfDayUtc))
          ..orderBy([(s) => OrderingTerm.desc(s.completedAt)]))
        .watch();
  }

  Future<String> insertFocusSession(int durationMinutes, {String? id}) async {
    final sessionId = id ?? _uuid.v4();
    final nowUtc = DateTime.now().toUtc();

    await into(attachedDatabase.focusSessions).insert(
      FocusSessionsCompanion.insert(
        id: sessionId,
        durationMinutes: durationMinutes,
        completedAt: Value(nowUtc),
        createdAt: Value(nowUtc),
        updatedAt: Value(nowUtc),
      ),
    );
    return sessionId;
  }
}