// lib/focus/intents/focus_intents.dart
import 'package:beacon_os/core/voice_bus/voice_bus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';
import 'package:local_vault_api/local_vault_api.dart';

/// معالج ضبط وبرمجة المنبهات
class SetAlarmIntentHandler extends VoiceIntentHandler {
  @override
  String get intentId => 'SET_ALARM';

  @override
  int get priority => 90;

  @override
  RegExp get fastPathPattern => RegExp(
        r'^(?:set alarm|create alarm|alarm for|wake me up at)\s+(.+)',
        caseSensitive: false,
      );

  @override
  String get llmDescription =>
      'Set or schedule a new alarm clock time with an optional label.';

  @override
  Map<String, String> get parameterDescriptions => const {
        'time':
            'Time string formatted as "HH:mm" or with AM/PM (e.g. "07:30", "7:00 PM", "21:15").',
        'hour': 'Integer hour (0 to 23).',
        'minute': 'Integer minute (0 to 59).',
        'label': 'Optional label or purpose of the alarm.',
      };

  @override
  Future<LauncherCommandResult> execute(
    BuildContext context,
    VoiceIntentContext intentContext,
  ) async {
    final repo = context.read<LauncherRepository>();
    final query = intentContext.normalizedQuery;
    final params = intentContext.llmParameters;

    int? hour;
    int? minute;

    // 1. استخراج الساعة والدقيقة مباشرة إن تم تمريرهما كأرقام
    if (params.containsKey('hour') && params['hour'] != null) {
      hour = int.tryParse(params['hour'].toString());
    }
    if (params.containsKey('minute') && params['minute'] != null) {
      minute = int.tryParse(params['minute'].toString());
    }

    // 2. تحليل معيار time النصي من الذكاء الاصطناعي
    if (hour == null &&
        params.containsKey('time') &&
        params['time'] is String) {
      final timeStr = (params['time'] as String).trim().toLowerCase();
      final timeParts = timeStr.replaceAll(RegExp(r'[^\d:]'), '').split(':');
      if (timeParts.isNotEmpty) {
        hour = int.tryParse(timeParts[0]);
        if (timeParts.length > 1) {
          minute = int.tryParse(timeParts[1]);
        }
        if (timeStr.contains('pm') && hour != null && hour < 12) {
          hour += 12;
        } else if (timeStr.contains('am') && hour == 12) {
          hour = 0;
        }
      }
    }

    // 3. تحليل الوقت من نص المسار السريع إذا لم يحدده الـ LLM
    if (hour == null) {
      final match = RegExp(r'(\d{1,2})(?::(\d{2}))?').firstMatch(query);
      if (match != null) {
        hour = int.tryParse(match.group(1) ?? '8') ?? 8;
        minute = int.tryParse(match.group(2) ?? '0') ?? 0;

        if (query.contains('pm') && hour < 12) hour += 12;
        if (query.contains('am') && hour == 12) hour = 0;
      }
    }

    if (hour != null) {
      final minVal = minute ?? 0;
      final label = (params['label'] as String?)?.trim() ?? 'Beacon Alarm';

      await repo.focusAlarms.createAlarm(
        hour: hour,
        minute: minVal,
        label: label.isEmpty ? 'Beacon Alarm' : label,
      );

      final hour12 = hour % 12 == 0 ? 12 : hour % 12;
      final period = hour >= 12 ? 'PM' : 'AM';
      final minStr =
          minVal == 0 ? "o'clock" : minVal.toString().padLeft(2, '0');

      return LauncherCommandResult(
        intent: intentId,
        spokenResponse: 'Alarm set for $hour12 $minStr $period.',
      );
    }

    return const LauncherCommandResult(
      intent: 'SET_ALARM_FAILED',
      spokenResponse: 'Please specify the alarm time, for example 7 AM.',
    );
  }
}

/// معالج تفعيل أو تعطيل المنبه (TOGGLE_ALARM)
class ToggleAlarmIntentHandler extends VoiceIntentHandler {
  @override
  String get intentId => 'TOGGLE_ALARM';

  @override
  int get priority => 90;

  @override
  RegExp get fastPathPattern => RegExp(
        r'^(?:turn (?:on|off)|enable|disable|toggle)\s+.*alarm',
        caseSensitive: false,
      );

  @override
  String get llmDescription =>
      'Turn on, enable, turn off, or disable a specific scheduled alarm clock.';

  @override
  Map<String, String> get parameterDescriptions => const {
        'alarm_id': 'Exact ID of the alarm to toggle from system context.',
        'is_active':
            'Boolean true to enable/turn on, false to disable/turn off.',
        'time': 'Time string to match if alarm_id is unknown (e.g. "07:30").',
      };

