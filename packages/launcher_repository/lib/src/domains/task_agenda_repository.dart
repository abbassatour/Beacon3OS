// packages/launcher_repository/lib/src/domains/task_agenda_repository.dart
import 'dart:developer';

import 'package:cloud_sync_api/cloud_sync_api.dart';
import 'package:drift/drift.dart';
import 'package:local_vault_api/local_vault_api.dart' as db;

import '../models/task_entity.dart';
import '../models/voice_memo_entity.dart';
import '../mappers/agenda_mapper.dart';

abstract class TaskAgendaRepository {
  Stream<List<TaskEntity>> watchTasks();
  Future<List<TaskEntity>> getPendingTasks();
  Future<TaskEntity?> getTaskById(String taskId);
  Future<String> createTask({
    required String title,
    DateTime? dueDate,
    String priority = 'medium',
  });
  Future<void> updateTask({
    required String taskId,
    String? title,
    DateTime? dueDate,
    String? priority,
    bool clearDueDate = false,
  });
  Future<void> toggleTask(TaskEntity task);
  Future<void> deleteTask(dynamic taskOrId);

  Stream<List<VoiceMemoEntity>> watchMemos();
  Future<String> createMemo({
    required String title,
    required String content,
  });
  Future<void> deleteMemo(dynamic memoOrId);
  
  Future<void> restoreTasksAndMemosFromCloud();
  Future<void> syncPendingTasksAndMemos();
}

class TaskAgendaRepositoryImpl implements TaskAgendaRepository {
  TaskAgendaRepositoryImpl({
    required db.AppDatabase database,
    required CloudSyncClient cloudSync,
  })  : _db = database,
        _cloud = cloudSync;

  final db.AppDatabase _db;
  final CloudSyncClient _cloud;

  @override
  Stream<List<TaskEntity>> watchTasks() {
    return _db.watchAllTasks().map(
          (driftTasks) => driftTasks.map((t) => t.toEntity()).toList(),
        );
  }

  @override
  Future<List<TaskEntity>> getPendingTasks() async {
    final driftTasks = await _db.getPendingTasks();
    return driftTasks.map((t) => t.toEntity()).toList();
  }

  @override
  Future<TaskEntity?> getTaskById(String taskId) async {
    final driftTask = await _db.getTaskById(taskId);
    return driftTask?.toEntity();
  }

  @override
  Future<String> createTask({
    required String title,
    DateTime? dueDate,
    String priority = 'medium',
  }) async {
    final id = await _db.insertTask(
      title: title,
      dueDate: dueDate,
      priority: priority,
    );

    _cloud
        .syncTask(
          id: id,
          title: title,
          dueDate: dueDate,
          priority: priority,
        )
        .catchError((Object error) {
      log('TaskAgendaRepository: Cloud sync deferred for task [$id]: $error');
    });

    return id;
  }

  @override
  Future<void> updateTask({
    required String taskId,
    String? title,
    DateTime? dueDate,
    String? priority,
    bool clearDueDate = false,
  }) async {
    await _db.updateTaskDetails(
      taskId: taskId,
      title: title,
      dueDate: dueDate,
      priority: priority,
      clearDueDate: clearDueDate,
    );

    final updated = await _db.getTaskById(taskId);
    if (updated != null) {
      _cloud
          .syncTask(
            id: updated.id,
            title: updated.title,
            dueDate: updated.dueDate,
            priority: updated.priority,
            isCompleted: updated.isCompleted,
          )
          .catchError((Object error) {
        log('TaskAgendaRepository: Cloud update deferred for task [$taskId]: $error');
      });
    }
  }

  @override
  Future<void> toggleTask(TaskEntity task) async {
    final nextStatus = !task.isCompleted;
    await _db.toggleTaskCompletion(task.id, nextStatus);

    _cloud
        .syncTask(
          id: task.id,
          title: task.title,
          dueDate: task.dueDate,
          priority: task.priority,
          isCompleted: nextStatus,
        )
        .catchError((Object error) {
      log('TaskAgendaRepository: Cloud toggle deferred for task [${task.id}]: $error');
    });
  }

