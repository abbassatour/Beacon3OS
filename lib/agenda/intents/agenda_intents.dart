// lib/agenda/intents/agenda_intents.dart
import 'package:beacon_os/core/voice_bus/voice_bus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';
import 'package:local_vault_api/local_vault_api.dart';

/// معالج قراءة المهام بالمسار السريع الفوري (Sub-5ms)
class ReadTasksIntentHandler extends VoiceIntentHandler {
  @override
  String get intentId => 'READ_TASKS';

  @override
  int get priority => 75;

  @override
  RegExp get fastPathPattern => RegExp(
        r'^(what are my tasks|read tasks|my tasks|list tasks|show tasks|tasks|what tasks do i have)',
        caseSensitive: false,
      );

  @override
  Future<LauncherCommandResult> execute(
    BuildContext context,
    VoiceIntentContext intentContext,
  ) async {
    final tasksRepo = context.read<TaskAgendaRepository>();
    final pending = await tasksRepo.getPendingTasks();

    if (pending.isEmpty) {
      return const LauncherCommandResult(
        intent: 'READ_TASKS',
        spokenResponse: 'Your agenda is clear with zero pending tasks.',
      );
    }

    final topTask = pending.first;
    final count = pending.length;
    final countStr = count == 1 ? 'one task' : '$count tasks';

    return LauncherCommandResult(
      intent: 'READ_TASKS',
      spokenResponse:
          'You have $countStr pending. Top priority: ${topTask.title}.',
      actionPayload: pending,
    );
  }
}

/// معالج إضافة مهمة جديدة بالمسار السريع الفوري
class SaveTaskIntentHandler extends VoiceIntentHandler {
  @override
  String get intentId => 'SAVE_TASK';

  @override
  int get priority => 65;

  @override
  RegExp get fastPathPattern => RegExp(
        r'^(?:remind me to|add task|create task|task:?)\s+(.+)',
        caseSensitive: false,
      );

  @override
  Future<LauncherCommandResult> execute(
    BuildContext context,
    VoiceIntentContext intentContext,
  ) async {
    final tasksRepo = context.read<TaskAgendaRepository>();
    String taskTitle = '';

    // 1. استخراج النص من المسار السريع إذا تطابق النمط
    final match = fastPathPattern?.firstMatch(intentContext.rawQuery);
    if (match != null && match.groupCount >= 1) {
      taskTitle = match.group(1)?.trim() ?? '';
    }

    // 2. استخراج النص من معطيات LLM إذا أتى الاستدعاء عبر المسار الذكي
    if (taskTitle.isEmpty && intentContext.llmParameters.containsKey('title')) {
      taskTitle = intentContext.llmParameters['title'] as String;
    }

    if (taskTitle.isEmpty) {
      return const LauncherCommandResult(
        intent: 'SAVE_TASK_FAILED',
        spokenResponse: 'What task would you like me to save?',
      );
    }

    String priority = 'medium';
    if (taskTitle.toLowerCase().contains('urgent') ||
        taskTitle.toLowerCase().contains('high priority')) {
      priority = 'high';
      taskTitle = taskTitle
          .replaceAll(RegExp(r'\b(urgent|high priority)\b', caseSensitive: false), '')
          .trim();
    }

    final id = await tasksRepo.createTask(
      title: taskTitle,
      priority: priority,
    );

    return LauncherCommandResult(
      intent: 'SAVE_TASK',
      spokenResponse: 'Task added: $taskTitle.',
      actionPayload: id,
    );
  }
}

/// معالج تدوين مذكرة سريعة بالمسار السريع الفوري
class SaveMemoIntentHandler extends VoiceIntentHandler {
  @override
  String get intentId => 'SAVE_MEMO';

  @override
  int get priority => 65;

  @override
  RegExp get fastPathPattern => RegExp(
        r'^(?:note:?|memo:?|take note|save note)\s+(.+)',
        caseSensitive: false,
      );

  @override
  Future<LauncherCommandResult> execute(
    BuildContext context,
    VoiceIntentContext intentContext,
  ) async {
    final tasksRepo = context.read<TaskAgendaRepository>();
    String memoContent = '';

    final match = fastPathPattern?.firstMatch(intentContext.rawQuery);
    if (match != null && match.groupCount >= 1) {
      memoContent = match.group(1)?.trim() ?? '';
    }

    if (memoContent.isEmpty && intentContext.llmParameters.containsKey('content')) {
      memoContent = intentContext.llmParameters['content'] as String;
    }

    if (memoContent.isEmpty) {
      return const LauncherCommandResult(
        intent: 'SAVE_MEMO_FAILED',
        spokenResponse: 'Please state what you would like to note down.',
      );
    }

    final id = await tasksRepo.createMemo(
      title: 'Voice Note',
      content: memoContent,
    );

    return LauncherCommandResult(
      intent: 'SAVE_MEMO',
      spokenResponse: 'Note saved: $memoContent.',
      actionPayload: id,
    );
  }
}

