// lib/mobile/shell/widgets/tactile_multi_touch_detector.dart
import 'dart:async';

import 'package:beacon_os/core/audio/sound_controller.dart';
import 'package:flutter/widgets.dart';

/// ملتقط اللمسات المتعددة الحسي المخصص لإيماءات المكفوفين ونظام الطوارئ.
///
/// يدير بأمان:
/// - ثلاث نقرات سريعة: نداء استغاثة الطوارئ SOS.
/// - ضغط مطول بإصبع واحد (> 650ms): استدعاء المساعد الصوتي دون اعتراض نقرات القوائم.
/// - نقرتان بإصبعين: إعلان الموقع والمستوى الحالي (Orientation Ping).
/// - سحب بثلاثة أصابع: مصعد الطوابق السريع (اختياري).
class TactileMultiTouchDetector extends StatefulWidget {
  const TactileMultiTouchDetector({
    required this.child,
    this.onTripleTapSos,
    this.onOrientationPing,
    this.onThreeFingerSwipeUp,
    this.onThreeFingerSwipeDown,
    this.onHoldToSpeakStart,
    this.onHoldToSpeakEnd,
    this.onHoldToSpeakCancel,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTripleTapSos;
  final VoidCallback? onOrientationPing;
  final VoidCallback? onThreeFingerSwipeUp;
  final VoidCallback? onThreeFingerSwipeDown;
  final VoidCallback? onHoldToSpeakStart;
  final VoidCallback? onHoldToSpeakEnd;
  final VoidCallback? onHoldToSpeakCancel;

  @override
  State<TactileMultiTouchDetector> createState() =>
      _TactileMultiTouchDetectorState();
}

class _TactileMultiTouchDetectorState extends State<TactileMultiTouchDetector> {
  // ⏱️ معايير التوقيت الصناعية لفك التداخل
  static const Duration _holdToSpeakTimeout = Duration(milliseconds: 650);
  static const Duration _singleTapMaxInterval = Duration(milliseconds: 420);
  static const Duration _twoFingerTapMaxInterval = Duration(milliseconds: 450);
  static const double _holdCancelSlop = 8.5; // إلغاء فوري عند بدء تمرير القوائم

  int _activePointers = 0;
  final Map<int, double> _threeFingerStartPointers = {};
  bool _threeFingerActionFired = false;

  Timer? _holdToSpeakTimer;
  bool _isHoldingToSpeak = false;
  Offset? _pointerDownPos;

  DateTime? _twoFingerTapStartTime;
  int _twoFingerTapCount = 0;
  DateTime? _lastTwoFingerTapTime;
  bool _hasTwoFingerMoved = false;

  int _singleTapCount = 0;
  DateTime? _lastSingleTapTime;

  @override
  void dispose() {
    _holdToSpeakTimer?.cancel();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    _activePointers++;
    _pointerDownPos = event.position;

    if (_activePointers <= 3) {
      _threeFingerStartPointers[event.pointer] = event.position.dy;
    }

    if (_activePointers == 3) {
      _holdToSpeakTimer?.cancel();
      _singleTapCount = 0; // 👈 تصفير
      SoundController.instance.stopSpatialRadar();
      _threeFingerActionFired = false;
    } else if (_activePointers >= 2) {
      // 🛡️ فور وجود إصبعين فأكثر، نقوم بتصفير عداد نقرات الـ SOS لمنع الإنذار الكاذب!
      _singleTapCount = 0;
      _holdToSpeakTimer?.cancel();
      if (_isHoldingToSpeak) {
        _isHoldingToSpeak = false;
        widget.onHoldToSpeakCancel?.call();
      }
      _twoFingerTapStartTime = DateTime.now();
      _hasTwoFingerMoved = false;
    } else if (_activePointers == 1) {
      final now = DateTime.now();
      if (_lastSingleTapTime == null ||
          now.difference(_lastSingleTapTime!).inMilliseconds >
              _singleTapMaxInterval.inMilliseconds) {
        _singleTapCount = 1;
      } else {
        _singleTapCount++;
      }
      _lastSingleTapTime = now;

      // 🚨 رصد ثلاث نقرات سريعة لنداء الطوارئ SOS
      if (_singleTapCount == 3) {
        _holdToSpeakTimer?.cancel();
        _isHoldingToSpeak = false;
        SoundController.instance.stopSpatialRadar();
        widget.onTripleTapSos?.call();
        _singleTapCount = 0;
        return;
      }

      // ضغط مطول للمساعد الصوتي
      _holdToSpeakTimer?.cancel();
      _holdToSpeakTimer = Timer(_holdToSpeakTimeout, () {
        if (_activePointers == 1) {
          _isHoldingToSpeak = true;
          SoundController.instance.stopSpatialRadar();
          widget.onHoldToSpeakStart?.call();
        }
      });
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    // معالجة إيماءات الثلاثة أصابع
    if (_activePointers == 3 && !_threeFingerActionFired) {
      final startY = _threeFingerStartPointers[event.pointer];
      if (startY != null) {
        final deltaY = event.position.dy - startY;
        if (deltaY < -75.0) {
          _threeFingerActionFired = true;
          widget.onThreeFingerSwipeUp?.call();
          return;
        } else if (deltaY > 75.0) {
          _threeFingerActionFired = true;
          widget.onThreeFingerSwipeDown?.call();
          return;
        }
      }
    }

    // إذا تحرك الإصبعان أكثر من 3.5 بكسل، فهو سحب فضائي للتنقل -> إلغاء النقر المزدوج
    if (_activePointers >= 2 && event.delta.distance > 3.5) {
      _hasTwoFingerMoved = true;
    }

    // إلغاء مؤقت المساعد الصوتي فوراً إذا تحرك الإصبع للتمرير أو السحب
    if (!_isHoldingToSpeak && _pointerDownPos != null) {
      final moved = (event.position - _pointerDownPos!).distance;
      if (moved > _holdCancelSlop) {
        _holdToSpeakTimer?.cancel();
      }
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _threeFingerStartPointers.remove(event.pointer);
    _holdToSpeakTimer?.cancel();

    if (_isHoldingToSpeak) {
      _isHoldingToSpeak = false;
      widget.onHoldToSpeakEnd?.call();
    } else if (_activePointers == 2 && _twoFingerTapStartTime != null) {
      final tapDuration = DateTime.now().difference(_twoFingerTapStartTime!);
      // شرط الحماية: يجب ألا يكون الإصبعان قد تحركا كسحب فضائي
      if (!_hasTwoFingerMoved && tapDuration.inMilliseconds < 350) {
        final now = DateTime.now();
        if (_lastTwoFingerTapTime == null ||
            now.difference(_lastTwoFingerTapTime!).inMilliseconds >
                _twoFingerTapMaxInterval.inMilliseconds) {
          _twoFingerTapCount = 1;
        } else {
          _twoFingerTapCount++;
        }
        _lastTwoFingerTapTime = now;

        if (_twoFingerTapCount == 2) {
          _twoFingerTapCount = 0;
          widget.onOrientationPing?.call();
        }
      }
    }

    _activePointers = (_activePointers - 1).clamp(0, 10);
    if (_activePointers == 0) {
      _hasTwoFingerMoved = false;
      _pointerDownPos = null;
      _threeFingerActionFired = false;
      _threeFingerStartPointers.clear();
      SoundController.instance.stopSpatialRadar();
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _holdToSpeakTimer?.cancel();
    if (_isHoldingToSpeak) {
      _isHoldingToSpeak = false;
      widget.onHoldToSpeakCancel?.call();
    }
    _activePointers = (_activePointers - 1).clamp(0, 10);
    _pointerDownPos = null;
    _threeFingerActionFired = false;
    _threeFingerStartPointers.clear();
    SoundController.instance.stopSpatialRadar();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: widget.child,
    );
  }
}