// lib/main_firetv.dart
import 'package:beacon_os/bootstrap.dart';

/// نقطة الدخول الرسمية لشاشات التلفاز وأجهزة Fire TV
Future<void> main() async {
  await bootstrap(target: DeviceTarget.tv);
}