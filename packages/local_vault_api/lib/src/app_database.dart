// packages/local_vault_api/lib/src/app_database.dart
import 'package:drift/drift.dart';
import 'connection.dart';
import 'daos/app_settings_dao.dart';
import 'daos/contacts_dao.dart';
import 'daos/focus_dao.dart';
import 'daos/safety_dao.dart';
import 'daos/spatial_nodes_dao.dart';
import 'daos/tasks_dao.dart';
import 'migrations/database_migrations.dart';
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

  @override
  int get schemaVersion => 9; // 👈 تم التحديث إلى 9

  @override
  MigrationStrategy get migration => DatabaseMigrations.createStrategy(this);

  // ===========================================================================
  // 🧩 Domain DAOs (Data Access Objects)
  // ===========================================================================
  late final SpatialNodesDao spatialNodesDao = SpatialNodesDao(this);
  late final AppSettingsDao settingsDao = AppSettingsDao(this);
  late final TasksDao tasksDao = TasksDao(this);
  late final ContactsDao contactsDao = ContactsDao(this);
  late final FocusDao focusDao = FocusDao(this);
  late final SafetyDao safetyDao = SafetyDao(this);

  // ===========================================================================
  // 🛡️ Forwarding Facade API
  // ===========================================================================

  // 1. Spatial Nodes
  Stream<List<SpatialNode>> watchAllSpatialNodes() =>
      spatialNodesDao.watchAllSpatialNodes();
  Future<List<SpatialNode>> getAllSpatialNodes() =>
      spatialNodesDao.getAllSpatialNodes();
  Future<void> updateNodeCoordinates({
    required String id,
    required int x,
    required int y,
    required int floorLevel,
  }) =>
      spatialNodesDao.updateNodeCoordinates(
        id: id,
        x: x,
        y: y,
        floorLevel: floorLevel,
      );
  Future<void> upsertSpatialNode(SpatialNodesCompanion node) =>
      spatialNodesDao.upsertSpatialNode(node);
  Future<void> softDeleteSpatialNode(String id) =>
      spatialNodesDao.softDeleteSpatialNode(id);
  Future<int> deleteSpatialNode(String id) =>
      spatialNodesDao.deleteSpatialNode(id);

  // 2. Settings & Persona
  Stream<AppSetting> watchSettings() => settingsDao.watchSettings();
  Future<bool> hasCompletedOnboarding() => settingsDao.hasCompletedOnboarding();
  Future<void> completeOnboarding({
    required String persona,
    required bool isHighContrast,
    required double speechRate,
  }) =>
      settingsDao.completeOnboarding(
        persona: persona,
        isHighContrast: isHighContrast,
        speechRate: speechRate,
      );
  Future<AppSetting> getSettings() => settingsDao.getSettings();
  Future<void> updateSettings(AppSettingsCompanion updated) =>
      settingsDao.updateSettings(updated);

  // 3. Tasks & Memos
  Stream<List<Task>> watchAllTasks() => tasksDao.watchAllTasks();
  Stream<List<Task>> watchPendingTasks() => tasksDao.watchPendingTasks();
  Future<List<Task>> getPendingTasks() => tasksDao.getPendingTasks();
  Future<Task?> getTaskById(String taskId) => tasksDao.getTaskById(taskId);
  Future<String> insertTask({
    required String title,
    DateTime? dueDate,
    String priority = 'medium',
    String? id,
  }) =>
      tasksDao.insertTask(
        title: title,
        dueDate: dueDate,
        priority: priority,
        id: id,
      );
  Future<void> toggleTaskCompletion(String taskId, bool isCompleted) =>
      tasksDao.toggleTaskCompletion(taskId, isCompleted);
  Future<void> updateTaskDetails({
    required String taskId,
    String? title,
    DateTime? dueDate,
    String? priority,
    bool clearDueDate = false,
  }) =>
      tasksDao.updateTaskDetails(
        taskId: taskId,
        title: title,
        dueDate: dueDate,
        priority: priority,
        clearDueDate: clearDueDate,
      );
  Future<void> softDeleteTask(String taskId) => tasksDao.softDeleteTask(taskId);
  Future<int> deleteTask(String id) => tasksDao.deleteTask(id);

  Stream<List<VoiceMemo>> watchRecentMemos({int limit = 25}) =>
      tasksDao.watchRecentMemos(limit: limit);
  Future<String> insertMemo({
    required String title,
    required String content,
    String? id,
  }) =>
      tasksDao.insertMemo(title: title, content: content, id: id);
  Future<void> softDeleteMemo(String memoId) => tasksDao.softDeleteMemo(memoId);
  Future<int> deleteMemo(String id) => tasksDao.deleteMemo(id);

  // 4. Contacts & Messages
  Stream<List<Contact>> watchAllContacts() => contactsDao.watchAllContacts();
  Future<List<Contact>> getEmergencyContacts() =>
      contactsDao.getEmergencyContacts();
  Future<Contact?> findContactByNameOrRelation(String query) =>
      contactsDao.findContactByNameOrRelation(query);
  Future<String> insertContact({
    required String name,
    required String phoneNumber,
    String? relationship,
    bool isEmergency = false,
    String? id,
  }) =>
      contactsDao.insertContact(
        name: name,
        phoneNumber: phoneNumber,
        relationship: relationship,
        isEmergency: isEmergency,
        id: id,
      );
  Future<void> softDeleteContact(String contactId) =>
      contactsDao.softDeleteContact(contactId);
  Future<int> deleteContact(String id) => contactsDao.deleteContact(id);

  Stream<List<MessagesVaultData>> watchMessagesForContact(
    String contactIdentifier,
  ) =>
      contactsDao.watchMessagesForContact(contactIdentifier);
  Future<List<MessagesVaultData>> getRecentMessages({int limit = 50}) =>
      contactsDao.getRecentMessages(limit: limit);
  Future<List<MessagesVaultData>> getUnreadMessages() =>
      contactsDao.getUnreadMessages();
  Future<String> insertMessage({
    required String contactIdentifier,
    required String senderName,
    required String messageText,
    String platform = 'sms',
    bool isOutgoing = false,
  }) =>
      contactsDao.insertMessage(
        contactIdentifier: contactIdentifier,
        senderName: senderName,
        messageText: messageText,
        platform: platform,
        isOutgoing: isOutgoing,
      );
  Future<void> markMessagesAsRead(String contactIdentifier) =>
      contactsDao.markMessagesAsRead(contactIdentifier);

  Future<List<NotificationsDigestData>> getUnreadNotifications() =>
      contactsDao.getUnreadNotifications();
  Future<int> insertNotification(NotificationsDigestCompanion notif) =>
      contactsDao.insertNotification(notif);
  Future<void> markAllNotificationsAsRead() =>
      contactsDao.markAllNotificationsAsRead();

  // 5. Alarms & Focus
  Stream<List<Alarm>> watchAllAlarms() => focusDao.watchAllAlarms();
  Future<String> insertAlarm({
    required int hour,
    required int minute,
    String label = 'Beacon Alarm',
    String? id,
  }) =>
      focusDao.insertAlarm(
        hour: hour,
        minute: minute,
        label: label,
        id: id,
      );
  Future<void> toggleAlarmStatus(String alarmId, bool isActive) =>
      focusDao.toggleAlarmStatus(alarmId, isActive);
  Future<void> softDeleteAlarm(String alarmId) =>
      focusDao.softDeleteAlarm(alarmId);
  Future<int> deleteAlarm(String id) => focusDao.deleteAlarm(id);

  Stream<List<FocusSession>> watchTodayFocusSessions() =>
      focusDao.watchTodayFocusSessions();
  Future<String> insertFocusSession(int durationMinutes, {String? id}) =>
      focusDao.insertFocusSession(durationMinutes, id: id);

  // 6. Safety & Vision
  Future<String> insertSosAlert({
    required double latitude,
    required double longitude,
    required int batteryLevel,
    required String googleMapsUrl,
    String status = 'active',
  }) =>
      safetyDao.insertSosAlert(
        latitude: latitude,
        longitude: longitude,
        batteryLevel: batteryLevel,
        googleMapsUrl: googleMapsUrl,
        status: status,
      );

  Future<String> insertVisionScan({
    required String mode,
    required String prompt,
    required String description,
  }) =>
      safetyDao.insertVisionScan(
        mode: mode,
        prompt: prompt,
        description: description,
      );
  Stream<List<VisionScan>> watchRecentVisionScans({int limit = 20}) =>
      safetyDao.watchRecentVisionScans(limit: limit);

  // ===========================================================================
  // 🌟 7. الدوال المضافة: المفاتيح السيادية واقتران الأجهزة (تم حل الخطأ هنا)
  // ===========================================================================

  Future<String?> getSovereignKey(String id) async {
    try {
      final rows = await customSelect(
        'SELECT key_hex FROM sovereign_keys WHERE id = ? LIMIT 1',
        variables: [Variable<String>(id)],
      ).get();
      if (rows.isEmpty) return null;
      return rows.first.data['key_hex'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<void> setSovereignKey(String id, String keyHex) async {
    try {
      await customStatement(
        'INSERT OR REPLACE INTO sovereign_keys (id, key_hex) VALUES (?, ?)',
        [id, keyHex],
      );
    } catch (_) {}
  }

  Future<String?> getDevicePairingMeta(String key) async {
    try {
      final rows = await customSelect(
        'SELECT val FROM device_pairing_meta WHERE key = ? LIMIT 1',
        variables: [Variable<String>(key)],
      ).get();
      if (rows.isEmpty) return null;
      return rows.first.data['val'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<void> setDevicePairingMeta(String key, String val) async {
    try {
      await customStatement(
        'INSERT OR REPLACE INTO device_pairing_meta (key, val) VALUES (?, ?)',
        [key, val],
      );
    } catch (_) {}
  }

  Future<void> deleteDevicePairingMeta(String key) async {
    try {
      await customStatement(
        'DELETE FROM device_pairing_meta WHERE key = ?',
        [key],
      );
    } catch (_) {}
  }
}