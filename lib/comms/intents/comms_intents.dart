// lib/comms/intents/comms_intents.dart
import 'package:beacon_os/core/voice_bus/voice_bus.dart'; // 👈 السطر المضاف الذي يحل الخطأ
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';
import 'package:local_vault_api/local_vault_api.dart';

/// معالج استغاثة الطوارئ SOS بالمسار السريع الفوري (أعلى أولوية في النظام: 100)
class EmergencySosIntentHandler extends VoiceIntentHandler {
  @override
  String get intentId => 'EMERGENCY_SOS';

  @override
  int get priority => 100;

  @override
  RegExp get fastPathPattern => RegExp(
        r'^(?:sos|emergency|help me|mayday|send help)',
        caseSensitive: false,
      );

  @override
  Future<LauncherCommandResult> execute(
    BuildContext context,
    VoiceIntentContext intentContext,
  ) async {
    final commsRepo = context.read<CommsRepository>();
    final alertId = await commsRepo.triggerEmergencySos();

    return LauncherCommandResult(
      intent: 'EMERGENCY_SOS',
      spokenResponse:
          'Emergency SOS broadcast initiated! Live GPS coordinates shared to family radar.',
      actionPayload: alertId,
    );
  }
}

/// معالج الاتصال الهاتفي السريع بجهة اتصال (أولوية مرتفعة: 95)
class CallContactIntentHandler extends VoiceIntentHandler {
  @override
  String get intentId => 'CALL_CONTACT';

  @override
  int get priority => 95;

  @override
  RegExp get fastPathPattern => RegExp(
        r'^(?:call|dial|phone)\s+(.+)',
        caseSensitive: false,
      );

  @override
  Future<LauncherCommandResult> execute(
    BuildContext context,
    VoiceIntentContext intentContext,
  ) async {
    final commsRepo = context.read<CommsRepository>();
    final hardwareRepo = context.read<SystemHardwareRepository>();

    String targetQuery = '';

    final match = fastPathPattern?.firstMatch(intentContext.rawQuery);
    if (match != null && match.groupCount >= 1) {
      targetQuery = match.group(1)?.trim() ?? '';
    }

    if (targetQuery.isEmpty &&
        intentContext.llmParameters.containsKey('contact_name')) {
      targetQuery =
          intentContext.llmParameters['contact_name'] as String? ?? '';
    }

    if (targetQuery.isEmpty) {
      return const LauncherCommandResult(
        intent: 'CALL_CONTACT_FAILED',
        spokenResponse: 'Who would you like me to call?',
      );
    }

    final contact = await commsRepo.findContact(targetQuery);

    if (contact != null) {
      await hardwareRepo.callPhoneNumber(contact.phoneNumber);
      return LauncherCommandResult(
        intent: 'CALL_CONTACT',
        spokenResponse: 'Calling ${contact.name}.',
        actionPayload: contact,
      );
    }

    final digitsOnly = targetQuery.replaceAll(RegExp(r'[^\d+]'), '');
    if (digitsOnly.length >= 3) {
      await hardwareRepo.callPhoneNumber(digitsOnly);
      return LauncherCommandResult(
        intent: 'CALL_CONTACT',
        spokenResponse: 'Dialing $digitsOnly.',
      );
    }

    return LauncherCommandResult(
      intent: 'CALL_CONTACT_NOT_FOUND',
      spokenResponse:
          'Could not find a contact named $targetQuery in your vault.',
    );
  }
}

/// معالج حفظ جهة اتصال جديدة صوتياً (SAVE_CONTACT)
class SaveContactIntentHandler extends VoiceIntentHandler {
  @override
  String get intentId => 'SAVE_CONTACT';

  @override
  int get priority => 85;

  @override
  RegExp get fastPathPattern => RegExp(
        r'^(?:save contact|add contact|new contact)\s+(.+)',
        caseSensitive: false,
      );

