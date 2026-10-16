// lib/main_windows.dart
import 'package:beacon_os/bootstrap.dart';

/// نقطة الدخول الرسمية لنسخة سطح المكتب (Windows / Desktop Command Center)
Future<void> main() async {
  await bootstrap(target: DeviceTarget.desktop);
}