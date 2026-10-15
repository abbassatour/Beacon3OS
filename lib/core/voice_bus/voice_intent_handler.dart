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

/// عقد تسجيل الأوامر الصوتية الملحقة (Pluggable Voice Intent Contract)
abstract class VoiceIntentHandler {
  /// المعرف الفريد للنية الصوتية (مثال: 'SAVE_TASK', 'SET_ALARM')
  String get intentId;

  /// أولوية المعالج (الأعلى رقماً يُفحص أولاً في المسار السريع)
  int get priority => 50;

  /// نمط التعبير النمطي للمسار السريع الفوري دون إنترنت (Sub-5ms)
  RegExp? get fastPathPattern => null;

  /// وصف وظيفي واضح بالإنجليزية يُدرج تلقائياً في System Prompt الخاص بـ LLM
  String get llmDescription => '';

  /// أسماء وتوصيفات المعاملات التي يستخرجها الذكاء الاصطناعي (مثل: title, priority)
  Map<String, String> get parameterDescriptions => const {};

  /// الصياغة النصية التلقائية للنية لتعليمها للذكاء الاصطناعي ديناميكياً
  String get promptDocumentation {
    if (llmDescription.isEmpty) {
      return '- "$intentId": Action handled by system module.';
    }
    if (parameterDescriptions.isEmpty) {
      return '- "$intentId": $llmDescription.';
    }
    final paramsFormatted = parameterDescriptions.entries
        .map((e) => '${e.key}: ${e.value}')
        .join(', ');
    return '- "$intentId": $llmDescription. Parameters expected: {$paramsFormatted}.';
  }

  /// فحص هل يستطيع المعالج تنفيذ الأمر بالمسار السريع المحلي
  bool canHandle(VoiceIntentContext context) {
    if (fastPathPattern == null) return false;
    return fastPathPattern!.hasMatch(context.normalizedQuery);
  }

  /// تنفيذ الأمر وتطبيق الأثر على قاعدة البيانات والعتاد
  Future<LauncherCommandResult> execute(
    BuildContext context,
    VoiceIntentContext intentContext,
  );
}