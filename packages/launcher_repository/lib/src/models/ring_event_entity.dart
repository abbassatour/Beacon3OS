// packages/launcher_repository/lib/src/models/ring_event_entity.dart
import 'package:equatable/equatable.dart';

class RingEventEntity extends Equatable {
  const RingEventEntity({
    required this.id,
    required this.deviceId,
    required this.deviceLabel,
    required this.eventType,
    required this.timestamp,
    this.snapshotPath,
    this.aiSceneDescription,
    this.isRead = false,
  });

  final String id;
  final String deviceId;
  final String deviceLabel;
  final String eventType;
  final DateTime timestamp;
  final String? snapshotPath;
  final String? aiSceneDescription;
  final bool isRead;

  @override
  List<Object?> get props => [
        id,
        deviceId,
        deviceLabel,
        eventType,
        timestamp,
        snapshotPath,
        aiSceneDescription,
        isRead,
      ];
}