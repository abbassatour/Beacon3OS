// packages/launcher_repository/lib/src/models/ring_device_entity.dart
import 'package:equatable/equatable.dart';

class RingDeviceEntity extends Equatable {
  const RingDeviceEntity({
    required this.id,
    required this.label,
    required this.deviceType,
    required this.location,
    this.spatialX = 0,
    this.spatialY = 2,
    this.spatialFloor = 0,
    this.batteryLevel = 100,
    this.isOnline = true,
    this.isMotionEnabled = true,
    this.lastDingAt,
    this.lastMotionAt,
  });

  final String id;
  final String label;
  final String deviceType;
  final String location;
  final int spatialX;
  final int spatialY;
  final int spatialFloor;
  final int batteryLevel;
  final bool isOnline;
  final bool isMotionEnabled;
  final DateTime? lastDingAt;
  final DateTime? lastMotionAt;

  @override
  List<Object?> get props => [
        id,
        label,
        deviceType,
        location,
        spatialX,
        spatialY,
        spatialFloor,
        batteryLevel,
        isOnline,
        isMotionEnabled,
        lastDingAt,
        lastMotionAt,
      ];
}