/// معالج إتمام المهمة صوتياً بالمسار السريع (Sub-5ms)
class CompleteTaskIntentHandler extends VoiceIntentHandler {
  @override
  String get intentId => 'COMPLETE_TASK';

  @override
  int get priority => 70;

  @override
  RegExp get fastPathPattern => RegExp(
        r'^(?:complete|finish|mark done|done with)\s+(.+)',
        caseSensitive: false,
      );

  @override
  Future<LauncherCommandResult> execute(
    BuildContext context,
    VoiceIntentContext intentContext,
  ) async {
    final tasksRepo = context.read<TaskAgendaRepository>();
    final params = intentContext.llmParameters;
    String targetQuery = '';

    final match = fastPathPattern?.firstMatch(intentContext.rawQuery);
    if (match != null && match.groupCount >= 1) {
      targetQuery = match.group(1)?.trim() ?? '';
    }

    final pending = await tasksRepo.getPendingTasks();
    if (pending.isEmpty) {
      return const LauncherCommandResult(
        intent: 'COMPLETE_TASK_FAILED',
        spokenResponse: 'You have no pending tasks to complete.',
      );
    }

    Task? matchedTask;
    final taskId = params['task_id'] as String?;
    if (taskId != null && taskId.isNotEmpty) {
      matchedTask = pending.where((t) => t.id == taskId).firstOrNull;
    }

    if (matchedTask == null) {
      final cleanQuery = targetQuery.isNotEmpty
          ? targetQuery.toLowerCase()
          : (params['title'] as String? ?? '').toLowerCase();

      matchedTask = pending.where((t) =>
          t.title.toLowerCase().contains(cleanQuery) ||
          cleanQuery.contains(t.title.toLowerCase())).firstOrNull;
    }

    if (matchedTask != null) {
      await tasksRepo.toggleTask(matchedTask);
      return LauncherCommandResult(
        intent: 'COMPLETE_TASK',
        spokenResponse: 'Task completed: ${matchedTask.title}.',
        actionPayload: matchedTask,
      );
    }

    return LauncherCommandResult(
      intent: 'COMPLETE_TASK_NOT_FOUND',
      spokenResponse: 'Could not find a pending task matching $targetQuery.',
    );
  }
}

/// معالج حذف المهمة صوتياً بالمسار السريع
class DeleteTaskIntentHandler extends VoiceIntentHandler {
  @override
  String get intentId => 'DELETE_TASK';

  @override
  int get priority => 70;

  @override
  RegExp get fastPathPattern => RegExp(
        r'^(?:delete task|remove task)\s+(.+)',
        caseSensitive: false,
      );

  @override
  Future<LauncherCommandResult> execute(
    BuildContext context,
    VoiceIntentContext intentContext,
  ) async {
    final tasksRepo = context.read<TaskAgendaRepository>();
    final params = intentContext.llmParameters;
    String targetQuery = '';

    final match = fastPathPattern?.firstMatch(intentContext.rawQuery);
    if (match != null && match.groupCount >= 1) {
      targetQuery = match.group(1)?.trim() ?? '';
    }

    final pending = await tasksRepo.getPendingTasks();

    Task? matchedTask;
    final taskId = params['task_id'] as String?;
    if (taskId != null && taskId.isNotEmpty) {
      matchedTask = pending.where((t) => t.id == taskId).firstOrNull;
    }

    if (matchedTask == null) {
      final cleanQuery = targetQuery.isNotEmpty
          ? targetQuery.toLowerCase()
          : (params['title'] as String? ?? '').toLowerCase();

      matchedTask = pending.where((t) =>
          t.title.toLowerCase().contains(cleanQuery) ||
          cleanQuery.contains(t.title.toLowerCase())).firstOrNull;
    }

    if (matchedTask != null) {
      await tasksRepo.deleteTask(matchedTask.id);
      return LauncherCommandResult(
        intent: 'DELETE_TASK',
        spokenResponse: 'Deleted task: ${matchedTask.title}.',
        actionPayload: matchedTask,
      );
    }

    return LauncherCommandResult(
      intent: 'DELETE_TASK_NOT_FOUND',
      spokenResponse: 'Could not find a task matching $targetQuery to delete.',
    );
  }
}

/// معالج تعديل المهمة بالمسار الذكي والسريع (UPDATE_TASK)
class UpdateTaskIntentHandler extends VoiceIntentHandler {
  @override
  String get intentId => 'UPDATE_TASK';

