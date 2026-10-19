// packages/local_vault_api/lib/src/migrations/database_migrations.dart
import 'package:drift/drift.dart';
import 'package:local_vault_api/src/app_database.dart';

class DatabaseMigrations {
  static const String defaultSettingsId = 'local_device_settings';

  static MigrationStrategy createStrategy(AppDatabase db) {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        // 1. إنشاء كافة الجداول المعرفة في AppDatabase
        await m.createAll();

        // 2. غرس الإعدادات الافتراضية
        await db.into(db.appSettings).insert(
          AppSettingsCompanion.insert(id: defaultSettingsId),
        );

        // 3. غرس خريطة الفضاء والغرف الأساسية (الطوابق: -1، 0، 1)
        await seedDefaultSpatialNodes(db);

        // 4. غرس كاميرات Ring الافتراضية الأربع
        await seedDefaultRingDevices(db);
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
        if (from < 9) {
          await db.customStatement(
            'CREATE TABLE IF NOT EXISTS sovereign_keys (id TEXT PRIMARY KEY, key_hex TEXT);',
          );
          await db.customStatement(
            'CREATE TABLE IF NOT EXISTS device_pairing_meta (key TEXT PRIMARY KEY, val TEXT);',
          );
        }
        if (from < 10) {
          await m.createTable(db.ringDevices);
          await m.createTable(db.ringEvents);
          await seedDefaultRingDevices(db);
          await seedPerimeterSpatialNodes(db);
        }
        if (from < 11) {
          await m.addColumn(db.appSettings, db.appSettings.spatialWhisperEnabled);
        }
        // 🚀 ترقية الإصدار 12: غرس عُقد الطابق -1 (Past, Vault & Infrastructure)
        if (from < 12) {
          await seedFloorNeg1SpatialNodes(db);
        }
      },
      beforeOpen: (details) async {
        // تأمين وجود الجداول المخصصة ومفاتيح السيادة دائماً
        await db.customStatement(
          'CREATE TABLE IF NOT EXISTS sovereign_keys (id TEXT PRIMARY KEY, key_hex TEXT);',
        );
        await db.customStatement(
          'CREATE TABLE IF NOT EXISTS device_pairing_meta (key TEXT PRIMARY KEY, val TEXT);',
        );

        // تأمين اكتمال العناوين والكاميرات وعقد الطابق -1 في أي قاعدة بيانات مفتوحة مسبقاً
        await backfillDefaultTitles(db);
        await seedPerimeterSpatialNodes(db);
        await seedDefaultRingDevices(db);
        await seedFloorNeg1SpatialNodes(db);
      },
    );
  }

  /// غرس الغرف الأساسية في كافة الطوابق (-1، 0، 1)
  static Future<void> seedDefaultSpatialNodes(AppDatabase db) async {
    final defaultNodes = <SpatialNodesCompanion>[
      // ==========================================
      // 🏠 الطابق الأرضي (Floor 0: Present & Operations)
      // ==========================================
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
        id: Value('perimeter_f0'),
        moduleId: Value('perimeter'),
        floorLevel: Value(0),
        x: Value(0),
        y: Value(2),
        customTitle: Value('Smart Perimeter & Ring'),
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

      // ==========================================
      // ⚙️ الطابق الأول (Floor 1: Future & Tuning)
      // ==========================================
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
        id: Value('perimeter_f1'),
        moduleId: Value('perimeter'),
        floorLevel: Value(1),
        x: Value(0),
        y: Value(2),
        customTitle: Value('Perimeter Camera Tuning'),
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

      // ==========================================
      // 🏛️ الطابق السفلي (Floor -1: Past, Vault & Infrastructure)
      // ==========================================
      const SpatialNodesCompanion(
        id: Value('cockpit_f_neg1'),
        moduleId: Value('cockpit'),
        floorLevel: Value(-1),
        x: Value(0),
        y: Value(0),
        customTitle: Value('Mesh Hub & Connected Devices'),
      ),
      const SpatialNodesCompanion(
        id: Value('focus_f_neg1'),
        moduleId: Value('focus'),
        floorLevel: Value(-1),
        x: Value(0),
        y: Value(1),
        customTitle: Value('Focus Analytics Archive'),
      ),
      const SpatialNodesCompanion(
        id: Value('perimeter_f_neg1'),
        moduleId: Value('perimeter'),
        floorLevel: Value(-1),
        x: Value(0),
        y: Value(2),
        customTitle: Value('Perimeter Activity Archive'),
      ),
      const SpatialNodesCompanion(
        id: Value('comms_f_neg1'),
        moduleId: Value('comms'),
        floorLevel: Value(-1),
        x: Value(0),
        y: Value(-1),
        customTitle: Value('Arbitrum Sepolia SOS Ledger'),
      ),
      const SpatialNodesCompanion(
        id: Value('vision_f_neg1'),
        moduleId: Value('vision'),
        floorLevel: Value(-1),
        x: Value(1),
        y: Value(0),
        customTitle: Value('Vision & OCR Archive'),
      ),
      const SpatialNodesCompanion(
        id: Value('agenda_f_neg1'),
        moduleId: Value('agenda'),
        floorLevel: Value(-1),
        x: Value(-1),
        y: Value(0),
        customTitle: Value('Archived Tasks & Notes'),
      ),
    ];

    for (final node in defaultNodes) {
      await db.into(db.spatialNodes).insert(node, mode: InsertMode.insertOrReplace);
    }
  }

  /// غرس غرف الطابق -1 بشكل مستقل لضمان التوافق مع قواعد البيانات الموجودة
  static Future<void> seedFloorNeg1SpatialNodes(AppDatabase db) async {
    final floorNeg1Nodes = <SpatialNodesCompanion>[
      const SpatialNodesCompanion(
        id: Value('cockpit_f_neg1'),
        moduleId: Value('cockpit'),
        floorLevel: Value(-1),
        x: Value(0),
        y: Value(0),
        customTitle: Value('Mesh Hub & Connected Devices'),
      ),
      const SpatialNodesCompanion(
        id: Value('focus_f_neg1'),
        moduleId: Value('focus'),
        floorLevel: Value(-1),
        x: Value(0),
        y: Value(1),
        customTitle: Value('Focus Analytics Archive'),
      ),
      const SpatialNodesCompanion(
        id: Value('perimeter_f_neg1'),
        moduleId: Value('perimeter'),
        floorLevel: Value(-1),
        x: Value(0),
        y: Value(2),
        customTitle: Value('Perimeter Activity Archive'),
      ),
      const SpatialNodesCompanion(
        id: Value('comms_f_neg1'),
        moduleId: Value('comms'),
        floorLevel: Value(-1),
        x: Value(0),
        y: Value(-1),
        customTitle: Value('Arbitrum Sepolia SOS Ledger'),
      ),
      const SpatialNodesCompanion(
        id: Value('vision_f_neg1'),
        moduleId: Value('vision'),
        floorLevel: Value(-1),
        x: Value(1),
        y: Value(0),
        customTitle: Value('Vision & OCR Archive'),
      ),
      const SpatialNodesCompanion(
        id: Value('agenda_f_neg1'),
        moduleId: Value('agenda'),
        floorLevel: Value(-1),
        x: Value(-1),
        y: Value(0),
        customTitle: Value('Archived Tasks & Notes'),
      ),
    ];

    for (final node in floorNeg1Nodes) {
      await db.into(db.spatialNodes).insert(node, mode: InsertMode.insertOrIgnore);
    }
  }

  /// غرس غرف المحيط الأمني بشكل مستقل لضمان التوافق
  static Future<void> seedPerimeterSpatialNodes(AppDatabase db) async {
    final perimeterNodes = <SpatialNodesCompanion>[
      const SpatialNodesCompanion(
        id: Value('perimeter_f0'),
        moduleId: Value('perimeter'),
        floorLevel: Value(0),
        x: Value(0),
        y: Value(2),
        customTitle: Value('Smart Perimeter & Ring'),
      ),
      const SpatialNodesCompanion(
        id: Value('perimeter_f1'),
        moduleId: Value('perimeter'),
        floorLevel: Value(1),
        x: Value(0),
        y: Value(2),
        customTitle: Value('Perimeter Camera Tuning'),
      ),
      const SpatialNodesCompanion(
        id: Value('perimeter_f_neg1'),
        moduleId: Value('perimeter'),
        floorLevel: Value(-1),
        x: Value(0),
        y: Value(2),
        customTitle: Value('Perimeter Activity Archive'),
      ),
    ];

    for (final node in perimeterNodes) {
      await db.into(db.spatialNodes).insert(node, mode: InsertMode.insertOrIgnore);
    }
  }

  /// غرس أجهزة كاميرات Ring الافتراضية
  static Future<void> seedDefaultRingDevices(AppDatabase db) async {
    final defaultCameras = <RingDevicesCompanion>[
      const RingDevicesCompanion(
        id: Value('ring_cam_front_door'),
        label: Value('Front Door'),
        deviceType: Value('doorbell'),
        location: Value('frontDoor'),
        spatialX: Value(0),
        spatialY: Value(2),
        spatialFloor: Value(0),
        batteryLevel: Value(92),
        isOnline: Value(true),
        isMotionEnabled: Value(true),
      ),
      const RingDevicesCompanion(
        id: Value('ring_cam_backyard'),
        label: Value('Backyard'),
        deviceType: Value('floodlightCam'),
        location: Value('backyard'),
        spatialX: Value(0),
        spatialY: Value(-2),
        spatialFloor: Value(0),
        batteryLevel: Value(100),
        isOnline: Value(true),
        isMotionEnabled: Value(true),
      ),
      const RingDevicesCompanion(
        id: Value('ring_cam_nursery'),
        label: Value('Nursery'),
        deviceType: Value('indoorCam'),
        location: Value('nursery'),
        spatialX: Value(2),
        spatialY: Value(0),
        spatialFloor: Value(0),
        batteryLevel: Value(88),
        isOnline: Value(true),
        isMotionEnabled: Value(true),
      ),
      const RingDevicesCompanion(
        id: Value('ring_cam_garage'),
        label: Value('Garage Driveway'),
        deviceType: Value('stickUpCam'),
        location: Value('garage'),
        spatialX: Value(-2),
        spatialY: Value(0),
        spatialFloor: Value(0),
        batteryLevel: Value(79),
        isOnline: Value(true),
        isMotionEnabled: Value(true),
      ),
    ];

    for (final cam in defaultCameras) {
      await db.into(db.ringDevices).insert(cam, mode: InsertMode.insertOrIgnore);
    }
  }

  /// استكمال وتحديث العناوين التلقائية للغرف
  static Future<void> backfillDefaultTitles(AppDatabase db) async {
    const titles = {
      'cockpit_f0': 'Today Cockpit',
      'focus_f0': 'Focus & Alarms',
      'perimeter_f0': 'Smart Perimeter & Ring',
      'comms_f0': 'Communications',
      'vision_f0': 'AI Vision Studio',
      'agenda_f0': 'Agenda & Tasks',
      'cockpit_f1': 'Core Engine & Preferences',
      'focus_f1': 'Focus & Alarm Tuning',
      'perimeter_f1': 'Perimeter Camera Tuning',
      'comms_f1': 'Safety & SOS Preferences',
      'vision_f1': 'AI Vision Tuning',
      'agenda_f1': 'Agenda Preferences',
      'cockpit_f_neg1': 'Mesh Hub & Connected Devices',
      'focus_f_neg1': 'Focus Analytics Archive',
      'perimeter_f_neg1': 'Perimeter Activity Archive',
      'comms_f_neg1': 'Arbitrum Sepolia SOS Ledger',
      'vision_f_neg1': 'Vision & OCR Archive',
      'agenda_f_neg1': 'Archived Tasks & Notes',
    };

    for (final entry in titles.entries) {
      await (db.update(db.spatialNodes)
            ..where((n) => n.id.equals(entry.key) & n.customTitle.isNull()))
          .write(SpatialNodesCompanion(customTitle: Value(entry.value)));
    }
  }
}