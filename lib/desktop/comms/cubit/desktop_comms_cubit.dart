// lib/desktop/comms/cubit/desktop_comms_cubit.dart
import 'dart:async';
import 'dart:developer';

import 'package:beacon_os/desktop/comms/cubit/desktop_comms_state.dart';
import 'package:bloc/bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';

class DesktopCommsCubit extends Cubit<DesktopCommsState> {
  DesktopCommsCubit({
    required CommsRepository commsRepository,
    required SafetyRadarRepository safetyRadarRepository,
  })  : _commsRepo = commsRepository,
        _safetyRadar = safetyRadarRepository,
        super(const DesktopCommsState()) {
    _initStreams();
  }

  final CommsRepository _commsRepo;
  final SafetyRadarRepository _safetyRadar;
  StreamSubscription<List<ContactEntity>>? _contactsSub;

  void _initStreams() {
    emit(state.copyWith(status: DesktopCommsStatus.loading));

    _contactsSub = _commsRepo.watchContacts().listen(
      (contactList) async {
        if (isClosed) return;
        final unread = await _commsRepo.getUnreadMessages();
        if (isClosed) return;
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
        if (!isClosed) {
          emit(
            state.copyWith(
              status: DesktopCommsStatus.error,
              errorMessage: error.toString(),
            ),
          );
        }
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
      if (!isClosed) {
        emit(state.copyWith(errorMessage: 'Failed to add contact: $e'));
      }
    }
  }

  Future<void> toggleEmergencyStatus(ContactEntity contact) async {
    try {
      await _commsRepo.toggleEmergencyStatus(
        contact.id,
        isEmergency: !contact.isEmergency,
      );
    } catch (e) {
      log('DesktopCommsCubit: Error toggling emergency contact: $e');
      if (!isClosed) {
        emit(state.copyWith(errorMessage: 'Failed to update contact status: $e'));
      }
    }
  }

  Future<void> deleteContact(ContactEntity contact) async {
    try {
      await _commsRepo.deleteContact(contact.id);
    } catch (e) {
      log('DesktopCommsCubit: Error deleting contact: $e');
      if (!isClosed) {
        emit(state.copyWith(errorMessage: 'Failed to delete contact: $e'));
      }
    }
  }

  Future<void> syncDeviceContacts() async {
    if (state.isSyncingContacts) return;
    emit(state.copyWith(isSyncingContacts: true));

    try {
      final result = await _commsRepo.syncDeviceContactsToVault();
      if (result.permissionDenied && !isClosed) {
        emit(state.copyWith(
          errorMessage: 'Contacts permission denied or not supported on this platform.',
        ));
      }
    } catch (e) {
      log('DesktopCommsCubit: Contacts sync error: $e');
      if (!isClosed) {
        emit(state.copyWith(errorMessage: 'Sync error: $e'));
      }
    } finally {
      if (!isClosed) {
        emit(state.copyWith(isSyncingContacts: false));
      }
    }
  }

  Future<void> markMessageAsRead(MessageEntity msg) async {
    try {
      await _commsRepo.markMessagesAsRead(msg.contactIdentifier);
      final unread = await _commsRepo.getUnreadMessages();
      if (!isClosed) {
        emit(state.copyWith(unreadMessages: unread));
      }
    } catch (e) {
      log('DesktopCommsCubit: Error marking message read: $e');
    }
  }

  Future<void> triggerTestSosBroadcast() async {
    if (state.isBroadcastingSos) return;

    emit(state.copyWith(isBroadcastingSos: true));

    try {
      final alertId = await _safetyRadar.triggerEmergencySos(
        latitude: 52.3676,
        longitude: 4.9041,
        batteryLevel: 95,
      );

      if (!isClosed) {
        emit(state.copyWith(lastSosAlertId: alertId));
      }
      await Future<void>.delayed(const Duration(seconds: 3));
    } catch (e) {
      log('DesktopCommsCubit: Error triggering test SOS: $e');
      if (!isClosed) {
        emit(state.copyWith(errorMessage: 'Failed to broadcast SOS: $e'));
      }
    } finally {
      if (!isClosed) {
        emit(state.copyWith(isBroadcastingSos: false));
      }
    }
  }

  @override
  Future<void> close() {
    _contactsSub?.cancel();
    return super.close();
  }
}