// packages/launcher_repository/lib/src/models/alarm_entity.dart
import 'package:equatable/equatable.dart';

class AlarmEntity extends Equatable {
  const AlarmEntity({
    required this.id,
    required this.hour,
    required this.minute,
    required this.label,
    required this.daysOfWeek,
    required this.isActive,
  });

  final String id;
  final int hour;
  final int minute;
  final String label;
  final String daysOfWeek;
  final bool isActive;

  @override
  List<Object?> get props => [id, hour, minute, label, daysOfWeek, isActive];
}