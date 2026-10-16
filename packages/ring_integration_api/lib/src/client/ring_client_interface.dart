import 'dart:async';
import 'package:ring_integration_api/src/models/ring_device.dart';
import 'package:ring_integration_api/src/models/ring_event.dart';

abstract class RingClientInterface {
  Future<void> initialize();
  Stream<List<RingDevice>> get devicesStream;
  Stream<RingEvent> get eventsStream;

  Future<List<RingDevice>> getDevices();
  Future<RingDevice?> getDeviceById(String deviceId);
  Future<String?> captureSnapshotBase64(String deviceId);
  Future<bool> startTwoWayAudio(String deviceId);
  Future<bool> stopTwoWayAudio(String deviceId);

  // أدوات تحكم خاصة بالمحاكاة والتجربة أمام لجان التحكيم
  Future<RingEvent> triggerSimulatedScenario(RingScenarioPreset scenario);
  void dispose();
}