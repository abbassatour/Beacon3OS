// packages/launcher_repository/lib/src/domains/safety_radar_repository.dart
import 'dart:async';
import 'dart:developer';

import 'package:cloud_sync_api/cloud_sync_api.dart';
import 'package:drift/drift.dart';
import 'package:equatable/equatable.dart';
import 'package:local_vault_api/local_vault_api.dart' as db;
import 'package:system_hardware_api/system_hardware_api.dart';

/// كائن يمثل سجل استغاثة طوارئ موثق في الخزنة وعلى البلوكتشين
class SosAlertRecord extends Equatable {
  const SosAlertRecord({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.batteryLevel,
    required this.status,
    required this.googleMapsUrl,
    required this.triggeredAt,
  });

  final String id;
  final double latitude;
  final double longitude;
  final int batteryLevel;
  final String status;
  final String googleMapsUrl;
  final DateTime triggeredAt;

  @override
  List<Object?> get props => [
        id,
        latitude,
        longitude,
        batteryLevel,
        status,
        googleMapsUrl,
        triggeredAt,
      ];
}

abstract class SafetyRadarRepository {
  /// 🚨 إطلاق نداء الاستغاثة والطوارئ
  Future<String> triggerEmergencySos({
    double? latitude,
    double? longitude,
    int? batteryLevel,
  });

  /// 📜 مراقبة سجل استغاثات الطوارئ SOS التاريخية
  Stream<List<SosAlertRecord>> watchSosHistory();

  /// 🚨 تنفيذ بروتوكول وميض الكشاف والاهتزاز لتحديد موقع الهاتف محلياً
  Future<void> executeLocateDevice({int pulseCycles = 8});

  /// 🔍 تسجيل معالج إضافي (صوتي/اهتزازي) عند تحديد موقع الهاتف
  void registerLocateHandler(Future<void> Function() handler);

  /// 🛑 إلغاء تسجيل معالج تحديد الموقع
  void unregisterLocateHandler();

  /// 🔍 إرسال طلب تحديد موقع الهاتف من شاشة التلفزيون أو الكمبيوتر (Local-First)
  Future<bool> requestLocatePhone({String reason = 'Living room request'});
}

class SafetyRadarRepositoryImpl implements SafetyRadarRepository {
  SafetyRadarRepositoryImpl({
    required db.AppDatabase database,
    required HardwareClient hardware,
    required HybridSyncClient hybridSync,
  })  : _db = database,
        _hardware = hardware,
        _hybridSync = hybridSync;

  final db.AppDatabase _db;
  final HardwareClient _hardware;
  final HybridSyncClient _hybridSync;

  Future<void> Function()? _locateHandler;
  bool _isLocating = false;

  @override
  void registerLocateHandler(Future<void> Function() handler) {
    _locateHandler = handler;
  }

  @override
  void unregisterLocateHandler() {
    _locateHandler = null;
  }

  @override
  Future<void> executeLocateDevice({int pulseCycles = 8}) async {
    if (_isLocating) return;
    _isLocating = true;

    log('SafetyRadarRepository: 📢 Locating Device: Triggering audio siren, haptics & flashlight strobe...');

    // تشغيل المعالج الصوتي والاهتزازي (يتم تمريره من واجهة المستخدم)
    if (_locateHandler != null) {
      unawaited(_locateHandler!().catchError((Object err) {
        log('SafetyRadarRepository: Custom locate handler note: $err');
      }));
    }

    // وميض كشاف الهاتف
    try {
      for (var i = 0; i < pulseCycles; i++) {
        await _hardware.toggleFlashlight(enable: true);
        await Future<void>.delayed(const Duration(milliseconds: 180));
        await _hardware.toggleFlashlight(enable: false);
        await Future<void>.delayed(const Duration(milliseconds: 180));
      }
    } catch (e) {
      log('SafetyRadarRepository: Hardware locator strobe error: $e');
    } finally {
      await _hardware.toggleFlashlight(enable: false).catchError((_) => false);
      _isLocating = false;
    }
  }

  @override
  Future<bool> requestLocatePhone({String reason = 'Living room request'}) async {
    return _hybridSync.dispatchLocatePhone(reason: reason);
  }

  @override
  Future<String> triggerEmergencySos({
    double? latitude,
    double? longitude,
    int? batteryLevel,
  }) async {
    final settings = await _db.getSettings();
    final shareGps = settings.shareGpsOnSos;
    final actualBattery = batteryLevel ?? await _hardware.getBatteryPercentage();

    double actualLat = latitude ?? 0.0;
    double actualLng = longitude ?? 0.0;

    // جلب الإحداثيات إن لم تكن ممررة وكانت الصلاحية موجودة ومفعلة
    if (shareGps && (latitude == null || longitude == null)) {
      final coords = await _hardware.getCurrentLocation();
      if (coords != null) {
        actualLat = coords.latitude;
        actualLng = coords.longitude;
      }
    }

    final effectiveLat = shareGps ? actualLat : 0.0;
    final effectiveLng = shareGps ? actualLng : 0.0;

    final googleMapsUrl = (shareGps && effectiveLat != 0.0 && effectiveLng != 0.0)
        ? 'https://maps.google.com/?q=$effectiveLat,$effectiveLng'
        : (shareGps
            ? 'GPS Unavailable (Searching satellites...)'
            : 'GPS Sharing Disabled');

    log('SafetyRadarRepository: SOS Triggered! Lat: $effectiveLat, Lng: $effectiveLng, Battery: $actualBattery%');

    // حفظها في الخزنة المحلية
    final alertId = await _db.insertSosAlert(
      latitude: effectiveLat,
      longitude: effectiveLng,
      batteryLevel: actualBattery,
      googleMapsUrl: googleMapsUrl,
    );

    // بثها عبر الـ Mesh Network للديسكتوب والتلفزيون (LAN)
    await _hybridSync.dispatchEmergencySos(
      latitude: effectiveLat,
      longitude: effectiveLng,
      batteryLevel: actualBattery,
    );

    // الاتصال الفوري بجهة اتصال الطوارئ إن كانت مفعلة
    if (settings.autoDialEmergency) {
      final emergencyContacts = await _db.getEmergencyContacts();
      if (emergencyContacts.isNotEmpty) {
        final primary = emergencyContacts.first;
        await _hardware.callPhoneNumber(primary.phoneNumber);
      }
    }

    return alertId;
  }

  @override
  Stream<List<SosAlertRecord>> watchSosHistory() {
    return (_db.select(_db.sosAlerts)
          ..where((s) => s.deletedAt.isNull())
          ..orderBy([(s) => OrderingTerm.desc(s.triggeredAt)]))
        .watch()
        .map((rows) => rows
            .map((r) => SosAlertRecord(
                  id: r.id,
                  latitude: r.latitude,
                  longitude: r.longitude,
                  batteryLevel: r.batteryLevel,
                  status: r.status,
                  googleMapsUrl: r.googleMapsUrl,
                  triggeredAt: r.triggeredAt,
                ))
            .toList());
  }
}