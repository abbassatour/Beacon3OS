// packages/launcher_repository/lib/src/domains/focus_alarms_repository.dart
import 'dart:async';
import 'dart:developer';

import 'package:cloud_sync_api/cloud_sync_api.dart';
import 'package:drift/drift.dart';
import 'package:local_vault_api/local_vault_api.dart' as db;
import 'package:system_hardware_api/system_hardware_api.dart';

import '../mappers/focus_alarms_mapper.dart';
import '../models/alarm_entity.dart';
import '../models/focus_session_entity.dart';

abstract class FocusAlarmsRepository {
  Stream<List<AlarmEntity>> watchAlarms();
  Future<String> createAlarm({
    required int hour,
    required int minute,
    String label = 'Beacon Alarm',
  });
  Future<void> toggleAlarm(AlarmEntity alarm);
  Future<void> deleteAlarm(dynamic alarmOrId);

  Stream<List<FocusSessionEntity>> watchTodayFocusSessions();
  Future<String> recordCompletedFocusSession(int minutes);
  Future<void> syncPendingAlarms();

  /// 📥 استرجاع المنبهات المسجلة من السحابة تفاضلياً
  Future<void> restoreAlarmsFromCloud();

  /// 🛰️ بدء الاستماع اللحظي لتحديثات المنبهات من السحابة
  void initializeRealtimeSync();

  /// 🛑 تحرير موارد الاشتراكات
  void dispose();
}

class FocusAlarmsRepositoryImpl implements FocusAlarmsRepository {
  FocusAlarmsRepositoryImpl({
    required db.AppDatabase database,
    required CloudSyncClient cloudSync,
    required HardwareClient hardware,
  })  : _db = database,
        _cloud = cloudSync,
        _hardware = hardware;

  final db.AppDatabase _db;
  final CloudSyncClient _cloud;
  final HardwareClient _hardware;

  StreamSubscription<dynamic>? _authSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _realtimeAlarmsSubscription;

  @override
  Stream<List<AlarmEntity>> watchAlarms() {
    return _db.watchAllAlarms().map(
          (driftAlarms) => driftAlarms.map((a) => a.toEntity()).toList(),
        );
  }

  @override
  Future<String> createAlarm({
    required int hour,
    required int minute,
    String label = 'Beacon Alarm',
  }) async {
    final id = await _db.insertAlarm(hour: hour, minute: minute, label: label);

    final settings = await _db.getSettings();
    if (settings.syncAlarmsWithAndroidClock) {
      await _hardware.setSystemAlarm(hour: hour, minute: minute, label: label);
    }

    _cloud.syncAlarm(id: id, hour: hour, minute: minute, label: label).catchError((Object error) {
      log('FocusAlarmsRepository: Cloud alarm sync deferred [$id]: $error');
    });

    return id;
  }

  @override
  Future<void> toggleAlarm(AlarmEntity alarm) async {
    final nextStatus = !alarm.isActive;
    await _db.toggleAlarmStatus(alarm.id, nextStatus);

    if (nextStatus) {
      final settings = await _db.getSettings();
      if (settings.syncAlarmsWithAndroidClock) {
        await _hardware.setSystemAlarm(
          hour: alarm.hour,
          minute: alarm.minute,
          label: alarm.label,
        );
      }
    }

    _cloud.syncAlarm(
      id: alarm.id,
      hour: alarm.hour,
      minute: alarm.minute,
      label: alarm.label,
      isActive: nextStatus,
    ).catchError((Object error) {
      log('FocusAlarmsRepository: Cloud alarm toggle deferred: $error');
    });
  }

  @override
  Future<void> deleteAlarm(dynamic alarmOrId) async {
    final String id = alarmOrId is AlarmEntity ? alarmOrId.id : alarmOrId.toString();
    await _db.softDeleteAlarm(id);

    _cloud.softDeleteAlarmInCloud(id).catchError((Object error) {
      log('FocusAlarmsRepository: Cloud alarm delete deferred [$id]: $error');
    });
  }

