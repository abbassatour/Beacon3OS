// lib/main_staging.dart
import 'package:beacon_os/bootstrap.dart';

Future<void> main() async {
  await bootstrap(flavor: AppFlavor.staging);
}