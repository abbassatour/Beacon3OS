// lib/mobile/comms/cubit/comms_cubit.dart
import 'dart:async';
import 'package:beacon_os/core/audio/sound_controller.dart';
import 'package:beacon_os/core/audio/sound_cue.dart';
import 'package:beacon_os/core/haptics/haptic_manager.dart';
import 'package:beacon_os/core/services/web3_service.dart';
import 'package:beacon_os/mobile/comms/cubit/comms_state.dart';
import 'package:bloc/bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';

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

  StreamSubscription<List<ContactEntity>>? _contactsSubscription;

  void _initStreams() {
    emit(state.copyWith(status: CommsStatus.loading));

    _contactsSubscription = _commsRepo.watchContacts().listen(
      (contactsList) async {
        if (isClosed) return;
        final messages = await _commsRepo.getUnreadMessages();
        if (isClosed) return;
        emit(
          state.copyWith(
            status: CommsStatus.success,
            contacts: contactsList,
            recentMessages: messages,
          ),
        );
      },
      onError: (Object error) {
        if (!isClosed) {
          emit(
            state.copyWith(
              status: CommsStatus.error,
              errorMessage: error.toString(),
            ),
          );
        }
      },
    );
  }

  Future<void> callContact(ContactEntity contact) async {
    await _haptics.successNotification();
    await _sound.play(SoundCue.navCenter);
    await _assistant.speak('Calling ${contact.name}');
    await _hardwareRepo.callPhoneNumber(contact.phoneNumber);
  }

  Future<void> readContactDetailsAloud(ContactEntity contact) async {
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

  Future<void> readMessageAloud(MessageEntity message) async {
    await _haptics.successNotification();
    await _sound.play(SoundCue.processing);

    final announcement =
        'Message on ${message.platform.toUpperCase()} from ${message.senderName}: ${message.messageText}';
    await _assistant.speak(announcement);

    await _commsRepo.markMessagesAsRead(message.contactIdentifier);
    final unread = await _commsRepo.getUnreadMessages();
    if (!isClosed) {
      emit(state.copyWith(recentMessages: unread));
    }
  }

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
      if (!isClosed) {
        emit(state.copyWith(errorMessage: 'Failed to add contact: $e'));
      }
    }
  }

  /// تبديل حالة الطوارئ لجهة الاتصال بأمان دون حذف السجل وإعادة إنشائه
  Future<void> toggleEmergencyStatus(ContactEntity contact) async {
    try {
      await _haptics.successNotification();
      await _sound.play(SoundCue.navCenter);
      final nextStatus = !contact.isEmergency;
      await _commsRepo.toggleEmergencyStatus(contact.id, isEmergency: nextStatus);

      final label = nextStatus
          ? 'promoted to emergency contact'
          : 'set as standard contact';
      await _assistant.speak('${contact.name} $label.');
    } catch (e) {
      await _haptics.errorAlert();
      await _sound.play(SoundCue.error);
    }
  }

  Future<void> deleteContact(ContactEntity contact) async {
    try {
      await _commsRepo.deleteContact(contact.id);
      await _haptics.successNotification();
      await _sound.play(SoundCue.navCenter);
      await _assistant.speak('Contact ${contact.name} deleted.');
    } catch (e) {
      await _haptics.errorAlert();
    }
  }

  Future<void> triggerEmergencySos() async {
    emit(state.copyWith(isSosBroadcasting: true));

    await _sound.play(SoundCue.sosAlarm);
    await _haptics.emergencyAlarmPulse();

    await _assistant.speak(
      'Emergency SOS broadcast initiated! Broadcasting real GPS coordinates and attesting to Arbitrum ledger.',
    );

    await _commsRepo.triggerEmergencySos();

    unawaited(
      _hardwareRepo.getCurrentLocation().then((coords) {
        if (coords != null) {
          return Web3Service.instance.attestEmergencySosOnChain(
            latitude: coords.latitude,
            longitude: coords.longitude,
          );
        }
      }).catchError((Object error) => null),
    );

    await Future<void>.delayed(const Duration(seconds: 4));
    if (!isClosed) {
      emit(state.copyWith(isSosBroadcasting: false));
    }
  }

  /// مزامنة دفتر هواتف الجهاز وتسويتها داخل الخزنة المشفرة
  Future<void> syncDeviceContacts() async {
    if (state.isSyncingContacts) return;

    emit(state.copyWith(isSyncingContacts: true));
    _haptics.selectionClick();
    await _sound.play(SoundCue.processing);
    await _assistant.speak('Reconciling contacts from your device...');

    final result = await _commsRepo.syncDeviceContactsToVault();

    // 🛡️ إذا كان الإذن محجوباً، نوجه المستخدم صوتياً بوضوح
    if (result.permissionDenied) {
      await _haptics.errorAlert();
      await _sound.play(SoundCue.error);
      await _assistant.speak(
        'Contacts permission is required to sync your phonebook. Please allow contacts access in settings.',
      );
      if (!isClosed) {
        emit(
          state.copyWith(
            isSyncingContacts: false,
            errorMessage: 'Contacts permission denied by user.',
          ),
        );
      }
      return;
    }

    await _haptics.successNotification();
    await _sound.play(SoundCue.success);

    final feedback = _buildSyncFeedback(
      added: result.addedCount,
      updated: result.updatedCount,
      deleted: result.deletedCount,
    );

    await _assistant.speak(feedback);
    if (!isClosed) {
      emit(state.copyWith(isSyncingContacts: false));
    }
  }

  String _buildSyncFeedback({
    required int added,
    required int updated,
    required int deleted,
  }) {
    if (added == 0 && updated == 0 && deleted == 0) {
      return 'Your contacts are already up to date.';
    }

    final summaryParts = <String>[];
    if (added > 0) summaryParts.add('$added new contacts added');
    if (updated > 0) summaryParts.add('$updated updated');

    return 'Contacts reconciled: ${summaryParts.join(', ')}.';
  }

  @override
  Future<void> close() {
    _contactsSubscription?.cancel();
    return super.close();
  }
}