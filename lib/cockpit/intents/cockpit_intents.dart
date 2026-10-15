// lib/cockpit/intents/cockpit_intents.dart
import 'package:beacon_os/core/voice_bus/voice_bus.dart';
import 'package:flutter/widgets.dart';
import 'package:drift/drift.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:launcher_repository/launcher_repository.dart';
import 'package:local_vault_api/local_vault_api.dart';
/// معالج فحص مستوى البطارية بالمسار السريع (Sub-5ms)
class BatteryStatusIntentHandler extends VoiceIntentHandler {
  @override
  String get intentId => 'BATTERY_STATUS';

  @override
  int get priority => 95;

  @override
  RegExp get fastPathPattern => RegExp(
        r'^(?:battery|what is my battery|battery level|battery status|check battery)',
        caseSensitive: false,
      );

  @override
  Future<LauncherCommandResult> execute(
    BuildContext context,
    VoiceIntentContext intentContext,
  ) async {
    final hardwareRepo = context.read<SystemHardwareRepository>();
    final status = await hardwareRepo.getBatteryStatus();

    return LauncherCommandResult(
      intent: 'BATTERY_STATUS',
      spokenResponse: status,
    );
  }
}

/// معالج تشغيل وإطفاء كشاف الهاتف بالمسار السريع
class FlashlightIntentHandler extends VoiceIntentHandler {
  @override
  String get intentId => 'FLASHLIGHT';

  @override
  int get priority => 95;

  @override
  RegExp get fastPathPattern => RegExp(
        r'^(?:flashlight|torch|turn on flashlight|turn off flashlight|toggle flashlight)',
        caseSensitive: false,
      );

  @override
  Future<LauncherCommandResult> execute(
    BuildContext context,
    VoiceIntentContext intentContext,
  ) async {
    final hardwareRepo = context.read<SystemHardwareRepository>();
    final query = intentContext.normalizedQuery;

    final enable = !query.contains('off');
    await hardwareRepo.toggleFlashlight(enable: enable);

    return LauncherCommandResult(
      intent: 'FLASHLIGHT',
      spokenResponse: enable ? 'Flashlight on.' : 'Flashlight off.',
    );
  }
}

/// معالج قفل الشاشة والعودة لسطح النظام
class LockScreenIntentHandler extends VoiceIntentHandler {
  @override
  String get intentId => 'LOCK_SCREEN';

  @override
  int get priority => 90;

  @override
  RegExp get fastPathPattern => RegExp(
        r'^(?:lock screen|lock phone|sleep|turn off screen)',
        caseSensitive: false,
      );

  @override
  Future<LauncherCommandResult> execute(
    BuildContext context,
    VoiceIntentContext intentContext,
  ) async {
    final hardwareRepo = context.read<SystemHardwareRepository>();
    await hardwareRepo.lockScreen();

    return const LauncherCommandResult(
      intent: 'LOCK_SCREEN',
      spokenResponse: 'Screen locked.',
    );
  }
}

/// معالج الاستعلام عن الوقت والتاريخ الحالي
class TimeDateIntentHandler extends VoiceIntentHandler {
  @override
  String get intentId => 'TIME_AND_DATE';

  @override
  int get priority => 85;

  @override
  RegExp get fastPathPattern => RegExp(
        r'^(?:what time is it|what is the time|current time|what is today|what date is it|what day is it|tell me the time)',
        caseSensitive: false,
      );

  @override
  Future<LauncherCommandResult> execute(
    BuildContext context,
    VoiceIntentContext intentContext,
  ) async {
    final now = DateTime.now();
    final timeStr = DateFormat('h:mm a').format(now);
    final dateStr = DateFormat('EEEE, MMMM d').format(now);

    return LauncherCommandResult(
      intent: 'TIME_AND_DATE',
      spokenResponse: 'It is $timeStr on $dateStr.',
    );
  }
}

