// lib/mobile/comms/intents/comms_intents.dart
import 'package:beacon_os/core/services/web3_service.dart';
import 'package:beacon_os/core/voice_bus/voice_bus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';

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
  String get llmDescription =>
      'Trigger emergency SOS distress broadcast, loud alarm siren, and share live GPS coordinates to emergency rescue radar.';

  @override
  Map<String, String> get parameterDescriptions => const {};

  @override
  Future<LauncherCommandResult> execute(
    BuildContext context,
    VoiceIntentContext intentContext,
  ) async {
    final commsRepo = context.read<CommsRepository>();
    final alertId = await commsRepo.triggerEmergencySos();

    return LauncherCommandResult(
      intent: intentId,
      spokenResponse:
          'Emergency SOS broadcast initiated! Live GPS coordinates shared to family radar.',
      actionPayload: alertId,
    );
  }
}

/// معالج الاتصال الهاتفي بجهة اتصال أو طلب رقم مباشرة
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
  String get llmDescription =>
      'Initiate a phone call to a saved contact by name, or dial a specific phone number directly.';

  @override
  Map<String, String> get parameterDescriptions => const {
        'contact_name': 'Name of the contact person to call.',
        'phone_number': 'Phone number digits to dial directly.',
      };

  @override
  Future<LauncherCommandResult> execute(
    BuildContext context,
    VoiceIntentContext intentContext,
  ) async {
    final commsRepo = context.read<CommsRepository>();
    final hardwareRepo = context.read<SystemHardwareRepository>();
    final params = intentContext.llmParameters;

    String targetQuery = '';

    // 1. فحص هل مرر الذكاء الاصطناعي رقماً مباشراً
    final directNumber = (params['phone_number'] as String?)?.trim();
    if (directNumber != null && directNumber.isNotEmpty) {
      final digits = directNumber.replaceAll(RegExp(r'[^\d+]'), '');
      if (digits.length >= 3) {
        await hardwareRepo.callPhoneNumber(digits);
        return LauncherCommandResult(
          intent: intentId,
          spokenResponse: 'Dialing $digits.',
          actionPayload: digits,
        );
      }
    }

    // 2. استخراج الاسم من المسار السريع
    final match = fastPathPattern?.firstMatch(intentContext.rawQuery);
    if (match != null && match.groupCount >= 1) {
      targetQuery = match.group(1)?.trim() ?? '';
    }

    // 3. استخراج الاسم من معطيات LLM
    if (targetQuery.isEmpty && params.containsKey('contact_name')) {
      targetQuery = (params['contact_name'] as String? ?? '').trim();
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
        intent: intentId,
        spokenResponse: 'Calling ${contact.name}.',
        actionPayload: contact,
      );
    }

    final digitsOnly = targetQuery.replaceAll(RegExp(r'[^\d+]'), '');
    if (digitsOnly.length >= 3) {
      await hardwareRepo.callPhoneNumber(digitsOnly);
      return LauncherCommandResult(
        intent: intentId,
        spokenResponse: 'Dialing $digitsOnly.',
        actionPayload: digitsOnly,
      );
    }

    return LauncherCommandResult(
      intent: 'CALL_CONTACT_NOT_FOUND',
      spokenResponse:
          'Could not find a contact named $targetQuery in your vault.',
    );
  }
}

/// معالج حفظ جهة اتصال جديدة (SAVE_CONTACT)
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
  String get llmDescription =>
      'Save or add a new phone contact into the vault and phonebook, with optional relationship label and emergency status.';

  @override
  Map<String, String> get parameterDescriptions => const {
        'name': 'Full name of the contact person.',
        'phone_number': 'Phone number digits.',
        'relationship':
            'Optional relationship label (e.g. Mother, Father, Doctor, Friend).',
        'is_emergency':
            'Boolean true if this contact should be designated as an Emergency SOS contact, false otherwise.',
      };

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
          name = name
              .replaceAll(
                RegExp(r'\b(number|phone|with)\b', caseSensitive: false),
                '',
              )
              .trim();
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
      intent: intentId,
      spokenResponse: 'Saved $name $roleText.',
      actionPayload: id,
    );
  }
}

/// معالج حذف جهة اتصال (DELETE_CONTACT)
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
  String get llmDescription =>
      'Delete or remove an existing contact from the vault by contact_id or name.';

  @override
  Map<String, String> get parameterDescriptions => const {
        'contact_id': 'Exact ID of the contact to delete from system context.',
        'name': 'Name of the contact to match if contact_id is unknown.',
      };

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

    ContactEntity? targetContact;

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
        intent: intentId,
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

