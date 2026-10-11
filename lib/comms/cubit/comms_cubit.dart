// lib/comms/cubit/comms_cubit.dart
import 'dart:async';
import 'package:beacon_os/comms/cubit/comms_state.dart';
import 'package:beacon_os/core/audio/sound_controller.dart';
import 'package:beacon_os/core/audio/sound_cue.dart';
import 'package:beacon_os/core/haptics/haptic_manager.dart';
import 'package:bloc/bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';
import 'package:local_vault_api/local_vault_api.dart';

class CommsCubit extends Cubit<CommsState> {
  CommsCubit({
    required CommsRepository commsRepository,
    required SystemHardwareRepository hardwareRepository,
    required AssistantRepository assistantRepository,
    HapticManager? hapticManager,
    SoundController? soundController,
  })  : _commsRepo = commsRepository,
        _hardwareRepo = hardwareRepository,
        _assistant = assistantRepository,
        _haptics = hapticManager ?? HapticManager.instance,
        _sound = soundController ?? SoundController.instance,
        super(const CommsState()) {
    _initStreams();
  }

  final CommsRepository _commsRepo;
  final SystemHardwareRepository _hardwareRepo;
  final AssistantRepository _assistant;
  final HapticManager _haptics;
  final SoundController _sound;

  StreamSubscription<List<Contact>>? _contactsSubscription;

  void _initStreams() {
    emit(state.copyWith(status: CommsStatus.loading));

    _contactsSubscription = _commsRepo.watchContacts().listen(
      (contactsList) async {
        final messages = await _commsRepo.getUnreadMessages();
        emit(
          state.copyWith(
            status: CommsStatus.success,
            contacts: contactsList,
            recentMessages: messages,
          ),
        );
      },
      onError: (Object error) {
        emit(
          state.copyWith(
            status: CommsStatus.error,
            errorMessage: error.toString(),
          ),
        );
      },
    );
  }

  /// إجراء مكالمة هاتفية مباشرة عبر عتاد الهاتف
  Future<void> callContact(Contact contact) async {
    await _haptics.successNotification();
    await _sound.play(SoundCue.navCenter);
    await _assistant.speak('Calling ${contact.name}');
    await _hardwareRepo.callPhoneNumber(contact.phoneNumber);
  }

  /// نطق تفاصيل جهة الاتصال للمكفوفين
  Future<void> readContactDetailsAloud(Contact contact) async {
    await _haptics.successNotification();
    final relation = contact.relationship != null
        ? 'Relationship: ${contact.relationship}.'
        : '';
    final type =
        contact.isEmergency ? 'Emergency SOS contact.' : 'Standard contact.';
    await _assistant.speak(
      '${contact.name}. $relation $type Phone number: ${contact.phoneNumber}',
    );
  }

  /// قراءة الرسالة الواردة وتمييزها كمقروءة فوراً
  Future<void> readMessageAloud(MessagesVaultData message) async {
    await _haptics.successNotification();
    await _sound.play(SoundCue.processing);

    final announcement =
        'Message on ${message.platform.toUpperCase()} from ${message.senderName}: ${message.messageText}';
    await _assistant.speak(announcement);

    await _commsRepo.markMessagesAsRead(message.contactIdentifier);
    final unread = await _commsRepo.getUnreadMessages();
    emit(state.copyWith(recentMessages: unread));
  }

  /// إضافة جهة اتصال جديدة إلى قاعدة البيانات المحلية والسحابية
  Future<void> addNewContact({
    required String name,
    required String phoneNumber,
    String? relationship,
    bool isEmergency = false,
  }) async {
    try {
      await _commsRepo.saveContact(
        name: name,
        phoneNumber: phoneNumber,
        relationship: relationship,
        isEmergency: isEmergency,
      );
      await _haptics.successNotification();
      await _sound.play(SoundCue.success);
      final role = isEmergency ? 'as an emergency contact' : 'to contacts';
      await _assistant.speak('Contact $name added $role.');
    } catch (e) {
      await _haptics.errorAlert();
      await _sound.play(SoundCue.error);
      emit(state.copyWith(errorMessage: 'Failed to add contact: $e'));
    }
  }

  /// حذف جهة اتصال مع التأكيد الصوتي
  Future<void> deleteContact(Contact contact) async {
    try {
      await _commsRepo.deleteContact(contact.id);
      await _haptics.successNotification();
      await _sound.play(SoundCue.navCenter);
      await _assistant.speak('Contact ${contact.name} deleted.');
    } catch (e) {
      await _haptics.errorAlert();
    }
  }

  /// إطلاق رادار الاستغاثة وبث الموقع الحقيقي عبر الأقمار الصناعية
  Future<void> triggerEmergencySos() async {
    emit(state.copyWith(isSosBroadcasting: true));

    await _sound.play(SoundCue.sosAlarm);
    await _haptics.emergencyAlarmPulse();

    await _assistant.speak(
      'Emergency SOS broadcast initiated! Broadcasting real GPS coordinates to family radar.',
    );

    await _commsRepo.triggerEmergencySos();

    await Future<void>.delayed(const Duration(seconds: 4));
    emit(state.copyWith(isSosBroadcasting: false));
  }

  /// مزامنة جهات اتصال الهاتف وتسويتها تفاضلياً داخل الخزنة مع تغذية صوتية ولمسية
  Future<void> syncDeviceContacts() async {
    if (state.isSyncingContacts) return;

    emit(state.copyWith(isSyncingContacts: true));
    _haptics.selectionClick();
    await _sound.play(SoundCue.processing);
    await _assistant.speak('Reconciling contacts from your device...');

    final result = await _commsRepo.syncDeviceContactsToVault();

    await _haptics.successNotification();
    await _sound.play(SoundCue.success);

    final feedback = _buildSyncFeedback(
      added: result.addedCount,
      updated: result.updatedCount,
      deleted: result.deletedCount,
    );

    await _assistant.speak(feedback);
    emit(state.copyWith(isSyncingContacts: false));
  }

  String _buildSyncFeedback({
    required int added,
    required int updated,
    required int deleted,
  }) {
    if (added == 0 && updated == 0 && deleted == 0) {
      return 'Your contacts are already completely up to date.';
    }

    final summaryParts = <String>[];
    if (added > 0) summaryParts.add('$added new contacts added');
    if (updated > 0) summaryParts.add('$updated updated');
    if (deleted > 0) summaryParts.add('$deleted removed');

    return 'Contacts reconciled: ${summaryParts.join(', ')}.';
  }

  @override
  Future<void> close() {
    _contactsSubscription?.cancel();
    return super.close();
  }
}

// 🛡️ اسم توافقي لمنع انكسار أي كود قديم
typedef CommunicationsCubit = CommsCubit;