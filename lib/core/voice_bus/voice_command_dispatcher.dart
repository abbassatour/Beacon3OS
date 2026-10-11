// lib/core/voice_bus/voice_command_dispatcher.dart
import 'dart:developer';
import 'package:beacon_os/core/audio/sound_controller.dart';
import 'package:beacon_os/core/audio/sound_cue.dart';
import 'package:beacon_os/core/haptics/haptic_manager.dart';
import 'package:beacon_os/core/topology/spatial_topology.dart';
import 'package:beacon_os/core/voice_bus/voice_intent_handler.dart';
import 'package:flutter/widgets.dart';
import 'package:launcher_repository/launcher_repository.dart';

/// حافلة توجيه الأوامر الصوتية الذكية (Two-Tier Pluggable Voice Intent Bus)
class VoiceCommandDispatcher {
  VoiceCommandDispatcher({
    required SpatialTopology topology,
    required AssistantRepository assistantRepository,
    GlobalKey<NavigatorState>? navigatorKey,
    SoundController? soundController,
    HapticManager? hapticManager,
  })  : _topology = topology,
        _assistant = assistantRepository,
        _navigatorKey = navigatorKey,
        _sound = soundController ?? SoundController.instance,
        _haptics = hapticManager ?? HapticManager.instance;

  final SpatialTopology _topology;
  final AssistantRepository _assistant;
  final GlobalKey<NavigatorState>? _navigatorKey;
  final SoundController _sound;
  final HapticManager _haptics;

  List<VoiceIntentHandler> get _registeredHandlers {
    final handlers = <VoiceIntentHandler>[];
    for (final module in _topology.allModules) {
      handlers.addAll(module.voiceIntents);
    }
    handlers.sort((a, b) => b.priority.compareTo(a.priority));
    return handlers;
  }

  Future<LauncherCommandResult> dispatch(
    String rawQuery, {
    String? base64Image,
    BuildContext? context,
    Map<String, dynamic>? systemContext,
  }) async {
    final effectiveContext = context ?? _navigatorKey?.currentContext;
    final normalized = rawQuery.trim().toLowerCase();

    final intentContext = VoiceIntentContext(
      rawQuery: rawQuery.trim(),
      normalizedQuery: normalized,
      base64Image: base64Image,
    );

    final handlers = _registeredHandlers;

    // ⚡ المستوى 1: المسار السريع الفوري (Sub-5ms Fast Path)
    for (final handler in handlers) {
      if (handler.canHandle(intentContext)) {
        log('VoiceDispatcher: ⚡ Fast-path matched [${handler.intentId}] for query: "$rawQuery"');
        if (effectiveContext != null) {
          try {
            return await handler.execute(effectiveContext, intentContext);
          } catch (e, st) {
            log('VoiceDispatcher: Error executing fast-path [${handler.intentId}]: $e',
                stackTrace: st);
          }
        }
      }
    }

    // 🧠 المستوى 2: المعالجة التوليدية بالذكاء الاصطناعي (Gemini 2.0 Flash)
    log('VoiceDispatcher: 🧠 Invoking Gemini 2.0 Multimodal...');
    try {
      final llmResult = await _assistant.processLlmCommand(
        userCommand: rawQuery,
        base64Image: base64Image,
        systemContext: systemContext,
      );

      final intentName = llmResult['intent'] as String? ?? 'GENERAL_CHAT';
      final spokenResponse =
          llmResult['spoken_response'] as String? ?? 'Done.';
      final parameters = llmResult['parameters'] is Map
          ? Map<String, dynamic>.from(llmResult['parameters'] as Map)
          : <String, dynamic>{};

      VoiceIntentHandler? targetHandler;
      for (final h in handlers) {
        if (h.intentId.toUpperCase() == intentName.toUpperCase()) {
          targetHandler = h;
          break;
        }
      }

      if (targetHandler != null && effectiveContext != null) {
        log('VoiceDispatcher: LLM intent [$intentName] executing via handler.');
        final enrichedContext = VoiceIntentContext(
          rawQuery: rawQuery,
          normalizedQuery: normalized,
          base64Image: base64Image,
          llmParameters: parameters,
        );
        return await targetHandler.execute(effectiveContext, enrichedContext);
      }

      return LauncherCommandResult(
        intent: intentName,
        spokenResponse: spokenResponse,
        actionPayload: parameters,
      );
    } catch (e, st) {
      log('VoiceDispatcher: LLM dispatch exception: $e', stackTrace: st);
      return const LauncherCommandResult(
        intent: 'ERROR',
        spokenResponse:
            "I'm sorry, I encountered a connection error. Please try again.",
      );
    }
  }

  Future<LauncherCommandResult> dispatchAndAnnounce(
    String rawQuery, {
    BuildContext? context,
    String? base64Image,
    Map<String, dynamic>? systemContext,
  }) async {
    final result = await dispatch(
      rawQuery,
      context: context,
      base64Image: base64Image,
      systemContext: systemContext,
    );

    if (result.intent == 'ERROR' || result.intent.endsWith('_FAILED')) {
      await _sound.play(SoundCue.error);
      await _haptics.errorAlert();
    } else {
      await _sound.play(SoundCue.success);
      await _haptics.successNotification();
    }

    await _assistant.speak(result.spokenResponse);
    return result;
  }
}