  @override
  Future<LauncherCommandResult> execute(
    BuildContext context,
    VoiceIntentContext intentContext,
  ) async {
    final alarmsRepo = context.read<FocusAlarmsRepository>();
    final query = intentContext.normalizedQuery;
    final params = intentContext.llmParameters;

    final alarmList = await alarmsRepo.watchAlarms().first;
    if (alarmList.isEmpty) {
      return const LauncherCommandResult(
        intent: 'TOGGLE_ALARM_FAILED',
        spokenResponse: 'You have no alarms scheduled to toggle.',
      );
    }

    Alarm? targetAlarm;
    final alarmId = params['alarm_id'] as String?;
    if (alarmId != null && alarmId.isNotEmpty) {
      targetAlarm = alarmList.where((a) => a.id == alarmId).firstOrNull;
    }

    if (targetAlarm == null) {
      final timeParam = params['time'] as String? ?? query;
      final match = RegExp(r'(\d{1,2})(?::(\d{2}))?').firstMatch(timeParam);
      if (match != null) {
        var h = int.tryParse(match.group(1) ?? '') ?? -1;
        final m = int.tryParse(match.group(2) ?? '0') ?? 0;
        if (timeParam.contains('pm') && h < 12) h += 12;
        if (timeParam.contains('am') && h == 12) h = 0;

        targetAlarm =
            alarmList.where((a) => a.hour == h && a.minute == m).firstOrNull;
      }
    }

    final shouldTurnOff = query.contains('off') ||
        query.contains('disable') ||
        (params['is_active'] == false);

    targetAlarm ??= shouldTurnOff
        ? alarmList.where((a) => a.isActive).firstOrNull
        : alarmList.where((a) => !a.isActive).firstOrNull;

    targetAlarm ??= alarmList.first;

    final desiredState = !shouldTurnOff;

    if (targetAlarm.isActive != desiredState) {
      await alarmsRepo.toggleAlarm(targetAlarm);
    }

    final hour12 = targetAlarm.hour % 12 == 0 ? 12 : targetAlarm.hour % 12;
    final period = targetAlarm.hour >= 12 ? 'PM' : 'AM';
    final minStr = targetAlarm.minute == 0
        ? "o'clock"
        : targetAlarm.minute.toString().padLeft(2, '0');
    final statusText = desiredState ? 'enabled' : 'turned off';

    return LauncherCommandResult(
      intent: intentId,
      spokenResponse: 'Alarm for $hour12 $minStr $period is now $statusText.',
      actionPayload: targetAlarm,
    );
  }
}

/// معالج حذف المنبه نهائياً (DELETE_ALARM)
class DeleteAlarmIntentHandler extends VoiceIntentHandler {
  @override
  String get intentId => 'DELETE_ALARM';

  @override
  int get priority => 90;

  @override
  RegExp get fastPathPattern => RegExp(
        r'^(?:delete|remove|cancel)\s+.*alarm',
        caseSensitive: false,
      );

  @override
  String get llmDescription =>
      'Delete, cancel, or remove a scheduled alarm clock from the vault by alarm_id or time.';

  @override
  Map<String, String> get parameterDescriptions => const {
        'alarm_id': 'Exact ID of the alarm to delete from system context.',
        'time': 'Time string to match if alarm_id is unknown (e.g. "07:30").',
      };

  @override
  Future<LauncherCommandResult> execute(
    BuildContext context,
    VoiceIntentContext intentContext,
  ) async {
    final alarmsRepo = context.read<FocusAlarmsRepository>();
    final query = intentContext.normalizedQuery;
    final params = intentContext.llmParameters;

    final alarmList = await alarmsRepo.watchAlarms().first;
    if (alarmList.isEmpty) {
      return const LauncherCommandResult(
        intent: 'DELETE_ALARM_FAILED',
        spokenResponse: 'You have no alarms scheduled to delete.',
      );
    }

    Alarm? targetAlarm;
    final alarmId = params['alarm_id'] as String?;
    if (alarmId != null && alarmId.isNotEmpty) {
      targetAlarm = alarmList.where((a) => a.id == alarmId).firstOrNull;
    }

    if (targetAlarm == null) {
      final timeParam = params['time'] as String? ?? query;
      final match = RegExp(r'(\d{1,2})(?::(\d{2}))?').firstMatch(timeParam);
      if (match != null) {
        var h = int.tryParse(match.group(1) ?? '') ?? -1;
        final m = int.tryParse(match.group(2) ?? '0') ?? 0;
        if (timeParam.contains('pm') && h < 12) h += 12;
        if (timeParam.contains('am') && h == 12) h = 0;

        targetAlarm =
            alarmList.where((a) => a.hour == h && a.minute == m).firstOrNull;
      }
    }

    if (targetAlarm == null && alarmList.length == 1) {
      targetAlarm = alarmList.first;
    }

    if (targetAlarm != null) {
      await alarmsRepo.deleteAlarm(targetAlarm.id);

      final hour12 = targetAlarm.hour % 12 == 0 ? 12 : targetAlarm.hour % 12;
      final period = targetAlarm.hour >= 12 ? 'PM' : 'AM';
      final minStr = targetAlarm.minute == 0
          ? "o'clock"
          : targetAlarm.minute.toString().padLeft(2, '0');

      return LauncherCommandResult(
        intent: intentId,
        spokenResponse: 'Deleted alarm for $hour12 $minStr $period.',
        actionPayload: targetAlarm,
      );
    }

    return const LauncherCommandResult(
      intent: 'DELETE_ALARM_NOT_FOUND',
      spokenResponse: 'Could not find a matching alarm time to delete.',
    );
  }
}