  @override
  Future<LauncherCommandResult> execute(
    BuildContext context,
    VoiceIntentContext intentContext,
  ) async {
    final commsRepo = context.read<CommsRepository>();
    final params = intentContext.llmParameters;

    String name = (params['name'] as String?)?.trim() ?? '';
    String phoneNumber = (params['phone_number'] as String?)?.trim() ?? '';
    final relationship = (params['relationship'] as String?)?.trim();
    final isEmergency = (params['is_emergency'] as bool?) ?? false;

    if (name.isEmpty || phoneNumber.isEmpty) {
      final raw = intentContext.rawQuery;
      final match = fastPathPattern?.firstMatch(raw);
      if (match != null && match.groupCount >= 1) {
        final query = match.group(1)?.trim() ?? '';
        final phoneMatch = RegExp(r'(\+?\d[\d\s-]{4,}\d)').firstMatch(query);
        if (phoneMatch != null) {
          phoneNumber = phoneMatch.group(1)!.replaceAll(RegExp(r'[\s-]'), '');
          name = query.replaceFirst(phoneMatch.group(1)!, '').trim();
          name = name.replaceAll(RegExp(r'\b(number|phone|with)\b', caseSensitive: false), '').trim();
        } else if (name.isEmpty) {
          name = query;
        }
      }
    }

    if (name.isEmpty) {
      return const LauncherCommandResult(
        intent: 'SAVE_CONTACT_FAILED',
        spokenResponse: 'Please state the contact name you want to save.',
      );
    }

    if (phoneNumber.isEmpty) {
      return LauncherCommandResult(
        intent: 'SAVE_CONTACT_FAILED',
        spokenResponse: 'Please provide the phone number for $name.',
      );
    }

    final id = await commsRepo.saveContact(
      name: name,
      phoneNumber: phoneNumber,
      relationship: relationship,
      isEmergency: isEmergency,
    );

    final roleText = isEmergency ? 'as an emergency contact' : 'to contacts';
    return LauncherCommandResult(
      intent: 'SAVE_CONTACT',
      spokenResponse: 'Saved $name $roleText.',
      actionPayload: id,
    );
  }
}

/// معالج حذف جهة اتصال صوتياً (DELETE_CONTACT)
class DeleteContactIntentHandler extends VoiceIntentHandler {
  @override
  String get intentId => 'DELETE_CONTACT';

  @override
  int get priority => 85;

  @override
  RegExp get fastPathPattern => RegExp(
        r'^(?:delete contact|remove contact)\s+(.+)',
        caseSensitive: false,
      );

  @override
  Future<LauncherCommandResult> execute(
    BuildContext context,
    VoiceIntentContext intentContext,
  ) async {
    final commsRepo = context.read<CommsRepository>();
    final params = intentContext.llmParameters;

    String targetQuery = (params['name'] as String?)?.trim() ?? '';
    final contactId = params['contact_id'] as String?;

    if (targetQuery.isEmpty && contactId == null) {
      final match = fastPathPattern?.firstMatch(intentContext.rawQuery);
      if (match != null && match.groupCount >= 1) {
        targetQuery = match.group(1)?.trim() ?? '';
      }
    }

    Contact? targetContact;

    if (contactId != null && contactId.isNotEmpty) {
      final allContacts = await commsRepo.watchContacts().first;
      targetContact = allContacts.where((c) => c.id == contactId).firstOrNull;
    }

    if (targetContact == null && targetQuery.isNotEmpty) {
      targetContact = await commsRepo.findContact(targetQuery);
    }

    if (targetContact != null) {
      await commsRepo.deleteContact(targetContact.id);
      return LauncherCommandResult(
        intent: 'DELETE_CONTACT',
        spokenResponse: 'Contact ${targetContact.name} deleted.',
        actionPayload: targetContact,
      );
    }

    return LauncherCommandResult(
      intent: 'DELETE_CONTACT_NOT_FOUND',
      spokenResponse:
          'Could not find a contact named ${targetQuery.isNotEmpty ? targetQuery : "that"} to delete.',
    );
  }
}

/// معالج مزامنة جهات اتصال الهاتف صوتياً (SYNC_CONTACTS)
class SyncContactsIntentHandler extends VoiceIntentHandler {
  @override
  String get intentId => 'SYNC_CONTACTS';

  @override
  int get priority => 85;

  @override
  RegExp get fastPathPattern => RegExp(
        r'^(?:sync contacts|import contacts|sync phone contacts|update contacts|import phonebook)',
        caseSensitive: false,
      );

  @override
  Future<LauncherCommandResult> execute(
    BuildContext context,
    VoiceIntentContext intentContext,
  ) async {
    final commsRepo = context.read<CommsRepository>();
    final result = await commsRepo.syncDeviceContactsToVault();

    final feedback = result.addedCount == 0 && result.updatedCount == 0
        ? 'Your contacts are already up to date.'
        : 'Synced ${result.addedCount} new contacts and updated ${result.updatedCount}.';

    return LauncherCommandResult(
      intent: 'SYNC_CONTACTS',
      spokenResponse: feedback,
      actionPayload: result,
    );
  }
}