  @override
  Future<void> deleteTask(dynamic taskOrId) async {
    final String id = taskOrId is TaskEntity ? taskOrId.id : taskOrId.toString();
    await _db.softDeleteTask(id);

    _cloud.softDeleteTaskInCloud(id).catchError((Object error) {
      log('TaskAgendaRepository: Cloud delete deferred for task [$id]: $error');
    });
  }

  @override
  Stream<List<VoiceMemoEntity>> watchMemos() {
    return _db.watchRecentMemos().map(
          (driftMemos) => driftMemos.map((m) => m.toEntity()).toList(),
        );
  }

  @override
  Future<String> createMemo({
    required String title,
    required String content,
  }) async {
    final id = await _db.insertMemo(title: title, content: content);

    _cloud
        .syncMemo(id: id, title: title, content: content)
        .catchError((Object error) {
      log('TaskAgendaRepository: Cloud memo deferred [$id]: $error');
    });

    return id;
  }

  @override
  Future<void> deleteMemo(dynamic memoOrId) async {
    final String id = memoOrId is VoiceMemoEntity ? memoOrId.id : memoOrId.toString();
    await _db.softDeleteMemo(id);

    _cloud.softDeleteMemoInCloud(id).catchError((Object error) {
      log('TaskAgendaRepository: Cloud memo delete deferred [$id]: $error');
    });
  }

  @override
  Future<void> restoreTasksAndMemosFromCloud() async {
    if (!_cloud.isAuthenticated) return;
    try {
      final cloudTasks = await _cloud.fetchTasks();
      for (final t in cloudTasks) {
        DateTime? due;
        if (t['due_date'] != null) {
          due = DateTime.tryParse(t['due_date'] as String);
        }
        await _db.into(_db.tasks).insert(
              db.TasksCompanion.insert(
                id: t['id'] as String,
                title: t['title'] as String,
                dueDate: Value(due),
                priority: Value(t['priority'] as String? ?? 'medium'),
                isCompleted: Value(t['is_completed'] as bool? ?? false),
                isSynced: const Value(true),
              ),
              mode: InsertMode.insertOrReplace,
            );
      }
      log('TaskAgendaRepository: Tasks & Memos restored from cloud.');
    } catch (e, st) {
      log('TaskAgendaRepository: Cloud restore error: $e', stackTrace: st);
    }
  }

  @override
  Future<void> syncPendingTasksAndMemos() async {
    if (!_cloud.isAuthenticated) return;
    try {
      final pendingTasks = await (_db.select(_db.tasks)
            ..where((t) => t.isSynced.equals(false)))
          .get();
      for (final t in pendingTasks) {
        if (t.deletedAt != null) {
          await _cloud.softDeleteTaskInCloud(t.id);
          await _db.deleteTask(t.id);
        } else {
          await _cloud.syncTask(
            id: t.id,
            title: t.title,
            dueDate: t.dueDate,
            priority: t.priority,
            isCompleted: t.isCompleted,
          );
          await (_db.update(_db.tasks)..where((tbl) => tbl.id.equals(t.id)))
              .write(const db.TasksCompanion(isSynced: Value(true)));
        }
      }

      final pendingMemos = await (_db.select(_db.voiceMemos)
            ..where((m) => m.isSynced.equals(false)))
          .get();
      for (final m in pendingMemos) {
        if (m.deletedAt != null) {
          await _cloud.softDeleteMemoInCloud(m.id);
          await _db.deleteMemo(m.id);
        } else {
          await _cloud.syncMemo(id: m.id, title: m.title, content: m.content);
          await (_db.update(_db.voiceMemos)..where((tbl) => tbl.id.equals(m.id)))
              .write(const db.VoiceMemosCompanion(isSynced: Value(true)));
        }
      }
    } catch (e) {
      log('TaskAgendaRepository: Pending sync error: $e');
    }
  }
}