// lib/mobile/shell/widgets/two_finger_gesture_detector.dart
import 'dart:developer';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// ملتقط إيماءات مخصص يضمن فوز إيماءات الإصبعين فور هبوطهما معاً
/// ويترك اللمس بإصبع واحد للقوائم والتمرير الداخلي بسلاسة تامة.
class TwoFingerScaleGestureRecognizer extends ScaleGestureRecognizer {
  TwoFingerScaleGestureRecognizer({
    super.debugOwner,
    super.supportedDevices,
    super.allowedButtonsFilter,
  });

  final Set<int> _activePointers = <int>{};
  bool _claimedVictory = false;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _activePointers.add(event.pointer);
    super.addAllowedPointer(event);

    // ⚡ فور هبوط إصبعين على الشاشة، ننتزع الفوز فوراً ونمنع القوائم من سرقة الإيماءة
    if (_activePointers.length >= 2) {
      _claimedVictory = true;
      log('TwoFingerDetector: ✌️ 2 Pointers down! Claiming victory.');
      for (final p in _activePointers) {
        resolvePointer(p, GestureDisposition.accepted);
      }
    }
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      _activePointers.remove(event.pointer);
      if (_activePointers.isEmpty) {
        _claimedVictory = false;
      }
    }
    super.handleEvent(event);
  }

  @override
  void acceptGesture(int pointer) {
    // نقبل الإيماءة إذا كان هناك إصبعان أو تم الفوز مسبقاً
    if (_activePointers.length >= 2 || _claimedVictory) {
      super.acceptGesture(pointer);
    }
    // 🛡️ لا نقوم بعمل rejectGesture هنا حتى لا نقتل الإصبع الأول قبل وصول الثاني!
  }

  @override
  void rejectGesture(int pointer) {
    _activePointers.remove(pointer);
    super.rejectGesture(pointer);
  }
}

/// ودجت بديلة لـ GestureDetector مخصصة للتحكم الفضائي النقي بإصبعين
class TwoFingerGestureDetector extends StatelessWidget {
  const TwoFingerGestureDetector({
    required this.child,
    this.onScaleStart,
    this.onScaleUpdate,
    this.onScaleEnd,
    this.behavior = HitTestBehavior.translucent,
    super.key,
  });

  final Widget child;
  final GestureScaleStartCallback? onScaleStart;
  final GestureScaleUpdateCallback? onScaleUpdate;
  final GestureScaleEndCallback? onScaleEnd;
  final HitTestBehavior behavior;

  @override
  Widget build(BuildContext context) {
    final gestures = <Type, GestureRecognizerFactory>{
      TwoFingerScaleGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<TwoFingerScaleGestureRecognizer>(
        () => TwoFingerScaleGestureRecognizer(debugOwner: this),
        (TwoFingerScaleGestureRecognizer instance) {
          instance
            ..onStart = onScaleStart
            ..onUpdate = onScaleUpdate
            ..onEnd = onScaleEnd
            ..dragStartBehavior = DragStartBehavior.down;
        },
      ),
    };

    return RawGestureDetector(
      gestures: gestures,
      behavior: behavior,
      child: child,
    );
  }
}