  @override
  Stream<List<FocusSessionEntity>> watchTodayFocusSessions() {
    return _db.watchTodayFocusSessions().map(
          (driftSessions) => driftSessions.map((s) => s.toEntity()).toList(),
        );
  }

  @override
  Future<String> recordCompletedFocusSession(int minutes) async {
    final id = await _db.insertFocusSession(minutes);

    _cloud.syncFocusSession(id: id, durationMinutes: minutes).catchError((Object error) {
      log('FocusAlarmsRepository: Cloud focus sync deferred [$id]: $error');
    });

    return id;
  }

  @override
  void initializeRealtimeSync() {
    _authSubscription?.cancel();
    _authSubscription = _cloud.authStateChanges?.listen(
      (_) {
        if (_cloud.isAuthenticated) {
          _subscribeToRealtimeAlarms();
        } else {
          _realtimeAlarmsSubscription?.cancel();
          _realtimeAlarmsSubscription = null;
        }
      },
      onError: (Object error) {
        log('FocusAlarmsRepository: Auth state stream error: $error');
      },
    );

    if (_cloud.isAuthenticated) {
      _subscribeToRealtimeAlarms();
    }
  }

  void _subscribeToRealtimeAlarms() {
    _realtimeAlarmsSubscription?.cancel();
    try {
      final stream = _cloud.streamAlarms();
      if (stream != null) {
        _realtimeAlarmsSubscription = stream.listen(
          (cloudAlarms) async {
            if (cloudAlarms.isEmpty) return;
            try {
              final localAlarms = await (_db.select(_db.alarms)).get();
              final localMap = {for (final a in localAlarms) a.id: a};

              await _db.batch((batch) {
                for (final item in cloudAlarms) {
                  final id = item['id'] as String?;
                  if (id == null || id.isEmpty) continue;

                  final cloudUpdated = item['updated_at'] != null
                      ? DateTime.tryParse(item['updated_at'] as String)
                      : null;
                  final deletedAtStr = item['deleted_at'] as String?;
                  final DateTime? deletedAt =
                      deletedAtStr != null ? DateTime.tryParse(deletedAtStr) : null;

                  final local = localMap[id];

                  // فض النزاع وفق مبدأ LWW الزمني
                  final shouldApply = local == null ||
                      (cloudUpdated != null && cloudUpdated.isAfter(local.updatedAt)) ||
                      (local.isSynced);

                  if (!shouldApply) continue;

                  if (deletedAt != null) {
                    if (local != null) {
                      batch.delete(
                        _db.alarms,
                        db.AlarmsCompanion(id: Value(id)),
                      );
                    }
                  } else {
                    final hour = (item['hour'] as num?)?.toInt() ?? 8;
                    final minute = (item['minute'] as num?)?.toInt() ?? 0;

                    batch.insert(
                      _db.alarms,
                      db.AlarmsCompanion.insert(
                        id: id,
                        hour: hour,
                        minute: minute,
                        label: Value(item['label'] as String? ?? 'Beacon Alarm'),
                        daysOfWeek: Value(item['days_of_week'] as String? ?? 'daily'),
                        isActive: Value(item['is_active'] as bool? ?? true),
                        updatedAt: Value(cloudUpdated ?? DateTime.now().toUtc()),
                        isSynced: const Value(true),
                      ),
                      mode: InsertMode.insertOrReplace,
                    );
                  }
                }
              });
              log('FocusAlarmsRepository: ⚡ Realtime alarms synced with LWW resolution (${cloudAlarms.length} alarms).');
            } catch (e) {
              log('FocusAlarmsRepository: Error reconciling realtime alarms: $e');
            }
          },
          onError: (Object error) {
            log('FocusAlarmsRepository: Realtime alarms stream error (offline handled): $error');
          },
          cancelOnError: false,
        );
      }
    } catch (e) {
      log('FocusAlarmsRepository: Safe catch on streamAlarms init: $e');
    }
  }

