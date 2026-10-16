import 'dart:async';
import 'package:ring_integration_api/src/client/ring_client_interface.dart';
import 'package:ring_integration_api/src/models/ring_device.dart';
import 'package:ring_integration_api/src/models/ring_event.dart';
import 'package:uuid/uuid.dart';

class RingSimulatorClient implements RingClientInterface {
  RingSimulatorClient({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  // صورة اختبارية 1x1 شفافة صالحة كـ Base64 لضمان عدم حدوث Crash
  static const String dummyImageBase64 =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

  final List<RingDevice> _devices = [
    const RingDevice(
      id: 'ring_cam_front_door',
      label: 'Front Door',
      type: RingDeviceType.doorbell,
      location: RingCameraLocation.frontDoor,
      spatialX: 0,
      spatialY: 2,
      spatialFloor: 0,
      batteryLevel: 92,
    ),
    const RingDevice(
      id: 'ring_cam_backyard',
      label: 'Backyard',
      type: RingDeviceType.floodlightCam,
      location: RingCameraLocation.backyard,
      spatialX: 0,
      spatialY: -2,
      spatialFloor: 0,
      batteryLevel: 100, // سلكي دائم
    ),
    const RingDevice(
      id: 'ring_cam_nursery',
      label: 'Nursery',
      type: RingDeviceType.indoorCam,
      location: RingCameraLocation.nursery,
      spatialX: 2,
      spatialY: 0,
      spatialFloor: 0,
      batteryLevel: 88,
    ),
    const RingDevice(
      id: 'ring_cam_garage',
      label: 'Garage Driveway',
      type: RingDeviceType.stickUpCam,
      location: RingCameraLocation.garage,
      spatialX: -2,
      spatialY: 0,
      spatialFloor: 0,
      batteryLevel: 79,
    ),
  ];

  final StreamController<List<RingDevice>> _devicesController =
      StreamController<List<RingDevice>>.broadcast();
  final StreamController<RingEvent> _eventsController =
      StreamController<RingEvent>.broadcast();

  @override
  Stream<List<RingDevice>> get devicesStream => _devicesController.stream;

  @override
  Stream<RingEvent> get eventsStream => _eventsController.stream;

  @override
  Future<void> initialize() async {
    _devicesController.add(List.unmodifiable(_devices));
  }

  @override
  Future<List<RingDevice>> getDevices() async => List.unmodifiable(_devices);

  @override
  Future<RingDevice?> getDeviceById(String deviceId) async {
    return _devices.where((d) => d.id == deviceId).firstOrNull;
  }

  @override
  Future<String?> captureSnapshotBase64(String deviceId) async {
    // محاكاة التقاط إطار حي
    return dummyImageBase64;
  }

  @override
  Future<bool> startTwoWayAudio(String deviceId) async => true;

  @override
  Future<bool> stopTwoWayAudio(String deviceId) async => true;

  @override
  Future<RingEvent> triggerSimulatedScenario(RingScenarioPreset scenario) async {
    String targetDeviceId;
    String targetLabel;
    RingEventType eventType;
    String initialDescription;

    switch (scenario) {
      case RingScenarioPreset.courierDelivery:
        targetDeviceId = 'ring_cam_front_door';
        targetLabel = 'Front Door';
        eventType = RingEventType.ding;
        initialDescription =
            'Amazon delivery courier standing at your porch placing a cardboard package.';
        break;
      case RingScenarioPreset.nightProwler:
        targetDeviceId = 'ring_cam_backyard';
        targetLabel = 'Backyard';
        eventType = RingEventType.motion;
        initialDescription =
            'Motion detected near backyard fence: A small stray cat moving across the lawn.';
        break;
      case RingScenarioPreset.babyCrying:
        targetDeviceId = 'ring_cam_nursery';
        targetLabel = 'Nursery';
        eventType = RingEventType.motion;
        initialDescription =
            'Movement in nursery: Baby is stirring and sitting up in the crib.';
        break;
      case RingScenarioPreset.carArriving:
        targetDeviceId = 'ring_cam_garage';
        targetLabel = 'Garage Driveway';
        eventType = RingEventType.motion;
        initialDescription =
            'Vehicle entering driveway: Silver sedan parking in front of garage.';
        break;
      case RingScenarioPreset.friendlyNeighbor:
        targetDeviceId = 'ring_cam_front_door';
        targetLabel = 'Front Door';
        eventType = RingEventType.ding;
        initialDescription =
            'Your neighbor Sarah is at the front door waving and smiling.';
        break;
    }

    // تحديث توقيت الجهاز المستهدف
    final index = _devices.indexWhere((d) => d.id == targetDeviceId);
    if (index != -1) {
      final d = _devices[index];
      _devices[index] = d.copyWith(
        lastDingAt: eventType == RingEventType.ding ? DateTime.now() : d.lastDingAt,
        lastMotionAt: eventType == RingEventType.motion ? DateTime.now() : d.lastMotionAt,
      );
      _devicesController.add(List.unmodifiable(_devices));
    }

    final event = RingEvent(
      id: _uuid.v4(),
      deviceId: targetDeviceId,
      deviceLabel: targetLabel,
      type: eventType,
      timestamp: DateTime.now(),
      snapshotBase64: dummyImageBase64,
      scenarioPreset: scenario,
      aiSceneDescription: initialDescription,
    );

    _eventsController.add(event);
    return event;
  }

  @override
  void dispose() {
    _devicesController.close();
    _eventsController.close();
  }
}