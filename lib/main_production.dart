// lib/main_production.dart
import 'package:beacon_os/bootstrap.dart';

Future<void> main() async {
  await bootstrap(flavor: AppFlavor.production);
}