  @override
  Future<void> restoreAlarmsFromCloud() async {
    if (!_cloud.isAuthenticated) return;
    try {
      // 🔄 استرجاع تفاضلي يشمل المحذوفات والتعديلات
      final cloudAlarms = await _cloud.fetchAlarmsDelta();
      if (cloudAlarms.isNotEmpty) {
        final localAlarms = await _db.select(_db.alarms).get();
        final localMap = {for (final a in localAlarms) a.id: a};

        await _db.batch((batch) {
          for (final a in cloudAlarms) {
            final id = a['id'] as String?;
            if (id == null) continue;

            final deletedAtStr = a['deleted_at'] as String?;
            final DateTime? deletedAt =
                deletedAtStr != null ? DateTime.tryParse(deletedAtStr) : null;
            final updatedStr = a['updated_at'] as String?;
            final DateTime? updatedAt =
                updatedStr != null ? DateTime.tryParse(updatedStr) : null;

            final local = localMap[id];

            if (deletedAt != null) {
              if (local != null) {
                batch.delete(_db.alarms, db.AlarmsCompanion(id: Value(id)));
              }
            } else {
              final shouldApply = local == null ||
                  (updatedAt != null && updatedAt.isAfter(local.updatedAt)) ||
                  (local.isSynced);

              if (shouldApply) {
                final hour = (a['hour'] as num?)?.toInt() ?? 8;
                final minute = (a['minute'] as num?)?.toInt() ?? 0;

                batch.insert(
                  _db.alarms,
                  db.AlarmsCompanion.insert(
                    id: id,
                    hour: hour,
                    minute: minute,
                    label: Value(a['label'] as String? ?? 'Beacon Alarm'),
                    daysOfWeek: Value(a['days_of_week'] as String? ?? 'daily'),
                    isActive: Value(a['is_active'] as bool? ?? true),
                    updatedAt: Value(updatedAt ?? DateTime.now().toUtc()),
                    isSynced: const Value(true),
                  ),
                  mode: InsertMode.insertOrReplace,
                );
              }
            }
          }
        });
        log('FocusAlarmsRepository: ⚡ Alarms delta restored from cloud in batch (${cloudAlarms.length} alarms).');
      }
    } catch (e, st) {
      log('FocusAlarmsRepository: Cloud restore error: $e', stackTrace: st);
    }
  }

  @override
  Future<void> syncPendingAlarms() async {
    if (!_cloud.isAuthenticated) return;
    try {
      final pending = await (_db.select(_db.alarms)..where((a) => a.isSynced.equals(false))).get();
      if (pending.isEmpty) return;

      final toDelete = pending.where((a) => a.deletedAt != null).toList();
      final toUpsert = pending.where((a) => a.deletedAt == null).toList();

      for (final a in toDelete) {
        await _cloud.softDeleteAlarmInCloud(a.id);
        await _db.deleteAlarm(a.id);
      }

      if (toUpsert.isNotEmpty) {
        final payload = toUpsert.map((a) => {
              'id': a.id,
              'hour': a.hour,
              'minute': a.minute,
              'label': a.label,
              'days_of_week': a.daysOfWeek,
              'is_active': a.isActive,
              'updated_at': a.updatedAt.toUtc().toIso8601String(),
            }).toList();

        await _cloud.syncAlarmsBatch(payload);

        final upsertIds = toUpsert.map((a) => a.id).toList();
        await (_db.update(_db.alarms)..where((tbl) => tbl.id.isIn(upsertIds)))
            .write(const db.AlarmsCompanion(isSynced: Value(true)));
      }

      log('FocusAlarmsRepository: ⚡ Pending offline alarms synced via batch.');
    } catch (e) {
      log('FocusAlarmsRepository: Pending alarm sync error: $e');
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _realtimeAlarmsSubscription?.cancel();
  }
}