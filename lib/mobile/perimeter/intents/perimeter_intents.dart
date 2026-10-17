// lib/mobile/perimeter/intents/perimeter_intents.dart
import 'package:beacon_os/core/voice_bus/voice_bus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';

/// معالج فحص الكاميرات المحيطية وتحليل المشهد المباشر صوتياً عبر الذكاء الاصطناعي
class InspectCameraIntentHandler extends VoiceIntentHandler {
  @override
  String get intentId => 'INSPECT_CAMERA';

  @override
  int get priority => 85;

  @override
  RegExp get fastPathPattern => RegExp(
        r'^(?:who is at the (?:front )?door|check (?:the )?(?:front door|doorbell|backyard|garage|nursery|camera)|look at (?:the )?(?:front door|backyard|garage|nursery|camera)|inspect (?:the )?camera)',
        caseSensitive: false,
      );

  @override
  String get llmDescription =>
      'Capture and inspect a live security camera frame from a specific Ring camera (front door, backyard, nursery, or garage) and describe the scene aloud.';

  @override
  Map<String, String> get parameterDescriptions => const {
        'camera_name':
            'The target camera to inspect: "front_door", "backyard", "nursery", or "garage".',
        'query':
            'Specific question about the live scene (e.g., checking for packages, vehicles, or pets).',
      };

  @override
  Future<LauncherCommandResult> execute(
    BuildContext context,
    VoiceIntentContext intentContext,
  ) async {
    final ringRepo = context.read<LauncherRepository>().ring;
    final devices = await ringRepo.getAllDevices();

    if (devices.isEmpty) {
      return const LauncherCommandResult(
        intent: 'INSPECT_CAMERA_FAILED',
        spokenResponse: 'No security cameras are registered in your vault.',
      );
    }

    final queryLower = intentContext.normalizedQuery;
    final params = intentContext.llmParameters;

    // 1. تحديد الكاميرا المستهدفة بناءً على النص أو معطيات الذكاء الاصطناعي
    RingDeviceEntity? targetDevice;

    final cameraParam = (params['camera_name'] as String?)?.toLowerCase();

    if (cameraParam != null && cameraParam.isNotEmpty) {
      targetDevice = devices.where((d) {
        final loc = d.location.toLowerCase();
        final label = d.label.toLowerCase();
        return loc.contains(cameraParam) || label.contains(cameraParam);
      }).firstOrNull;
    }

    if (targetDevice == null) {
      if (queryLower.contains('backyard') || queryLower.contains('garden')) {
        targetDevice = devices
            .where((d) => d.location.toLowerCase().contains('backyard'))
            .firstOrNull;
      } else if (queryLower.contains('garage') ||
          queryLower.contains('driveway') ||
          queryLower.contains('car')) {
        targetDevice = devices
            .where((d) => d.location.toLowerCase().contains('garage'))
            .firstOrNull;
      } else if (queryLower.contains('nursery') ||
          queryLower.contains('baby') ||
          queryLower.contains('crib')) {
        targetDevice = devices
            .where((d) => d.location.toLowerCase().contains('nursery'))
            .firstOrNull;
      } else {
        // الافتراضي هو الباب الأمامي
        targetDevice = devices
            .where((d) => d.location.toLowerCase().contains('front'))
            .firstOrNull;
      }
    }

    // إذا لم يتطابق أي اسم، نختار الكاميرا الأولى المسجلة
    targetDevice ??= devices.first;

    // 2. فحص الكاميرا فوراً وتحليل الإطار صوتياً
    final customQuery = params['query'] as String?;
    final analysis = await ringRepo.inspectCameraLive(
      deviceId: targetDevice.id,
      customQuery: customQuery,
    );

    return LauncherCommandResult(
      intent: intentId,
      spokenResponse:
          analysis ?? 'Activity detected at ${targetDevice.label}.',
      actionPayload: targetDevice,
    );
  }
}

/// معالج فتح خط التحدث الصوتي ثنائي الاتجاه مع جرس الباب (Two-Way Audio)
class AnswerDoorbellIntentHandler extends VoiceIntentHandler {
  @override
  String get intentId => 'ANSWER_DOORBELL';

  @override
  int get priority => 90;

  @override
  RegExp get fastPathPattern => RegExp(
        r'^(?:answer (?:the )?(?:door|doorbell)|talk to (?:the )?(?:visitor|door)|speak to (?:the )?(?:front )?door)',
        caseSensitive: false,
      );