/// معالج قراءة الملخص الصباحي اليومي الشامل
class DailyBriefingIntentHandler extends VoiceIntentHandler {
  @override
  String get intentId => 'DAILY_BRIEFING';

  @override
  int get priority => 80;

  @override
  RegExp get fastPathPattern => RegExp(
        r'^(?:briefing|daily briefing|morning briefing|overview|what does my day look like)',
        caseSensitive: false,
      );

  @override
  Future<LauncherCommandResult> execute(
    BuildContext context,
    VoiceIntentContext intentContext,
  ) async {
    final tasksRepo = context.read<TaskAgendaRepository>();
    final alarmsRepo = context.read<FocusAlarmsRepository>();
    final hardwareRepo = context.read<SystemHardwareRepository>();

    final now = DateTime.now();
    final timeStr = DateFormat('h:mm a').format(now);
    final dateStr = DateFormat('EEEE, MMMM d').format(now);

    final buffer = StringBuffer('Good day. Today is $dateStr, $timeStr. ');

    final alarms = await alarmsRepo.watchAlarms().first;
    final activeAlarms = alarms.where((a) => a.isActive).toList();
    if (activeAlarms.isNotEmpty) {
      final a = activeAlarms.first;
      final hour12 = a.hour % 12 == 0 ? 12 : a.hour % 12;
      final period = a.hour >= 12 ? 'PM' : 'AM';
      buffer.write('Next alarm is at $hour12 $period. ');
    } else {
      buffer.write('No active alarms scheduled. ');
    }

    final pending = await tasksRepo.getPendingTasks();
    if (pending.isEmpty) {
      buffer.write('Your agenda is completely clear. ');
    } else {
      buffer.write('You have ${pending.length} pending tasks. Top priority: ${pending.first.title}. ');
    }

    final battery = await hardwareRepo.getBatteryStatus();
    buffer.write(battery);

    return LauncherCommandResult(
      intent: 'DAILY_BRIEFING',
      spokenResponse: buffer.toString(),
    );
  }
}

/// معالج فتح وتشغيل التطبيقات الخارجية بالمسار السريع (Sub-5ms)
class OpenAppIntentHandler extends VoiceIntentHandler {
  @override
  String get intentId => 'OPEN_APP';

  @override
  int get priority => 85;

  @override
  RegExp get fastPathPattern => RegExp(
        r'^(?:open|launch|start|run)\s+(.+)',
        caseSensitive: false,
      );

  @override
  Future<LauncherCommandResult> execute(
    BuildContext context,
    VoiceIntentContext intentContext,
  ) async {
    final hardwareRepo = context.read<SystemHardwareRepository>();
    String appTarget = '';

    final match = fastPathPattern?.firstMatch(intentContext.rawQuery);
    if (match != null && match.groupCount >= 1) {
      appTarget = match.group(1)?.trim() ?? '';
    }

    if (appTarget.isEmpty && intentContext.llmParameters.containsKey('app_name')) {
      appTarget = intentContext.llmParameters['app_name'] as String? ?? '';
    }

    appTarget = appTarget.replaceAll(RegExp(r'\bapp\b', caseSensitive: false), '').trim();

    if (appTarget.isEmpty) {
      return const LauncherCommandResult(
        intent: 'OPEN_APP_FAILED',
        spokenResponse: 'Which app would you like me to open?',
      );
    }

    final success = await hardwareRepo.openApp(appTarget);

    if (success) {
      return LauncherCommandResult(
        intent: 'OPEN_APP',
        spokenResponse: 'Opening $appTarget.',
        actionPayload: appTarget,
      );
    } else {
      return LauncherCommandResult(
        intent: 'OPEN_APP_NOT_FOUND',
        spokenResponse: 'Could not open $appTarget. It might not be installed.',
        actionPayload: appTarget,
      );
    }
  }
}

/// معالج تحديث إعدادات النظام صوتياً بالمسار السريع (Sub-5ms Fast Path)
class UpdateSettingsIntentHandler extends VoiceIntentHandler {
  @override
  String get intentId => 'UPDATE_SETTINGS';

