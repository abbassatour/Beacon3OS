// packages/local_vault_api/lib/src/daos/safety_dao.dart
import 'package:drift/drift.dart';
import 'package:local_vault_api/src/app_database.dart';
import 'package:uuid/uuid.dart';

class SafetyDao extends DatabaseAccessor<AppDatabase> {
  SafetyDao(super.db);

  final _uuid = const Uuid();

  // --- SOS Alerts ---
  Future<String> insertSosAlert({
    required double latitude,
    required double longitude,
    required int batteryLevel,
    required String googleMapsUrl,
    String status = 'active',
  }) async {
    final alertId = _uuid.v4();
    await into(attachedDatabase.sosAlerts).insert(
      SosAlertsCompanion.insert(
        id: alertId,
        latitude: latitude,
        longitude: longitude,
        batteryLevel: Value(batteryLevel),
        googleMapsUrl: googleMapsUrl,
        status: Value(status),
      ),
    );
    return alertId;
  }

  // --- Vision Scans ---
  Future<String> insertVisionScan({
    required String mode,
    required String prompt,
    required String description,
  }) async {
    final scanId = _uuid.v4();
    await into(attachedDatabase.visionScans).insert(
      VisionScansCompanion.insert(
        id: scanId,
        mode: mode,
        prompt: prompt,
        description: description,
      ),
    );
    return scanId;
  }

  Stream<List<VisionScan>> watchRecentVisionScans({int limit = 20}) =>
      (select(attachedDatabase.visionScans)
            ..where((v) => v.deletedAt.isNull())
            ..orderBy([(v) => OrderingTerm.desc(v.createdAt)])
            ..limit(limit))
          .watch();
}