  @override
  String get llmDescription =>
      'Open two-way audio communication with the front door video doorbell to talk to a visitor.';

  @override
  Map<String, String> get parameterDescriptions => const {
        'camera_name':
            'Optional specific doorbell device to answer. Defaults to front door.',
      };

  @override
  Future<LauncherCommandResult> execute(
    BuildContext context,
    VoiceIntentContext intentContext,
  ) async {
    final ringRepo = context.read<LauncherRepository>().ring;
    final devices = await ringRepo.getAllDevices();

    final doorbell = devices.where((d) {
      return d.deviceType == 'doorbell' ||
          d.location.toLowerCase().contains('front');
    }).firstOrNull ?? (devices.isNotEmpty ? devices.first : null);

    if (doorbell == null) {
      return const LauncherCommandResult(
        intent: 'ANSWER_DOORBELL_FAILED',
        spokenResponse: 'No video doorbell was found to connect.',
      );
    }

    await ringRepo.answerDoorbell(doorbell.id);

    return LauncherCommandResult(
      intent: intentId,
      spokenResponse:
          'Two-way audio connected to ${doorbell.label}. You can speak now.',
      actionPayload: doorbell,
    );
  }
}

/// معالج إطلاق سيناريوهات المحاكاة الذكية المخصصة للتحكيم (Judge Demo Trigger)
class SimulateRingScenarioIntentHandler extends VoiceIntentHandler {
  @override
  String get intentId => 'TRIGGER_RING_SCENARIO';

  @override
  int get priority => 90;

  @override
  RegExp get fastPathPattern => RegExp(
        r'^(?:simulate|test)\s+(?:courier|delivery|package|doorbell|ring|intruder|cat|night prowler|baby|car|neighbor)\b',
        caseSensitive: false,
      );

  @override
  String get llmDescription =>
      'Trigger a simulated Ring event scenario for testing: "courier" (Amazon package), "night_prowler" (cat in backyard), "baby_crying" (nursery stirring), "car_arriving" (garage sedan), or "neighbor" (friendly neighbor waving).';

  @override
  Map<String, String> get parameterDescriptions => const {
        'scenario':
            'The test scenario: "courier", "night_prowler", "baby", "car", or "neighbor".',
      };

  @override
  Future<LauncherCommandResult> execute(
    BuildContext context,
    VoiceIntentContext intentContext,
  ) async {
    final ringRepo = context.read<LauncherRepository>().ring;
    final query = intentContext.normalizedQuery;
    final scenarioParam =
        (intentContext.llmParameters['scenario'] as String?)?.toLowerCase() ?? '';

    RingScenarioPreset preset;

    if (query.contains('night') ||
        query.contains('prowler') ||
        query.contains('cat') ||
        query.contains('intruder') ||
        scenarioParam.contains('prowler')) {
      preset = RingScenarioPreset.nightProwler;
    } else if (query.contains('baby') ||
        query.contains('nursery') ||
        query.contains('crying') ||
        scenarioParam.contains('baby')) {
      preset = RingScenarioPreset.babyCrying;
    } else if (query.contains('car') ||
        query.contains('driveway') ||
        query.contains('garage') ||
        scenarioParam.contains('car')) {
      preset = RingScenarioPreset.carArriving;
    } else if (query.contains('neighbor') ||
        query.contains('sarah') ||
        scenarioParam.contains('neighbor')) {
      preset = RingScenarioPreset.friendlyNeighbor;
    } else {
      preset = RingScenarioPreset.courierDelivery;
    }

    await ringRepo.triggerSimulatedScenario(preset);

    String label;
    switch (preset) {
      case RingScenarioPreset.courierDelivery:
        label = 'Courier delivery at Front Door';
        break;
      case RingScenarioPreset.nightProwler:
        label = 'Night movement in Backyard';
        break;
      case RingScenarioPreset.babyCrying:
        label = 'Movement in Nursery';
        break;
      case RingScenarioPreset.carArriving:
        label = 'Vehicle arriving at Garage';
        break;
      case RingScenarioPreset.friendlyNeighbor:
        label = 'Neighbor at Front Door';
        break;
    }

    return LauncherCommandResult(
      intent: intentId,
      spokenResponse: 'Simulating $label. Processing inbound alert.',
      actionPayload: preset.name,
    );
  }
}