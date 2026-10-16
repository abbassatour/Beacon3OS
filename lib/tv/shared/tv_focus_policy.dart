// lib/tv/shared/tv_focus_policy.dart
import 'package:flutter/material.dart';

/// يضمن حركة حتمية لمؤشر التحديد (D-Pad) بين خلايا شبكة 2x2 دون أن يعلق الفوكس أو يقفز عشوائياً
class TvGridFocusScope extends StatelessWidget {
  const TvGridFocusScope({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: child,
    );
  }
}