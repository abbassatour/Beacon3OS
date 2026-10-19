// lib/core/haptics/haptic_manager.dart
import 'dart:async';
import 'package:flutter/services.dart';

class HapticManager {
  HapticManager._();
  static final HapticManager instance = HapticManager._();

  Timer? _listeningPulseTimer;

  /// 🎛️ حالة تفعيل الاهتزازات التكتيكية (مربوطة لحظياً بقاعدة البيانات)
  bool isEnabled = true;

  /// نبضة خفيفة عند تجاوز عتبة السحب في البوصلة (Detent Click)
  void selectionClick() {
    if (!isEnabled) return;
    HapticFeedback.selectionClick();
  }

  /// 🟢 اجعل النبضة واحدة فقط عند لمس الشاشة بدلاً من Timer دوري يشوش على الميكروفون:
void startListeningPulse() {
  _listeningPulseTimer?.cancel();
  if (!isEnabled) return;
  HapticFeedback.selectionClick(); // نبضة تأكيد واحدة تكفي تماماً
}

  void stopListeningPulse() {
    _listeningPulseTimer?.cancel();
    _listeningPulseTimer = null;
  }

  /// اهتزاز مزدوج يؤكد نجاح العملية
  Future<void> successNotification() async {
    stopListeningPulse();
    if (!isEnabled) return;

    await HapticFeedback.mediumImpact();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.lightImpact();
  }

  /// اهتزاز قوي للتنبيه على حدوث خطأ أو إلغاء أمر
  Future<void> errorAlert() async {
    stopListeningPulse();
    if (!isEnabled) return;

    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.heavyImpact();
  }

  /// نبضات تصاعدية سريعة لحالة الطوارئ SOS (تعمل دائماً كحالة سيادية حرجة)
  Future<void> emergencyAlarmPulse() async {
    stopListeningPulse();
    // 🛡️ استثناء أمني: نبضات الطوارئ تعمل دائماً لتنبيه الكفيف حتى لو عطل الاهتزازات اليومية
    for (var i = 0; i < 3; i++) {
      await HapticFeedback.heavyImpact();
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
  }

  void dispose() {
    stopListeningPulse();
  }
}