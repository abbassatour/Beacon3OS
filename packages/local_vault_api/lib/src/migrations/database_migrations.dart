// packages/local_vault_api/lib/src/migrations/database_migrations.dart
import 'package:drift/drift.dart';
import 'package:local_vault_api/src/app_database.dart';

class DatabaseMigrations {
  static const String defaultSettingsId = 'local_device_settings';

  static MigrationStrategy createStrategy(AppDatabase db) {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        await db.into(db.appSettings).insert(
          AppSettingsCompanion.insert(id: defaultSettingsId),
        );
        await seedDefaultSpatialNodes(db);
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 5) {
          await m.createTable(db.appSettings);
          await m.createTable(db.sosAlerts);
          await m.createTable(db.visionScans);
          await db.into(db.appSettings).insert(
            AppSettingsCompanion.insert(id: defaultSettingsId),
            mode: InsertMode.insertOrIgnore,
          );
        }
        if (from < 6) {
          await m.addColumn(db.appSettings, db.appSettings.userPersona);
          await m.addColumn(db.appSettings, db.appSettings.hasCompletedOnboarding);
        }
        if (from < 7) {
          await m.createTable(db.spatialNodes);
          await seedDefaultSpatialNodes(db);
        }
        if (from < 8) {
          await backfillDefaultTitles(db);
        }
      },
      beforeOpen: (details) async {
        await backfillDefaultTitles(db);
      },
    );
  }

  static Future<void> seedDefaultSpatialNodes(AppDatabase db) async {
    final defaultNodes = <SpatialNodesCompanion>[
      // 🏠 Floor 0 (Ground)
      const SpatialNodesCompanion(
        id: Value('cockpit_f0'),
        moduleId: Value('cockpit'),
        floorLevel: Value(0),
        x: Value(0),
        y: Value(0),
        customTitle: Value('Today Cockpit'),
      ),
      const SpatialNodesCompanion(
        id: Value('focus_f0'),
        moduleId: Value('focus'),
        floorLevel: Value(0),
        x: Value(0),
        y: Value(1),
        customTitle: Value('Focus & Alarms'),
      ),
      const SpatialNodesCompanion(
        id: Value('comms_f0'),
        moduleId: Value('comms'),
        floorLevel: Value(0),
        x: Value(0),
        y: Value(-1),
        customTitle: Value('Communications'),
      ),
      const SpatialNodesCompanion(
        id: Value('vision_f0'),
        moduleId: Value('vision'),
        floorLevel: Value(0),
        x: Value(1),
        y: Value(0),
        customTitle: Value('AI Vision Studio'),
      ),
      const SpatialNodesCompanion(
        id: Value('agenda_f0'),
        moduleId: Value('agenda'),
        floorLevel: Value(0),
        x: Value(-1),
        y: Value(0),
        customTitle: Value('Agenda & Tasks'),
      ),

      // ⚙️ Floor 1 (Settings & Engine)
      const SpatialNodesCompanion(
        id: Value('cockpit_f1'),
        moduleId: Value('cockpit'),
        floorLevel: Value(1),
        x: Value(0),
        y: Value(0),
        customTitle: Value('Core Engine & Preferences'),
      ),
      const SpatialNodesCompanion(
        id: Value('focus_f1'),
        moduleId: Value('focus'),
        floorLevel: Value(1),
        x: Value(0),
        y: Value(1),
        customTitle: Value('Focus & Alarm Tuning'),
      ),
      const SpatialNodesCompanion(
        id: Value('comms_f1'),
        moduleId: Value('comms'),
        floorLevel: Value(1),
        x: Value(0),
        y: Value(-1),
        customTitle: Value('Safety & SOS Preferences'),
      ),
      const SpatialNodesCompanion(
        id: Value('vision_f1'),
        moduleId: Value('vision'),
        floorLevel: Value(1),
        x: Value(1),
        y: Value(0),
        customTitle: Value('AI Vision Tuning'),
      ),
      const SpatialNodesCompanion(
        id: Value('agenda_f1'),
        moduleId: Value('agenda'),
        floorLevel: Value(1),
        x: Value(-1),
        y: Value(0),
        customTitle: Value('Agenda Preferences'),
      ),
    ];

    for (final node in defaultNodes) {
      await db.into(db.spatialNodes).insert(node, mode: InsertMode.insertOrReplace);
    }
  }

  static Future<void> backfillDefaultTitles(AppDatabase db) async {
    const titles = {
      'cockpit_f0': 'Today Cockpit',
      'focus_f0': 'Focus & Alarms',
      'comms_f0': 'Communications',
      'vision_f0': 'AI Vision Studio',
      'agenda_f0': 'Agenda & Tasks',
      'cockpit_f1': 'Core Engine & Preferences',
      'focus_f1': 'Focus & Alarm Tuning',
      'comms_f1': 'Safety & SOS Preferences',
      'vision_f1': 'AI Vision Tuning',
      'agenda_f1': 'Agenda Preferences',
    };

    for (final entry in titles.entries) {
      await (db.update(db.spatialNodes)
            ..where((n) => n.id.equals(entry.key) & n.customTitle.isNull()))
          .write(SpatialNodesCompanion(customTitle: Value(entry.value)));
    }
  }
}