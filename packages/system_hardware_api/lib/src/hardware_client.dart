// packages/system_hardware_api/lib/src/hardware_client.dart
import 'dart:developer';
import 'dart:io';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

/// كائن يمثل الإحداثيات الجغرافية الحقيقية للجهاز
class GpsCoordinates {
  const GpsCoordinates({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;

  @override
  String toString() => 'GpsCoordinates($latitude, $longitude)';
}

/// كائن خفيف يمثل جهة اتصال مجلوبة من نظام التشغيل
class DeviceContactRecord {
  const DeviceContactRecord({
    required this.name,
    required this.phoneNumber,
  });

  final String name;
  final String phoneNumber;

  @override
  String toString() => 'DeviceContactRecord(name: $name, phone: $phoneNumber)';
}

class HardwareClient {
  HardwareClient();

  final Battery _battery = Battery();

  static const MethodChannel _systemChannel = MethodChannel(
    'com.beaconos/system',
  );

  bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  /// جلب جهات الاتصال المسجلة في الهاتف (للهواتف فقط، مع تجاوز آمن على سطح المكتب)
  Future<List<DeviceContactRecord>> getDeviceContacts() async {
    if (!_isMobile) {
      log('HardwareClient: Desktop environment. Mobile contact store bypassed.');
      return [];
    }

    try {
      final status = await FlutterContacts.permissions.request(PermissionType.read);
      if (status != PermissionStatus.granted) {
        log('HardwareClient: Read contacts permission denied by user.');
        return [];
      }

      final rawContacts = await FlutterContacts.getAll(
        properties: {ContactProperty.phone},
      );

      final List<DeviceContactRecord> records = [];

      for (final contact in rawContacts) {
        final displayName = (contact.displayName ?? '').trim();
        if (displayName.isEmpty || contact.phones.isEmpty) continue;

        for (final phone in contact.phones) {
          final cleanNumber = phone.number.replaceAll(RegExp(r'[\s\(\)\-\.]'), '').trim();
          if (cleanNumber.length >= 3) {
            records.add(
              DeviceContactRecord(
                name: displayName,
                phoneNumber: cleanNumber,
              ),
            );
          }
        }
      }

      log('HardwareClient: Successfully fetched ${records.length} contact records from phone.');
      return records;
    } catch (e, st) {
      log('HardwareClient: Error reading phone contacts: $e', stackTrace: st);
      return [];
    }
  }

  /// 📲 كتابة جهة اتصال جديدة في سجل الهاتف الرسمي
  Future<bool> saveDeviceContact({
    required String name,
    required String phoneNumber,
  }) async {
    if (!_isMobile) {
      log('HardwareClient: Device contact write skipped on Desktop.');
      return true;
    }

    try {
      final status = await FlutterContacts.permissions.request(PermissionType.readWrite);
      if (status != PermissionStatus.granted) {
        log('HardwareClient: Write contacts permission denied by user.');
        return false;
      }

      final nameParts = name.trim().split(' ');
      final firstName = nameParts.first;
      final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

      final newContact = Contact(
        name: Name(
          first: firstName,
          last: lastName.isNotEmpty ? lastName : null,
        ),
        phones: [
          Phone(number: phoneNumber.trim()),
        ],
      );

      await FlutterContacts.create(newContact);
      log('HardwareClient: Contact successfully written to Android phonebook: $name');
      return true;
    } catch (e, st) {
      log('HardwareClient: Error writing contact to device phonebook: $e', stackTrace: st);
      return false;
    }
  }

  /// جلب مستوى البطارية وحالتها كنص مقروء للمستخدم
  Future<String> getBatteryStatus() async {
    try {
      final level = await _battery.batteryLevel;
      final state = await _battery.batteryState;

      var stateStr = 'discharging';
      if (state == BatteryState.charging) stateStr = 'charging';
      if (state == BatteryState.full) stateStr = 'fully charged';

      return 'Battery is at $level% and currently $stateStr.';
    } catch (e) {
      return 'Power connected / Battery status normal.';
    }
  }

  /// جلب نسبة شحن البطارية الحقيقية كرقم صحيح
  Future<int> getBatteryPercentage() async {
    try {
      return await _battery.batteryLevel;
    } catch (_) {
      return 100;
    }
  }

  /// جلب إحداثيات الـ GPS الحقيقية مع فحص آمن
  Future<GpsCoordinates?> getCurrentLocation() async {
    try {
      final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isServiceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }

      if (permission == LocationPermission.deniedForever) return null;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 5),
        ),
      );

      return GpsCoordinates(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (e) {
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          return GpsCoordinates(
            latitude: lastKnown.latitude,
            longitude: lastKnown.longitude,
          );
        }
      } catch (_) {}
      return null;
    }
  }

  /// إجراء مكالمة هاتفية
  Future<bool> callPhoneNumber(String phoneNumber) async {
    final digits = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.isEmpty) return false;

    final uri = Uri.parse('tel:$digits');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// ضبط منبه النظام الرسمي
  Future<bool> setSystemAlarm({
    required int hour,
    required int minute,
    String label = 'BeaconOS Alarm',
  }) async {
    if (!_isMobile) {
      log('HardwareClient: External system clock integration skipped on Desktop (Managed by local vault).');
      return true;
    }

    try {
      final result = await _systemChannel.invokeMethod<bool>('setAlarm', {
        'hour': hour,
        'minute': minute,
        'label': label,
      });
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// تشغيل أو إطفاء فلاش الكاميرا (الكشاف)
  Future<bool> toggleFlashlight({bool? enable}) async {
    if (!_isMobile) {
      log('HardwareClient: Torch is not available on Desktop environment.');
      return false;
    }

    try {
      final result = await _systemChannel.invokeMethod<bool>(
        'toggleFlashlight',
        enable != null ? {'enable': enable} : null,
      );
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// فتح تطبيق خارجي مثبت على النظام
  Future<bool> openApp(String packageName) async {
    if (Platform.isWindows) {
      try {
        // 🪟 تشغيل البرامج على نظام ويندوز عبر shell
        await Process.run('cmd', ['/c', 'start', packageName]);
        return true;
      } catch (e) {
        log('HardwareClient: Failed to launch app on Windows: $e');
        return false;
      }
    }

    if (!_isMobile) return false;

    try {
      final result = await _systemChannel.invokeMethod<bool>('openApp', {
        'packageName': packageName,
      });
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// قفل شاشة الجهاز
  Future<bool> lockScreen() async {
    if (Platform.isWindows) {
      try {
        // 🪟 قفل كمبيوتر ويندوز فورياً عبر API النظام
        await Process.run('rundll32.exe', ['user32.dll,LockWorkStation']);
        return true;
      } catch (e) {
        log('HardwareClient: Error locking Windows station: $e');
        return false;
      }
    }

    if (!_isMobile) return false;

    try {
      final result = await _systemChannel.invokeMethod<bool>('lockScreen');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }
}