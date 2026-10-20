// lib/core/services/background_sync_worker.dart
import 'dart:developer';
import 'package:beacon_os/core/constants/api_constants.dart';
import 'package:cloud_sync_api/cloud_sync_api.dart';
import 'package:flutter/widgets.dart';
import 'package:launcher_repository/launcher_repository.dart';
import 'package:local_vault_api/local_vault_api.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';

const String beaconPeriodicSyncTask = 'com.beaconos.periodic_vault_sync';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    log('WorkManager: 🌙 Starting background headless vault sync...');
    WidgetsFlutterBinding.ensureInitialized();

    try {
      // 1. تهيئة Supabase داخل بيئة العازل المنفصلة إذا كانت البيانات متوفرة
      if (ApiConstants.supabaseUrl.isNotEmpty && ApiConstants.supabaseAnonKey.isNotEmpty) {
        try {
          await Supabase.initialize(
            url: ApiConstants.supabaseUrl,
            anonKey: ApiConstants.supabaseAnonKey,
          );
        } catch (_) {}
      }

      final db = AppDatabase();
      final cloud = CloudSyncClient();

      if (!cloud.isAuthenticated) {
        log('WorkManager: User unauthenticated / offline-first. Skipping cloud sync.');
        return true;
      }

      // 2. مزامنة التغييرات المعلقة واستعادة البيانات بالترتيب الزمني LWW
      final repo = LauncherRepository(
        database: db,
        cloudSyncClient: cloud,
      );

      await repo.syncPendingOfflineChanges();
      await repo.restoreVaultFromCloud();

      log('WorkManager: ✅ Background sync completed successfully.');
      return true;
    } catch (e, st) {
      log('WorkManager: ❌ Background sync task failed: $e', stackTrace: st);
      return false;
    }
  });
}