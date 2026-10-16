import 'package:equatable/equatable.dart';

enum RingDeviceType {
  doorbell,
  stickUpCam,
  indoorCam,
  floodlightCam,
}

enum RingCameraLocation {
  frontDoor,
  backyard,
  nursery,
  garage,
  custom,
}

class RingDevice extends Equatable {
  const RingDevice({
    required this.id,
    required this.label,
    required this.type,
    required this.location,
    required this.spatialX,
    required this.spatialY,
    required this.spatialFloor,
    this.batteryLevel = 100,
    this.isOnline = true,
    this.firmwareVersion = 'v3.2.14',
    this.isMotionEnabled = true,
    this.lastDingAt,
    this.lastMotionAt,
  });

  final String id;
  final String label;
  final RingDeviceType type;
  final RingCameraLocation location;
  final int spatialX;
  final int spatialY;
  final int spatialFloor;
  final int batteryLevel;
  final bool isOnline;
  final String firmwareVersion;
  final bool isMotionEnabled;
  final DateTime? lastDingAt;
  final DateTime? lastMotionAt;

  RingDevice copyWith({
    String? id,
    String? label,
    RingDeviceType? type,
    RingCameraLocation? location,
    int? spatialX,
    int? spatialY,
    int? spatialFloor,
    int? batteryLevel,
    bool? isOnline,
    String? firmwareVersion,
    bool? isMotionEnabled,
    DateTime? lastDingAt,
    DateTime? lastMotionAt,
  }) {
    return RingDevice(
      id: id ?? this.id,
      label: label ?? this.label,
      type: type ?? this.type,
      location: location ?? this.location,
      spatialX: spatialX ?? this.spatialX,
      spatialY: spatialY ?? this.spatialY,
      spatialFloor: spatialFloor ?? this.spatialFloor,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      isOnline: isOnline ?? this.isOnline,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      isMotionEnabled: isMotionEnabled ?? this.isMotionEnabled,
      lastDingAt: lastDingAt ?? this.lastDingAt,
      lastMotionAt: lastMotionAt ?? this.lastMotionAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        label,
        type,
        location,
        spatialX,
        spatialY,
        spatialFloor,
        batteryLevel,
        isOnline,
        firmwareVersion,
        isMotionEnabled,
        lastDingAt,
        lastMotionAt,
      ];
}