// packages/launcher_repository/lib/src/mappers/agenda_mapper.dart
import 'package:local_vault_api/local_vault_api.dart' as db;
import '../models/task_entity.dart';
import '../models/voice_memo_entity.dart';

extension TaskDataToEntity on db.Task {
  TaskEntity toEntity() {
    return TaskEntity(
      id: id,
      title: title,
      dueDate: dueDate,
      priority: priority,
      isCompleted: isCompleted,
      updatedAt: updatedAt,
    );
  }
}

extension VoiceMemoDataToEntity on db.VoiceMemo {
  VoiceMemoEntity toEntity() {
    return VoiceMemoEntity(
      id: id,
      title: title,
      content: content,
      createdAt: createdAt,
    );
  }
}