// packages/launcher_repository/lib/src/domains/system_hardware_repository.dart
import 'package:system_hardware_api/system_hardware_api.dart';

export 'package:system_hardware_api/system_hardware_api.dart'
    show DeviceContactRecord, GpsCoordinates;

abstract class SystemHardwareRepository {
  Future<String> getBatteryStatus();
  Future<int> getBatteryPercentage();
  Future<GpsCoordinates?> getCurrentLocation();
  Future<List<DeviceContactRecord>> getDeviceContacts();
  Future<bool> saveDeviceContact({required String name, required String phoneNumber});
  Future<bool> toggleFlashlight({bool? enable});
  Future<bool> lockScreen();
  Future<bool> openApp(String packageNameOrCommonName);
  Future<bool> callPhoneNumber(String phoneNumber);
}

class SystemHardwareRepositoryImpl implements SystemHardwareRepository {
  SystemHardwareRepositoryImpl({HardwareClient? hardwareClient})
      : _hardware = hardwareClient ?? HardwareClient();

  final HardwareClient _hardware;

  static const Map<String, String> _knownAppPackages = {
    'whatsapp': 'com.whatsapp',
    'youtube': 'com.google.android.youtube',
    'chrome': 'com.android.chrome',
    'browser': 'com.android.chrome',
    'settings': 'com.android.settings',
    'camera': 'com.google.android.GoogleCamera',
    'spotify': 'com.spotify.music',
    'telegram': 'org.telegram.messenger',
    'gmail': 'com.google.android.gm',
    'maps': 'com.google.android.apps.maps',
    'phone': 'com.google.android.dialer',
  };

  @override
  Future<List<DeviceContactRecord>> getDeviceContacts() =>
      _hardware.getDeviceContacts();

  @override
  Future<bool> saveDeviceContact({
    required String name,
    required String phoneNumber,
  }) =>
      _hardware.saveDeviceContact(name: name, phoneNumber: phoneNumber);

  @override
  Future<String> getBatteryStatus() => _hardware.getBatteryStatus();

  @override
  Future<int> getBatteryPercentage() => _hardware.getBatteryPercentage();

  @override
  Future<GpsCoordinates?> getCurrentLocation() =>
      _hardware.getCurrentLocation();

  @override
  Future<bool> toggleFlashlight({bool? enable}) =>
      _hardware.toggleFlashlight(enable: enable);

  @override
  Future<bool> lockScreen() => _hardware.lockScreen();

  @override
  Future<bool> openApp(String packageNameOrCommonName) {
    final key = packageNameOrCommonName.trim().toLowerCase();
    final targetPackage = _knownAppPackages[key] ?? packageNameOrCommonName;
    return _hardware.openApp(targetPackage);
  }

  @override
  Future<bool> callPhoneNumber(String phoneNumber) =>
      _hardware.callPhoneNumber(phoneNumber);
}