  @override
  int get priority => 70;

  @override
  RegExp get fastPathPattern => RegExp(
        r'^(?:update task|change task|edit task|set task)\s+(.+)',
        caseSensitive: false,
      );

  @override
  Future<LauncherCommandResult> execute(
    BuildContext context,
    VoiceIntentContext intentContext,
  ) async {
    final tasksRepo = context.read<TaskAgendaRepository>();
    final params = intentContext.llmParameters;

    final taskId = params['task_id'] as String?;
    final newTitle = params['title'] as String?;
    String? newPriority = params['priority'] as String?;
    DateTime? newDueDate;
    if (params['due_date'] != null) {
      newDueDate = DateTime.tryParse(params['due_date'].toString());
    }

    final pending = await tasksRepo.getPendingTasks();

    Task? targetTask;
    if (taskId != null && taskId.isNotEmpty) {
      targetTask = await tasksRepo.getTaskById(taskId);
    }

    // مطابقة احتياطية بالاسم في حال تعذر الحصول على الـ id
    if (targetTask == null) {
      final raw = intentContext.rawQuery.toLowerCase();
      targetTask = pending.where((t) =>
          raw.contains(t.title.toLowerCase()) ||
          t.title.toLowerCase().contains(raw)).firstOrNull;
    }

    // استخراج أولوية المسار السريع إن لم يمررها الـ LLM
    if (targetTask != null && newPriority == null && newTitle == null) {
      final query = intentContext.normalizedQuery;
      if (query.contains('urgent') || query.contains('high')) {
        newPriority = 'high';
      } else if (query.contains('medium') || query.contains('normal')) {
        newPriority = 'medium';
      } else if (query.contains('low')) {
        newPriority = 'low';
      }
    }

    if (targetTask == null) {
      return const LauncherCommandResult(
        intent: 'UPDATE_TASK_NOT_FOUND',
        spokenResponse: 'Could not find a matching task to update.',
      );
    }

    await tasksRepo.updateTask(
      taskId: targetTask.id,
      title: newTitle,
      priority: newPriority,
      dueDate: newDueDate,
    );

    final updates = <String>[];
    if (newPriority != null) updates.add('priority set to $newPriority');
    if (newTitle != null) updates.add('renamed to $newTitle');
    if (newDueDate != null) updates.add('deadline updated');

    final changeSummary =
        updates.isNotEmpty ? updates.join(' and ') : 'updated successfully';

    return LauncherCommandResult(
      intent: 'UPDATE_TASK',
      spokenResponse: 'Task "${targetTask.title}" $changeSummary.',
      actionPayload: targetTask,
    );
  }
}

/// معالج حذف الملاحظات الصوتية (DELETE_MEMO)
class DeleteMemoIntentHandler extends VoiceIntentHandler {
  @override
  String get intentId => 'DELETE_MEMO';

  @override
  int get priority => 70;

  @override
  RegExp get fastPathPattern => RegExp(
        r'^(?:delete note|remove note|delete memo|remove memo)\s+(.+)',
        caseSensitive: false,
      );

  @override
  Future<LauncherCommandResult> execute(
    BuildContext context,
    VoiceIntentContext intentContext,
  ) async {
    final tasksRepo = context.read<TaskAgendaRepository>();
    final params = intentContext.llmParameters;

    final memoId = params['memo_id'] as String?;
    final memos = await tasksRepo.watchMemos().first;

    VoiceMemo? targetMemo;
    if (memoId != null && memoId.isNotEmpty) {
      targetMemo = memos.where((m) => m.id == memoId).firstOrNull;
    }

    if (targetMemo == null) {
      String queryTarget = '';
      final match = fastPathPattern?.firstMatch(intentContext.rawQuery);
      if (match != null && match.groupCount >= 1) {
        queryTarget = match.group(1)?.trim() ?? '';
      } else if (params.containsKey('title')) {
        queryTarget = params['title'] as String? ?? '';
      }

      final cleanQuery = queryTarget.toLowerCase();
      targetMemo = memos.where((m) =>
          m.title.toLowerCase().contains(cleanQuery) ||
          cleanQuery.contains(m.title.toLowerCase()) ||
          m.content.toLowerCase().contains(cleanQuery)).firstOrNull;
    }

    if (targetMemo != null) {
      await tasksRepo.deleteMemo(targetMemo.id);
      return LauncherCommandResult(
        intent: 'DELETE_MEMO',
        spokenResponse: 'Deleted note titled: ${targetMemo.title}.',
        actionPayload: targetMemo,
      );
    }

    return const LauncherCommandResult(
      intent: 'DELETE_MEMO_NOT_FOUND',
      spokenResponse: 'Could not find a note matching your request to delete.',
    );
  }
}