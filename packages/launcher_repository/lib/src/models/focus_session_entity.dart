// packages/launcher_repository/lib/src/models/focus_session_entity.dart
import 'package:equatable/equatable.dart';

class FocusSessionEntity extends Equatable {
  const FocusSessionEntity({
    required this.id,
    required this.durationMinutes,
    required this.sessionType,
    required this.completedAt,
  });

  final String id;
  final int durationMinutes;
  final String sessionType;
  final DateTime completedAt;

  @override
  List<Object?> get props => [id, durationMinutes, sessionType, completedAt];
}