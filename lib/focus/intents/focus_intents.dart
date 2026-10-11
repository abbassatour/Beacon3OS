// lib/focus/intents/focus_intents.dart
import 'package:beacon_os/core/voice_bus/voice_bus.dart'; // 👈 السطر المضاف الذي يحل الخطأ
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';
import 'package:local_vault_api/local_vault_api.dart';

/// معالج ضبط المنبه بالمسار السريع (Sub-5ms Fast Path)
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
  Future<LauncherCommandResult> execute(
    BuildContext context,
    VoiceIntentContext intentContext,
  ) async {
    final repo = context.read<LauncherRepository>();
    final query = intentContext.normalizedQuery;
    final params = intentContext.llmParameters;

    int? hour;
    int? minute;

    if (params.containsKey('time') && params['time'] is String) {
      final timeParts = (params['time'] as String).split(':');
      if (timeParts.length >= 2) {
        hour = int.tryParse(timeParts[0]);
        minute = int.tryParse(timeParts[1]);
      }
    }

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
      final label = (params['label'] as String?) ?? 'Beacon Alarm';

      await repo.focusAlarms.createAlarm(
        hour: hour,
        minute: minVal,
        label: label,
      );

      final hour12 = hour % 12 == 0 ? 12 : hour % 12;
      final period = hour >= 12 ? 'PM' : 'AM';
      final minStr = minVal == 0 ? "o'clock" : minVal.toString().padLeft(2, '0');

      return LauncherCommandResult(
        intent: 'SET_ALARM',
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
      final match = RegExp(r'(\d{1,2})(?::(\d{2}))?').firstMatch(query);
      if (match != null) {
        var h = int.tryParse(match.group(1) ?? '') ?? -1;
        final m = int.tryParse(match.group(2) ?? '0') ?? 0;
        if (query.contains('pm') && h < 12) h += 12;
        if (query.contains('am') && h == 12) h = 0;

        targetAlarm = alarmList.where((a) => a.hour == h && a.minute == m).firstOrNull;
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
    final minStr = targetAlarm.minute == 0 ? "o'clock" : targetAlarm.minute.toString().padLeft(2, '0');
    final statusText = desiredState ? 'enabled' : 'turned off';

    return LauncherCommandResult(
      intent: 'TOGGLE_ALARM',
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
      final match = RegExp(r'(\d{1,2})(?::(\d{2}))?').firstMatch(query);
      if (match != null) {
        var h = int.tryParse(match.group(1) ?? '') ?? -1;
        final m = int.tryParse(match.group(2) ?? '0') ?? 0;
        if (query.contains('pm') && h < 12) h += 12;
        if (query.contains('am') && h == 12) h = 0;

        targetAlarm = alarmList.where((a) => a.hour == h && a.minute == m).firstOrNull;
      }
    }

    if (targetAlarm == null && alarmList.length == 1) {
      targetAlarm = alarmList.first;
    }

    if (targetAlarm != null) {
      await alarmsRepo.deleteAlarm(targetAlarm.id);

      final hour12 = targetAlarm.hour % 12 == 0 ? 12 : targetAlarm.hour % 12;
      final period = targetAlarm.hour >= 12 ? 'PM' : 'AM';
      final minStr = targetAlarm.minute == 0 ? "o'clock" : targetAlarm.minute.toString().padLeft(2, '0');

      return LauncherCommandResult(
        intent: 'DELETE_ALARM',
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