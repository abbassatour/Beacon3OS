// lib/core/voice_bus/voice_intent_handler.dart
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:launcher_repository/launcher_repository.dart';

/// سياق تنفيذ الأمر الصوتي
class VoiceIntentContext {
  const VoiceIntentContext({
    required this.rawQuery,
    required this.normalizedQuery,
    this.base64Image,
    this.llmParameters = const {},
  });

  final String rawQuery;
  final String normalizedQuery;
  final String? base64Image;
  final Map<String, dynamic> llmParameters;
}

/// عقد تسجيل الأوامر الصوتية الملحقة (Pluggable Voice Intent)
abstract class VoiceIntentHandler {
  String get intentId;
  int get priority => 50;
  RegExp? get fastPathPattern => null;

  bool canHandle(VoiceIntentContext context) {
    if (fastPathPattern == null) return false;
    return fastPathPattern!.hasMatch(context.normalizedQuery);
  }

  Future<LauncherCommandResult> execute(
    BuildContext context,
    VoiceIntentContext intentContext,
  );
}