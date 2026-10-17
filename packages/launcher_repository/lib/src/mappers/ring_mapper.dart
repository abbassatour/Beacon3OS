// packages/launcher_repository/lib/src/mappers/ring_mapper.dart
import 'package:local_vault_api/local_vault_api.dart' as db;
import '../models/ring_device_entity.dart';
import '../models/ring_event_entity.dart';

extension RingDeviceDataToEntity on db.RingDeviceEntry {
  RingDeviceEntity toEntity() {
    return RingDeviceEntity(
      id: id,
      label: label,
      deviceType: deviceType,
      location: location,
      spatialX: spatialX,
      spatialY: spatialY,
      spatialFloor: spatialFloor,
      batteryLevel: batteryLevel,
      isOnline: isOnline,
      isMotionEnabled: isMotionEnabled,
      lastDingAt: lastDingAt,
      lastMotionAt: lastMotionAt,
    );
  }
}

extension RingEventDataToEntity on db.RingEventEntry {
  RingEventEntity toEntity() {
    return RingEventEntity(
      id: id,
      deviceId: deviceId,
      deviceLabel: deviceLabel,
      eventType: eventType,
      timestamp: timestamp,
      snapshotPath: snapshotPath,
      aiSceneDescription: aiSceneDescription,
      isRead: isRead,
    );
  }
}