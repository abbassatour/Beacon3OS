// lib/spatial_shell/widgets/corner_swipe_detector.dart
import 'package:flutter/material.dart';

/// ملتقط الإيماءات المائلة من زوايا الهاتف السفلية لاستدعاء المساعد الذكي
class CornerSwipeDetector extends StatefulWidget {
  const CornerSwipeDetector({
    required this.child,
    required this.onCornerSwipe,
    this.cornerWidth = 72.0,
    this.cornerHeight = 96.0,
    super.key,
  });

  final Widget child;
  final VoidCallback onCornerSwipe;
  final double cornerWidth;
  final double cornerHeight;

  @override
  State<CornerSwipeDetector> createState() => _CornerSwipeDetectorState();
}

enum _ActiveCorner { none, bottomLeft, bottomRight }

class _CornerSwipeDetectorState extends State<CornerSwipeDetector> {
  _ActiveCorner _activeCorner = _ActiveCorner.none;
  Offset? _startTouch;
  bool _hasTriggeredInSession = false;

  void _handlePointerDown(PointerDownEvent event) {
    final size = MediaQuery.of(context).size;
    final pos = event.position;

    _hasTriggeredInSession = false;
    _startTouch = pos;

    if (pos.dx <= widget.cornerWidth &&
        pos.dy >= size.height - widget.cornerHeight) {
      _activeCorner = _ActiveCorner.bottomLeft;
    } else if (pos.dx >= size.width - widget.cornerWidth &&
        pos.dy >= size.height - widget.cornerHeight) {
      _activeCorner = _ActiveCorner.bottomRight;
    } else {
      _activeCorner = _ActiveCorner.none;
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_activeCorner == _ActiveCorner.none ||
        _hasTriggeredInSession ||
        _startTouch == null) {
      return;
    }

    final delta = event.position - _startTouch!;
    var triggered = false;

    if (_activeCorner == _ActiveCorner.bottomLeft) {
      if (delta.dx > 28 && delta.dy < -28) {
        triggered = true;
      }
    } else if (_activeCorner == _ActiveCorner.bottomRight) {
      if (delta.dx < -28 && delta.dy < -28) {
        triggered = true;
      }
    }

    if (triggered) {
      _hasTriggeredInSession = true;
      widget.onCornerSwipe();
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    _activeCorner = _ActiveCorner.none;
    _startTouch = null;
    _hasTriggeredInSession = false;
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _activeCorner = _ActiveCorner.none;
    _startTouch = null;
    _hasTriggeredInSession = false;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: widget.child,
    );
  }
}