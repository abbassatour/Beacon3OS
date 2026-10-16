// lib/desktop/cubit/desktop_comms_cubit.dart
import 'dart:async';
import 'dart:developer';

import 'package:beacon_os/desktop/comms/cubit/desktop_comms_state.dart';
import 'package:bloc/bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';
import 'package:local_vault_api/local_vault_api.dart';

class DesktopCommsCubit extends Cubit<DesktopCommsState> {
  DesktopCommsCubit({
    required CommsRepository commsRepository,
  })  : _commsRepo = commsRepository,
        super(const DesktopCommsState()) {
    _initStreams();
  }

  final CommsRepository _commsRepo;
  StreamSubscription<List<Contact>>? _contactsSub;

  void _initStreams() {
    emit(state.copyWith(status: DesktopCommsStatus.loading));

    _contactsSub = _commsRepo.watchContacts().listen(
      (contactList) async {
        final unread = await _commsRepo.getUnreadMessages();
        emit(
          state.copyWith(
            status: DesktopCommsStatus.success,
            contacts: contactList,
            unreadMessages: unread,
          ),
        );
      },
      onError: (Object error) {
        log('DesktopCommsCubit: Error watching contacts: $error');
        emit(
          state.copyWith(
            status: DesktopCommsStatus.error,
            errorMessage: error.toString(),
          ),
        );
      },
    );
  }

  void setSearchQuery(String query) {
    emit(state.copyWith(searchQuery: query.trim()));
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
    } catch (e) {
      log('DesktopCommsCubit: Error adding contact: $e');
      emit(state.copyWith(errorMessage: 'Failed to add contact: $e'));
    }
  }

  Future<void> toggleEmergencyStatus(Contact contact) async {
    try {
      // Ø¥Ø²Ø§Ù„Ø© Ø§Ù„Ù‚Ø¯ÙŠÙ… ÙˆØ­ÙØ¸Ù‡ Ø¨Ø§Ù„Ø­Ø§Ù„Ø© Ø§Ù„Ø¬Ø¯ÙŠØ¯Ø©
      await _commsRepo.deleteContact(contact.id);
      await _commsRepo.saveContact(
        name: contact.name,
        phoneNumber: contact.phoneNumber,
        relationship: contact.relationship,
        isEmergency: !contact.isEmergency,
      );
    } catch (e) {
      log('DesktopCommsCubit: Error toggling emergency contact: $e');
    }
  }

  Future<void> deleteContact(Contact contact) async {
    try {
      await _commsRepo.deleteContact(contact.id);
    } catch (e) {
      log('DesktopCommsCubit: Error deleting contact: $e');
    }
  }

  Future<void> syncDeviceContacts() async {
    if (state.isSyncingContacts) return;
    emit(state.copyWith(isSyncingContacts: true));

    try {
      await _commsRepo.syncDeviceContactsToVault();
    } catch (e) {
      log('DesktopCommsCubit: Contacts sync error: $e');
    } finally {
      emit(state.copyWith(isSyncingContacts: false));
    }
  }

  Future<void> markMessageAsRead(MessagesVaultData msg) async {
    try {
      await _commsRepo.markMessagesAsRead(msg.contactIdentifier);
      final unread = await _commsRepo.getUnreadMessages();
      emit(state.copyWith(unreadMessages: unread));
    } catch (e) {
      log('DesktopCommsCubit: Error marking message read: $e');
    }
  }

  /// Ø¥Ø·Ù„Ø§Ù‚ Ø¨Ø« Ø±Ø§Ø¯Ø§Ø± Ø·ÙˆØ§Ø±Ø¦ ØªØ¬Ø±ÙŠØ¨ÙŠ Ù„Ù„ØªØ­Ù‚Ù‚ Ù…Ù† Ø§Ù„Ø§ØªØµØ§Ù„ Ø§Ù„Ø³Ø­Ø§Ø¨ÙŠ
  Future<void> triggerTestSosBroadcast() async {
    if (state.isBroadcastingSos) return;

    emit(state.copyWith(isBroadcastingSos: true));

    try {
      final alertId = await _commsRepo.triggerEmergencySos(
        latitude: 52.3676, // Ø¥Ø­Ø¯Ø§Ø«ÙŠØ§Øª Ù…Ø±Ø¬Ø¹ÙŠØ©
        longitude: 4.9041,
        batteryLevel: 95,
      );

      emit(state.copyWith(lastSosAlertId: alertId));
      await Future<void>.delayed(const Duration(seconds: 3));
    } catch (e) {
      log('DesktopCommsCubit: Error triggering test SOS: $e');
    } finally {
      emit(state.copyWith(isBroadcastingSos: false));
    }
  }

  @override
  Future<void> close() {
    _contactsSub?.cancel();
    return super.close();
  }
}
