// lib/mobile/shell/widgets/two_finger_gesture_detector.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// ملتقط إيماءات مخصص يرفض المنافسة بإصبع واحد لترك القوائم تعمل بحرية،
/// ويقبل المنافسة فقط عندما يلمس الشاشة إصبعان أو أكثر.
class TwoFingerScaleGestureRecognizer extends ScaleGestureRecognizer {
  TwoFingerScaleGestureRecognizer({
    super.debugOwner,
    super.supportedDevices,
  });

  final Map<int, Offset> _pointers = <int, Offset>{};

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _pointers[event.pointer] = event.position;
    super.addAllowedPointer(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      _pointers[event.pointer] = event.position;
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      _pointers.remove(event.pointer);
    }

    // 🛡️ شرط حلبة الإيماءات الصارم:
    // إذا كان هناك أقل من إصبعين على الشاشة، لا تسمح للملتقط بالفوز أو حجز اللمس
    if (_pointers.length < 2) {
      stopTrackingIfPointerNoLongerDown(event);
      return;
    }

    super.handleEvent(event);
  }

  @override
  void acceptGesture(int pointer) {
    // نقبل الإيماءة فقط إذا كان هناك إصبعان على الأقل
    if (_pointers.length >= 2) {
      super.acceptGesture(pointer);
    }
  }

  @override
  void rejectGesture(int pointer) {
    _pointers.remove(pointer);
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
            ..onEnd = onScaleEnd;
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