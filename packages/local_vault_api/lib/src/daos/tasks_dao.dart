// packages/local_vault_api/lib/src/daos/tasks_dao.dart
import 'package:drift/drift.dart';
import 'package:local_vault_api/src/app_database.dart';
import 'package:uuid/uuid.dart';

class TasksDao extends DatabaseAccessor<AppDatabase> {
  TasksDao(super.db);

  final _uuid = const Uuid();

  // --- Tasks ---
  Stream<List<Task>> watchAllTasks() => (select(attachedDatabase.tasks)
        ..where((t) => t.deletedAt.isNull())
        ..orderBy([
          (t) => OrderingTerm.asc(t.isCompleted),
          (t) => OrderingTerm.asc(t.dueDate),
        ]))
      .watch();

  Stream<List<Task>> watchPendingTasks() => (select(attachedDatabase.tasks)
        ..where((t) => t.deletedAt.isNull() & t.isCompleted.equals(false))
        ..orderBy([(t) => OrderingTerm.asc(t.dueDate)]))
      .watch();

  Future<List<Task>> getPendingTasks() => (select(attachedDatabase.tasks)
        ..where((t) => t.deletedAt.isNull() & t.isCompleted.equals(false)))
      .get();

  Future<Task?> getTaskById(String taskId) =>
      (select(attachedDatabase.tasks)
            ..where((t) => t.id.equals(taskId) & t.deletedAt.isNull()))
          .getSingleOrNull();

  Future<String> insertTask({
    required String title,
    DateTime? dueDate,
    String priority = 'medium',
    String? id,
  }) async {
    final taskId = id ?? _uuid.v4();
    final nowUtc = DateTime.now().toUtc();

    await into(attachedDatabase.tasks).insert(
      TasksCompanion.insert(
        id: taskId,
        title: title,
        dueDate: Value(dueDate?.toUtc()),
        priority: Value(priority),
        createdAt: Value(nowUtc),
        updatedAt: Value(nowUtc),
      ),
    );
    return taskId;
  }

  Future<void> toggleTaskCompletion(String taskId, bool isCompleted) {
    return (update(attachedDatabase.tasks)..where((t) => t.id.equals(taskId)))
        .write(
      TasksCompanion(
        isCompleted: Value(isCompleted),
        updatedAt: Value(DateTime.now().toUtc()),
        isSynced: const Value(false),
      ),
    );
  }

  Future<void> updateTaskDetails({
    required String taskId,
    String? title,
    DateTime? dueDate,
    String? priority,
    bool clearDueDate = false,
  }) {
    return (update(attachedDatabase.tasks)..where((t) => t.id.equals(taskId)))
        .write(
      TasksCompanion(
        title: title != null ? Value(title) : const Value.absent(),
        dueDate: clearDueDate
            ? const Value(null)
            : (dueDate != null ? Value(dueDate.toUtc()) : const Value.absent()),
        priority: priority != null ? Value(priority) : const Value.absent(),
        updatedAt: Value(DateTime.now().toUtc()),
        isSynced: const Value(false),
      ),
    );
  }

  Future<void> softDeleteTask(String taskId) {
    final nowUtc = DateTime.now().toUtc();
    return (update(attachedDatabase.tasks)..where((t) => t.id.equals(taskId)))
        .write(
      TasksCompanion(
        deletedAt: Value(nowUtc),
        updatedAt: Value(nowUtc),
        isSynced: const Value(false),
      ),
    );
  }

  Future<int> deleteTask(String id) =>
      (delete(attachedDatabase.tasks)..where((t) => t.id.equals(id))).go();

  // --- Voice Memos ---
  Stream<List<VoiceMemo>> watchRecentMemos({int limit = 25}) =>
      (select(attachedDatabase.voiceMemos)
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
    final nowUtc = DateTime.now().toUtc();

    await into(attachedDatabase.voiceMemos).insert(
      VoiceMemosCompanion.insert(
        id: memoId,
        title: title,
        content: content,
        createdAt: Value(nowUtc),
        updatedAt: Value(nowUtc),
      ),
    );
    return memoId;
  }

  Future<void> softDeleteMemo(String memoId) {
    final nowUtc = DateTime.now().toUtc();
    return (update(attachedDatabase.voiceMemos)
          ..where((m) => m.id.equals(memoId)))
        .write(
      VoiceMemosCompanion(
        deletedAt: Value(nowUtc),
        updatedAt: Value(nowUtc),
        isSynced: const Value(false),
      ),
    );
  }

  Future<int> deleteMemo(String id) =>
      (delete(attachedDatabase.voiceMemos)..where((m) => m.id.equals(id))).go();
}