  @override
  int get priority => 80;

  @override
  RegExp get fastPathPattern => RegExp(
        r'^(?:turn (?:on|off)|enable|disable|toggle|set)\s+(?:high contrast|haptics|sound cues|sounds?|speech rate|reading speed)',
        caseSensitive: false,
      );

  @override
  String get llmDescription =>
      'Update system settings such as high contrast theme, sound cues, haptics, or speech rate';

  @override
  Map<String, String> get parameterDescriptions => const {
        'setting': 'Which setting to update (high_contrast, haptics, sound_cues, speech_rate)',
        'value': 'Target value (true, false, or numeric rate)',
      };

  @override
  Future<LauncherCommandResult> execute(
    BuildContext context,
    VoiceIntentContext intentContext,
  ) async {
    final settingsRepo = context.read<SettingsRepository>();
    final query = intentContext.normalizedQuery;
    final params = intentContext.llmParameters;

    final isOff = query.contains('off') || query.contains('disable');
    final isOn = query.contains('on') || query.contains('enable');

    // 1. التباين العالي (High Contrast)
    if (query.contains('contrast') || params['setting'] == 'high_contrast') {
      final current = await settingsRepo.getSettings();
      final enable = isOn ? true : (isOff ? false : !current.isHighContrast);

      await settingsRepo.updateSettings(
        AppSettingsCompanion(isHighContrast: Value(enable)),
      );

      return LauncherCommandResult(
        intent: 'UPDATE_SETTINGS',
        spokenResponse: enable ? 'High contrast display enabled.' : 'High contrast disabled.',
      );
    }

    // 2. الاهتزازات التكتيكية (Haptics)
    if (query.contains('haptic') || params['setting'] == 'haptics') {
      final current = await settingsRepo.getSettings();
      final enable = isOn ? true : (isOff ? false : !current.hapticsEnabled);

      await settingsRepo.updateSettings(
        AppSettingsCompanion(hapticsEnabled: Value(enable)),
      );

      return LauncherCommandResult(
        intent: 'UPDATE_SETTINGS',
        spokenResponse: enable ? 'Tactile haptics enabled.' : 'Tactile haptics turned off.',
      );
    }

    // 3. الأصوات ونغمات البوصلة (Sound Cues)
    if (query.contains('sound') || params['setting'] == 'sound_cues') {
      final current = await settingsRepo.getSettings();
      final enable = isOn ? true : (isOff ? false : !current.soundCuesEnabled);

      await settingsRepo.updateSettings(
        AppSettingsCompanion(soundCuesEnabled: Value(enable)),
      );

      return LauncherCommandResult(
        intent: 'UPDATE_SETTINGS',
        spokenResponse: enable ? 'Spatial sound cues enabled.' : 'Sound cues turned off.',
      );
    }

    // 4. سرعة نطق الصوت (Speech Rate)
    if (query.contains('speech rate') || query.contains('speed') || params['setting'] == 'speech_rate') {
      final assistantRepo = context.read<AssistantRepository>();
      final current = await settingsRepo.getSettings();
      var newRate = current.speechRate;

      if (query.contains('faster') || query.contains('increase')) {
        newRate = (current.speechRate + 0.1).clamp(0.3, 1.0);
      } else if (query.contains('slower') || query.contains('decrease')) {
        newRate = (current.speechRate - 0.1).clamp(0.3, 1.0);
      }

      await assistantRepo.setSpeechRate(newRate);
      await settingsRepo.updateSettings(
        AppSettingsCompanion(speechRate: Value(newRate)),
      );

      return LauncherCommandResult(
        intent: 'UPDATE_SETTINGS',
        spokenResponse: 'Speech speed set to ${(newRate * 2).toStringAsFixed(1)} times.',
      );
    }

    return const LauncherCommandResult(
      intent: 'UPDATE_SETTINGS_FAILED',
      spokenResponse: 'Could not recognize which setting to update.',
    );
  }
}