/// معالج مزامنة جهات اتصال الهاتف وسجل العتاد (SYNC_CONTACTS)
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
  String get llmDescription =>
      'Synchronize and reconcile contacts between the local device phonebook and the vault.';

  @override
  Map<String, String> get parameterDescriptions => const {};

  @override
  Future<LauncherCommandResult> execute(
    BuildContext context,
    VoiceIntentContext intentContext,
  ) async {
    final commsRepo = context.read<CommsRepository>();
    final result = await commsRepo.syncDeviceContactsToVault();

    String feedback;
    if (result.addedCount == 0 &&
        result.updatedCount == 0 &&
        result.deletedCount == 0) {
      feedback = 'Your contacts are already up to date.';
    } else {
      final summary = <String>[];
      if (result.addedCount > 0) summary.add('${result.addedCount} added');
      if (result.updatedCount > 0) summary.add('${result.updatedCount} updated');
      if (result.deletedCount > 0) summary.add('${result.deletedCount} removed');
      feedback = 'Contacts synced: ${summary.join(', ')}.';
    }

    return LauncherCommandResult(
      intent: intentId,
      spokenResponse: feedback,
      actionPayload: result,
    );
  }
}

/// معالج الاقتران اللاتمركزي الفوري بالأجهزة وشاشات التلفزيون والكمبيوتر (PAIR_DEVICE)
class PairDeviceIntentHandler extends VoiceIntentHandler {
  @override
  String get intentId => 'PAIR_DEVICE';

  @override
  int get priority => 90;

  // 🌟 تحديث النمط ليقبل أي نص بعد كلمة Pair لنتعامل مع الكلمات والأرقام معاً
  @override
  RegExp get fastPathPattern => RegExp(
        r'^(?:pair|connect|link)\s*(?:device|tv|screen|display|computer|desktop)?\s*(.+)',
        caseSensitive: false,
      );

  @override
  String get llmDescription =>
      'Pair or link this sovereign vault to a secondary display (Fire TV or Desktop) using a 6-digit code announced or displayed on that screen.';

  @override
  Map<String, String> get parameterDescriptions => const {
        'pairing_code':
            'The 6-digit numeric pairing code displayed on the target screen.',
      };

  /// 🌟 مساعد ذكي لتحويل الكلمات المنطوقة إلى أرقام لتفادي أخطاء الـ Speech-to-Text
  String _convertWordsToDigits(String input) {
    const map = {
      'zero': '0', 'oh': '0',
      'one': '1', 'won': '1',
      'two': '2', 'to': '2', 'too': '2',
      'three': '3', 'tree': '3',
      'four': '4', 'for': '4',
      'five': '5',
      'six': '6',
      'seven': '7',
      'eight': '8', 'ate': '8',
      'nine': '9',
    };
    
    var res = input.toLowerCase();
    map.forEach((key, value) {
      res = res.replaceAll(RegExp(r'\b' + key + r'\b'), value);
    });
    
    // إزالة أي شيء ليس رقماً
    return res.replaceAll(RegExp(r'\D'), '');
  }

  @override
  Future<LauncherCommandResult> execute(
    BuildContext context,
    VoiceIntentContext intentContext,
  ) async {
    final commsRepo = context.read<CommsRepository>();
    final params = intentContext.llmParameters;

    String rawInput = '';

    // 1. استخراج النص من التعبير النمطي للمسار السريع (Sub-5ms)
    final match = fastPathPattern?.firstMatch(intentContext.rawQuery);
    if (match != null && match.groupCount >= 1) {
      rawInput = match.group(1)?.trim() ?? '';
    }

    // 2. استخراج الأرقام من معطيات الذكاء الاصطناعي كخيار بديل
    if (rawInput.isEmpty && params.containsKey('pairing_code')) {
      rawInput = params['pairing_code'] as String? ?? '';
    }

    // 3. تحويل الكلمات الإنجليزية للأرقام، ثم تنظيف النص
    final cleanCode = _convertWordsToDigits(rawInput);

    if (cleanCode.length != 6) {
      return const LauncherCommandResult(
        intent: 'PAIR_DEVICE_FAILED',
        spokenResponse:
            'Please state the six-digit code announced on your screen, for example: Pair 8 4 9, 2 0 1.',
      );
    }

    // استخدام المعرف السيادي اللامركزي للهاتف كـ Master Vault ID
    final sovereignDid = Web3Service.instance.walletAddressHex.toLowerCase();

    final success = await commsRepo.authorizePairingCode(
      cleanCode,
      customVaultId: sovereignDid,
    );

    if (success) {
      return LauncherCommandResult(
        intent: 'PAIR_DEVICE',
        spokenResponse:
            'Living room display successfully linked! Real-time telemetry and agenda are now live.',
        actionPayload: cleanCode,
      );
    } else {
      return LauncherCommandResult(
        intent: 'PAIR_DEVICE_FAILED',
        spokenResponse:
            'Pairing failed. The code may be incorrect or has expired. Please check the screen.',
        actionPayload: cleanCode,
      );
    }
  }
}