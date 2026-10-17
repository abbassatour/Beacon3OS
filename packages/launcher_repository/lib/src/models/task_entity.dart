// packages/launcher_repository/lib/src/models/task_entity.dart
import 'package:equatable/equatable.dart';

class TaskEntity extends Equatable {
  const TaskEntity({
    required this.id,
    required this.title,
    this.dueDate,
    this.priority = 'medium',
    this.isCompleted = false,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final DateTime? dueDate;
  final String priority;
  final bool isCompleted;
  final DateTime updatedAt;

  TaskEntity copyWith({
    String? id,
    String? title,
    DateTime? dueDate,
    bool clearDueDate = false,
    String? priority,
    bool? isCompleted,
    DateTime? updatedAt,
  }) {
    return TaskEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      priority: priority ?? this.priority,
      isCompleted: isCompleted ?? this.isCompleted,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        dueDate,
        priority,
        isCompleted,
        updatedAt,
      ];
}