// packages/launcher_repository/lib/src/mappers/focus_alarms_mapper.dart
import 'package:local_vault_api/local_vault_api.dart' as db;
import '../models/alarm_entity.dart';
import '../models/focus_session_entity.dart';

extension AlarmDataToEntity on db.Alarm {
  AlarmEntity toEntity() {
    return AlarmEntity(
      id: id,
      hour: hour,
      minute: minute,
      label: label,
      daysOfWeek: daysOfWeek,
      isActive: isActive,
    );
  }
}

extension FocusSessionDataToEntity on db.FocusSession {
  FocusSessionEntity toEntity() {
    return FocusSessionEntity(
      id: id,
      durationMinutes: durationMinutes,
      sessionType: sessionType,
      completedAt: completedAt,
    );
  }
}