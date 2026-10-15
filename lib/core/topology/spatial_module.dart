// lib/core/topology/spatial_module.dart
import 'package:beacon_os/core/audio/sound_cue.dart';
import 'package:beacon_os/core/topology/spatial_coordinate.dart';
import 'package:beacon_os/core/voice_bus/voice_intent_handler.dart';
import 'package:flutter/widgets.dart';

/// العقد المعماري الموحد لأي غرفة أو ميزة في نظام BeaconOS (Pluggable Module Contract)
abstract class SpatialModule {
  /// المعرف الفريد للموديول (مثل: 'cockpit', 'focus', 'comms', 'vision', 'agenda')
  String get id;

  /// الاسم الكامل للغرفة
  String get title;

  /// الاسم المختصر للشاشات والـ HUD
  String get shortTitle;

  /// أيقونة الموديول
  IconData get icon;

  /// النغمة الصوتية المميزة للموديول عند التنقل إليه
  SoundCue get sonicSignature;

  /// الموقع الافتراضي للغرفة في الفضاء (X, Y, Floor) عند أول تشغيل
  SpatialCoordinate get defaultCoordinate =>
      const SpatialCoordinate(x: 0, y: 0, floor: 0);

  /// قائمة الأوامر الصوتية التي يجيد هذا الموديول معالجتها
  List<VoiceIntentHandler> get voiceIntents => const [];

  /// تصدير سياق الغرفة اللحظي (بيانات قاعدة البيانات) لإطعام الذكاء الاصطناعي ديناميكياً
  Future<Map<String, dynamic>?> getVoiceContext(BuildContext context) async =>
      null;

  /// فحص هل يدعم الموديول طابقاً معيناً (الأرضي 0، الإعدادات 1، الأرشيف -1)
  bool supportsFloor(int floorLevel);

  /// عنوان الغرفة بحسب رقم الطابق
  String getFloorTitle(int floorLevel) {
    if (floorLevel == 1) return '$shortTitle Settings';
    if (floorLevel == -1) return '$shortTitle Archive';
    return title;
  }

  /// بناء واجهة الغرفة بناءً على رقم الطابق المطلوب
  Widget buildFloorView(BuildContext context, int floorLevel);
}