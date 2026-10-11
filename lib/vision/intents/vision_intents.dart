// lib/vision/intents/vision_intents.dart
import 'package:beacon_os/core/services/camera_service.dart';
import 'package:beacon_os/core/voice_bus/voice_bus.dart'; // 👈 السطر المضاف الذي يحل الخطأ
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';

/// معالج استكشاف المحيط والعوائق عبر الكاميرا
class DescribeSceneIntentHandler extends VoiceIntentHandler {
  @override
  String get intentId => 'DESCRIBE_SCENE';

  @override
  int get priority => 90;

  @override
  RegExp get fastPathPattern => RegExp(
        r'^(?:look|see|what is in front of me|describe scene|what do you see|inspect scene)',
        caseSensitive: false,
      );

  @override
  Future<LauncherCommandResult> execute(
    BuildContext context,
    VoiceIntentContext intentContext,
  ) async {
    final assistantRepo = context.read<AssistantRepository>();
    final settingsRepo = context.read<SettingsRepository>();

    String? base64Image = intentContext.base64Image;
    if (base64Image == null || base64Image.isEmpty) {
      base64Image = await CameraService.instance.captureAsBase64();
    }

    if (base64Image == null || base64Image.isEmpty) {
      return const LauncherCommandResult(
        intent: 'DESCRIBE_SCENE_FAILED',
        spokenResponse:
            'Camera capture failed. Please try holding the phone steady.',
      );
    }

    final settings = await settingsRepo.getSettings();
    final isDetailed = settings.visionInspectionDetail == 'detailed';

    final prompt = isDetailed
        ? 'You are the digital eyes for a blind person. Provide a thorough, structured description of the entire scene in front of them: room layout, people, spatial distance to key objects, and any immediate ground hazards.'
        : 'You are the digital eyes for a blind person. In 1 to 2 clear, concise sentences, describe what is directly in front of them and highlight any immediate obstacles or walking hazards.';

    final spokenResult = await assistantRepo.analyzeVisionFrame(
      base64Image: base64Image,
      prompt: prompt,
    );

    return LauncherCommandResult(
      intent: 'DESCRIBE_SCENE',
      spokenResponse: spokenResult,
    );
  }
}

/// معالج قراءة النصوص واللافتات والوثائق المطبوعة
class ReadTextVisionIntentHandler extends VoiceIntentHandler {
  @override
  String get intentId => 'READ_DOCUMENT_TEXT';

  @override
  int get priority => 85;

  @override
  RegExp get fastPathPattern => RegExp(
        r'^(?:read this|read text|read document|read paper|read sign)',
        caseSensitive: false,
      );

  @override
  Future<LauncherCommandResult> execute(
    BuildContext context,
    VoiceIntentContext intentContext,
  ) async {
    final assistantRepo = context.read<AssistantRepository>();

    String? base64Image = intentContext.base64Image;
    if (base64Image == null || base64Image.isEmpty) {
      base64Image = await CameraService.instance.captureAsBase64();
    }

    if (base64Image == null || base64Image.isEmpty) {
      return const LauncherCommandResult(
        intent: 'READ_DOCUMENT_FAILED',
        spokenResponse: 'Could not capture document image.',
      );
    }

    final spokenResult = await assistantRepo.analyzeVisionFrame(
      base64Image: base64Image,
      prompt:
          'Read all visible text, document headings, signs, or labels in this image clearly and concisely.',
    );

    return LauncherCommandResult(
      intent: 'READ_DOCUMENT_TEXT',
      spokenResponse: spokenResult,
    );
  }
}

/// معالج التعرف على العملات والنقود الورقية والمعدنية
class IdentifyCurrencyIntentHandler extends VoiceIntentHandler {
  @override
  String get intentId => 'IDENTIFY_CURRENCY';

  @override
  int get priority => 85;

  @override
  RegExp get fastPathPattern => RegExp(
        r'^(?:what money is this|identify currency|read cash|read banknote|count money)',
        caseSensitive: false,
      );

  @override
  Future<LauncherCommandResult> execute(
    BuildContext context,
    VoiceIntentContext intentContext,
  ) async {
    final assistantRepo = context.read<AssistantRepository>();
    final settingsRepo = context.read<SettingsRepository>();

    String? base64Image = intentContext.base64Image;
    if (base64Image == null || base64Image.isEmpty) {
      base64Image = await CameraService.instance.captureAsBase64();
    }

    if (base64Image == null || base64Image.isEmpty) {
      return const LauncherCommandResult(
        intent: 'IDENTIFY_CURRENCY_FAILED',
        spokenResponse: 'Could not capture currency frame.',
      );
    }

    final settings = await settingsRepo.getSettings();
    final currencyPref = settings.preferredCurrency;

    final spokenResult = await assistantRepo.analyzeVisionFrame(
      base64Image: base64Image,
      prompt:
          'Identify the banknotes or coins visible in this image. Pay special attention to $currencyPref. State the exact currency name and total denomination value clearly.',
    );

    return LauncherCommandResult(
      intent: 'IDENTIFY_CURRENCY',
      spokenResponse: spokenResult,
    );
  }
}