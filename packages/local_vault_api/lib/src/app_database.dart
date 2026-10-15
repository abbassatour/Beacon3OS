// packages/local_vault_api/lib/src/app_database.dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'connection.dart';
import 'tables/alarms_table.dart';
import 'tables/app_settings_table.dart';
import 'tables/contacts_table.dart';
import 'tables/focus_sessions_table.dart';
import 'tables/messages_vault_table.dart';
import 'tables/notifications_table.dart';
import 'tables/sos_alerts_table.dart';
import 'tables/spatial_nodes_table.dart';
import 'tables/tasks_table.dart';
import 'tables/vision_scans_table.dart';
import 'tables/voice_memos_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    VoiceMemos,
    Tasks,
    NotificationsDigest,
    Contacts,
    MessagesVault,
    Alarms,
    FocusSessions,
    AppSettings,
    SosAlerts,
    VisionScans,
    SpatialNodes,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openConnection());

  // ===========================================================================
  // ⚙️ الثوابت وكائنات التوليد
  // ===========================================================================
  static const String defaultSettingsId = 'local_device_settings';
  final _uuid = const Uuid();

  // 1. ترقية رقم الإصدار إلى 8 لدعم استقرار العناوين
  @override
  int get schemaVersion => 8;

  // 2. تحديث استراتيجية الترقية الآمنة
  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        await into(appSettings).insert(
          AppSettingsCompanion.insert(id: defaultSettingsId),
        );
        await _seedDefaultSpatialNodes();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 5) {
          await m.createTable(appSettings);
          await m.createTable(sosAlerts);
          await m.createTable(visionScans);
          await into(appSettings).insert(
            AppSettingsCompanion.insert(id: defaultSettingsId),
            mode: InsertMode.insertOrIgnore,
          );
        }
        if (from < 6) {
          await m.addColumn(appSettings, appSettings.userPersona);
          await m.addColumn(appSettings, appSettings.hasCompletedOnboarding);
        }
        if (from < 7) {
          await m.createTable(spatialNodes);
          await _seedDefaultSpatialNodes();
        }
        if (from < 8) {
          await _backfillDefaultTitles();
        }
      },
      beforeOpen: (details) async {
        // حماية تضمن تعبئة أي حقول customTitle فارغة عند إقلاع التطبيق
        await _backfillDefaultTitles();
      },
    );
  }

  // ===========================================================================
  // 🧭 0. إدارة الشبكة الإحداثية الفضائية (Spatial Grid Topology Engine)
  // ===========================================================================

  /// مراقبة جميع الغرف والعُقد النشطة في الفضاء بشكل لحظي
  Stream<List<SpatialNode>> watchAllSpatialNodes() => (select(spatialNodes)
        ..where((n) => n.deletedAt.isNull() & n.isVisible.equals(true))
        ..orderBy([
          (n) => OrderingTerm.asc(n.floorLevel),
          (n) => OrderingTerm.asc(n.id),
        ]))
      .watch();

  /// جلب كافة العُقد الفضائية لمرة واحدة
  Future<List<SpatialNode>> getAllSpatialNodes() => (select(spatialNodes)
        ..where((n) => n.deletedAt.isNull() & n.isVisible.equals(true)))
      .get();

  /// تحديث موقع غرفة معين في الفضاء (X, Y, Floor) مع وسم غير متزامن للسحابة
  Future<void> updateNodeCoordinates({
    required String id,
    required int x,
    required int y,
    required int floorLevel,
  }) {
    return (update(spatialNodes)..where((n) => n.id.equals(id))).write(
      SpatialNodesCompanion(
        x: Value(x),
        y: Value(y),
        floorLevel: Value(floorLevel),
        updatedAt: Value(DateTime.now()),
        isSynced: const Value(false),
      ),
    );
  }

  /// إدراج أو تعديل عقدة فضائية كاملة
  Future<void> upsertSpatialNode(SpatialNodesCompanion node) {
    return into(spatialNodes).insert(
      node.copyWith(
        updatedAt: Value(DateTime.now()),
        isSynced: const Value(false),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  /// الحذف الناعم لغرفة فضائية
  Future<void> softDeleteSpatialNode(String id) {
    return (update(spatialNodes)..where((n) => n.id.equals(id))).write(
      SpatialNodesCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
        isSynced: const Value(false),
      ),
    );
  }

  /// البذر التلقائي الذكي للغرف الخمس الأساسية على الطابقين 0 و 1 مع العناوين النظيفة
  Future<void> _seedDefaultSpatialNodes() async {
    final defaultNodes = <SpatialNodesCompanion>[
      // 🏠 الطابق الأرضي (Floor 0)
      const SpatialNodesCompanion(
        id: Value('cockpit_f0'),
        moduleId: Value('cockpit'),
        floorLevel: Value(0),
        x: Value(0),
        y: Value(0), // Center
        customTitle: Value('Today Cockpit'),
      ),
      const SpatialNodesCompanion(
        id: Value('focus_f0'),
        moduleId: Value('focus'),
        floorLevel: Value(0),
        x: Value(0),
        y: Value(1), // North
        customTitle: Value('Focus & Alarms'),
      ),
      const SpatialNodesCompanion(
        id: Value('comms_f0'),
        moduleId: Value('comms'),
        floorLevel: Value(0),
        x: Value(0),
        y: Value(-1), // South
        customTitle: Value('Communications'),
      ),
      const SpatialNodesCompanion(
        id: Value('vision_f0'),
        moduleId: Value('vision'),
        floorLevel: Value(0),
        x: Value(1),
        y: Value(0), // East
        customTitle: Value('AI Vision Studio'),
      ),
      const SpatialNodesCompanion(
        id: Value('agenda_f0'),
        moduleId: Value('agenda'),
        floorLevel: Value(0),
        x: Value(-1),
        y: Value(0), // West
        customTitle: Value('Agenda & Tasks'),
      ),

      // ⚙️ الطابق الأول (Floor 1 - Settings & Engines)
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
      await into(spatialNodes).insert(node, mode: InsertMode.insertOrReplace);
    }
  }

  /// تعبئة تلقائية آمنة للعناوين الفارغة في القواعد الحالية دون تجاوز تعديلات المستخدم
  Future<void> _backfillDefaultTitles() async {
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
      await (update(spatialNodes)
            ..where((n) => n.id.equals(entry.key) & n.customTitle.isNull()))
          .write(SpatialNodesCompanion(customTitle: Value(entry.value)));
    }
  }

  // ===========================================================================
  // 🎛️ 1. إدارة الإعدادات والهوية (Settings & Persona Engine)
  // ===========================================================================

  Stream<AppSetting> watchSettings() => (select(appSettings)
        ..where((s) => s.id.equals(defaultSettingsId)))
      .watchSingle();

  Future<bool> hasCompletedOnboarding() async {
    final settings = await getSettings();
    return settings.hasCompletedOnboarding;
  }

  Future<void> completeOnboarding({
    required String persona,
    required bool isHighContrast,
    required double speechRate,
  }) async {
    await updateSettings(
      AppSettingsCompanion(
        userPersona: Value(persona),
        hasCompletedOnboarding: const Value(true),
        isHighContrast: Value(isHighContrast),
        speechRate: Value(speechRate),
      ),
    );
  }

  Future<AppSetting> getSettings() async {
    final existing = await (select(appSettings)
          ..where((s) => s.id.equals(defaultSettingsId)))
        .getSingleOrNull();

    if (existing != null) return existing;

    await into(appSettings).insert(
      AppSettingsCompanion.insert(id: defaultSettingsId),
      mode: InsertMode.insertOrIgnore,
    );
    return (select(appSettings)
          ..where((s) => s.id.equals(defaultSettingsId)))
        .getSingle();
  }

  Future<void> updateSettings(AppSettingsCompanion updated) {
    return (update(appSettings)..where((s) => s.id.equals(defaultSettingsId)))
        .write(updated.copyWith(
          updatedAt: Value(DateTime.now()),
          isSynced: const Value(false),
        ));
  }

  // ===========================================================================
  // 📋 2. عمليات المهام مع الحذف الناعم (Tasks Engine)
  // ===========================================================================

  Stream<List<Task>> watchAllTasks() => (select(tasks)
        ..where((t) => t.deletedAt.isNull())
        ..orderBy([
          (t) => OrderingTerm.asc(t.isCompleted),
          (t) => OrderingTerm.asc(t.dueDate),
        ]))
      .watch();

  Stream<List<Task>> watchPendingTasks() => (select(tasks)
        ..where((t) => t.deletedAt.isNull() & t.isCompleted.equals(false))
        ..orderBy([(t) => OrderingTerm.asc(t.dueDate)]))
      .watch();

  Future<List<Task>> getPendingTasks() => (select(tasks)
        ..where((t) => t.deletedAt.isNull() & t.isCompleted.equals(false)))
      .get();

  Future<String> insertTask({
    required String title,
    DateTime? dueDate,
    String priority = 'medium',
    String? id,
  }) async {
    final taskId = id ?? _uuid.v4();
    await into(tasks).insert(
      TasksCompanion.insert(
        id: taskId,
        title: title,
        dueDate: Value(dueDate),
        priority: Value(priority),
      ),
    );
    return taskId;
  }

  Future<void> toggleTaskCompletion(String taskId, bool isCompleted) {
    return (update(tasks)..where((t) => t.id.equals(taskId))).write(
      TasksCompanion(
        isCompleted: Value(isCompleted),
        updatedAt: Value(DateTime.now()),
        isSynced: const Value(false),
      ),
    );
  }

  Future<void> softDeleteTask(String taskId) {
    return (update(tasks)..where((t) => t.id.equals(taskId))).write(
      TasksCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
        isSynced: const Value(false),
      ),
    );
  }

  // ===========================================================================
  // 🎙️ 3. المذكرات والملاحظات الصوتية (Voice Memos)
  // ===========================================================================

  Stream<List<VoiceMemo>> watchRecentMemos({int limit = 25}) =>
      (select(voiceMemos)
            ..where((m) => m.deletedAt.isNull())
            ..orderBy([(m) => OrderingTerm.desc(m.createdAt)])
            ..limit(limit))
          .watch();

  Future<String> insertMemo({
    required String title,
    required String content,
    String? id,
  }) async {
    final memoId = id ?? _uuid.v4();
    await into(voiceMemos).insert(
      VoiceMemosCompanion.insert(
        id: memoId,
        title: title,
        content: content,
      ),
    );
    return memoId;
  }

  Future<void> softDeleteMemo(String memoId) {
    return (update(voiceMemos)..where((m) => m.id.equals(memoId))).write(
      VoiceMemosCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
        isSynced: const Value(false),
      ),
    );
  }

  // ===========================================================================
  // 📇 4. جهات الاتصال (Contacts)
  // ===========================================================================

  Stream<List<Contact>> watchAllContacts() => (select(contacts)
        ..where((c) => c.deletedAt.isNull())
        ..orderBy([(c) => OrderingTerm.asc(c.name)]))
      .watch();

  Future<List<Contact>> getEmergencyContacts() => (select(contacts)
        ..where((c) => c.deletedAt.isNull() & c.isEmergency.equals(true)))
      .get();

  Future<Contact?> findContactByNameOrRelation(String query) {
    final clean = query.trim().toLowerCase();
    return (select(contacts)
          ..where((c) =>
              c.deletedAt.isNull() &
              (c.name.lower().equals(clean) |
                  c.relationship.lower().equals(clean) |
                  c.name.lower().like('%$clean%') |
                  c.relationship.lower().like('%$clean%')))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<String> insertContact({
    required String name,
    required String phoneNumber,
    String? relationship,
    bool isEmergency = false,
    String? id,
  }) async {
    final contactId = id ?? _uuid.v4();
    await into(contacts).insert(
      ContactsCompanion.insert(
        id: contactId,
        name: name,
        phoneNumber: phoneNumber,
        relationship: Value(relationship),
        isEmergency: Value(isEmergency),
      ),
    );
    return contactId;
  }

  Future<void> softDeleteContact(String contactId) {
    return (update(contacts)..where((c) => c.id.equals(contactId))).write(
      ContactsCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
        isSynced: const Value(false),
      ),
    );
  }

  // ===========================================================================
  // ⏰ 5. المنبهات الهادئة (Alarms)
  // ===========================================================================

  Stream<List<Alarm>> watchAllAlarms() => (select(alarms)
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
    await into(alarms).insert(
      AlarmsCompanion.insert(
        id: alarmId,
        hour: hour,
        minute: minute,
        label: Value(label),
      ),
    );
    return alarmId;
  }

  Future<void> toggleAlarmStatus(String alarmId, bool isActive) {
    return (update(alarms)..where((a) => a.id.equals(alarmId))).write(
      AlarmsCompanion(
        isActive: Value(isActive),
        updatedAt: Value(DateTime.now()),
        isSynced: const Value(false),
      ),
    );
  }

  Future<void> softDeleteAlarm(String alarmId) {
    return (update(alarms)..where((a) => a.id.equals(alarmId))).write(
      AlarmsCompanion(
        deletedAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
        isSynced: const Value(false),
      ),
    );
  }

  // ===========================================================================
  // ⏳ 6. جلسات التركيز (Focus Sessions)
  // ===========================================================================

  Stream<List<FocusSession>> watchTodayFocusSessions() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    return (select(focusSessions)
          ..where((s) =>
              s.deletedAt.isNull() &
              s.completedAt.isBiggerOrEqualValue(startOfDay))
          ..orderBy([(s) => OrderingTerm.desc(s.completedAt)]))
        .watch();
  }

  Future<String> insertFocusSession(int durationMinutes, {String? id}) async {
    final sessionId = id ?? _uuid.v4();
    await into(focusSessions).insert(
      FocusSessionsCompanion.insert(
        id: sessionId,
        durationMinutes: durationMinutes,
      ),
    );
    return sessionId;
  }

  // ===========================================================================
  // 🚨 7. استغاثات الطوارئ وسجل الرادار (SOS Alerts)
  // ===========================================================================

  Future<String> insertSosAlert({
    required double latitude,
    required double longitude,
    required int batteryLevel,
    required String googleMapsUrl,
    String status = 'active',
  }) async {
    final alertId = _uuid.v4();
    await into(sosAlerts).insert(
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

  // ===========================================================================
  // 👁️ 8. الفحوصات البصرية الذكية (Vision Scans)
  // ===========================================================================

  Future<String> insertVisionScan({
    required String mode,
    required String prompt,
    required String description,
  }) async {
    final scanId = _uuid.v4();
    await into(visionScans).insert(
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
      (select(visionScans)
            ..where((v) => v.deletedAt.isNull())
            ..orderBy([(v) => OrderingTerm.desc(v.createdAt)])
            ..limit(limit))
          .watch();

  // ===========================================================================
  // 💬 9. الرسائل والإشعارات (Messages & Notifications)
  // ===========================================================================

  Stream<List<MessagesVaultData>> watchMessagesForContact(
    String contactIdentifier,
  ) {
    return (select(messagesVault)
          ..where((m) =>
              m.deletedAt.isNull() &
              m.contactIdentifier.equals(contactIdentifier))
          ..orderBy([(m) => OrderingTerm.asc(m.timestamp)]))
        .watch();
  }

  Future<List<MessagesVaultData>> getRecentMessages({int limit = 50}) =>
      (select(messagesVault)
            ..where((m) => m.deletedAt.isNull())
            ..orderBy([(m) => OrderingTerm.desc(m.timestamp)])
            ..limit(limit))
          .get();

  Future<List<MessagesVaultData>> getUnreadMessages() => (select(messagesVault)
        ..where((m) => m.deletedAt.isNull() & m.isRead.equals(false)))
      .get();

  Future<String> insertMessage({
    required String contactIdentifier,
    required String senderName,
    required String messageText,
    String platform = 'sms',
    bool isOutgoing = false,
  }) async {
    final msgId = _uuid.v4();
    await into(messagesVault).insert(
      MessagesVaultCompanion.insert(
        id: msgId,
        contactIdentifier: contactIdentifier,
        senderName: senderName,
        messageText: messageText,
        platform: Value(platform),
        isOutgoing: Value(isOutgoing),
      ),
    );
    return msgId;
  }

  Future<void> markMessagesAsRead(String contactIdentifier) {
    return (update(messagesVault)
          ..where((m) => m.contactIdentifier.equals(contactIdentifier)))
        .write(MessagesVaultCompanion(
          isRead: const Value(true),
          updatedAt: Value(DateTime.now()),
          isSynced: const Value(false),
        ));
  }

  Future<List<NotificationsDigestData>> getUnreadNotifications() =>
      (select(notificationsDigest)..where((t) => t.isRead.equals(false))).get();

  Future<int> insertNotification(NotificationsDigestCompanion notif) =>
      into(notificationsDigest).insert(notif);

  Future<void> markAllNotificationsAsRead() =>
      (update(notificationsDigest)..where((t) => t.isRead.equals(false))).write(
        const NotificationsDigestCompanion(isRead: Value(true)),
      );

  // ===========================================================================
  // 🧹 عمليات الحذف النهائي (Hard Deletes for Sync Cleanup)
  // ===========================================================================

  Future<int> deleteTask(String id) =>
      (delete(tasks)..where((t) => t.id.equals(id))).go();

  Future<int> deleteMemo(String id) =>
      (delete(voiceMemos)..where((m) => m.id.equals(id))).go();

  Future<int> deleteContact(String id) =>
      (delete(contacts)..where((c) => c.id.equals(id))).go();

  Future<int> deleteAlarm(String id) =>
      (delete(alarms)..where((a) => a.id.equals(id))).go();

  Future<int> deleteSpatialNode(String id) =>
      (delete(spatialNodes)..where((n) => n.id.equals(id))).go();

  // ===========================================================================
  // 📋 عمليات المهام الإضافية للتعديل بالذكاء الاصطناعي
  // ===========================================================================

  Future<Task?> getTaskById(String taskId) =>
      (select(tasks)..where((t) => t.id.equals(taskId) & t.deletedAt.isNull()))
          .getSingleOrNull();

  Future<void> updateTaskDetails({
    required String taskId,
    String? title,
    DateTime? dueDate,
    String? priority,
    bool clearDueDate = false,
  }) {
    return (update(tasks)..where((t) => t.id.equals(taskId))).write(
      TasksCompanion(
        title: title != null ? Value(title) : const Value.absent(),
        dueDate: clearDueDate
            ? const Value(null)
            : (dueDate != null ? Value(dueDate) : const Value.absent()),
        priority: priority != null ? Value(priority) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
        isSynced: const Value(false),
      ),
    );
  }
}