// lib/desktop/settings/cubit/desktop_settings_cubit.dart
import 'dart:async';
import 'dart:developer';

import 'package:beacon_os/desktop/settings/cubit/desktop_settings_state.dart';
import 'package:bloc/bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DesktopSettingsCubit extends Cubit<DesktopSettingsState> {
  DesktopSettingsCubit({
    required SettingsRepository settingsRepository,
    required TaskAgendaRepository taskRepository,
    required FocusAlarmsRepository focusAlarmsRepository,
    required CommsRepository commsRepository,
    required TopologyRepository topologyRepository,
  })  : _settingsRepo = settingsRepository,
        _taskRepo = taskRepository,
        _focusRepo = focusAlarmsRepository,
        _commsRepo = commsRepository,
        _topologyRepo = topologyRepository,
        super(const DesktopSettingsState()) {
    _initStream();
    _checkAuthStatus();
  }

  final SettingsRepository _settingsRepo;
  final TaskAgendaRepository _taskRepo;
  final FocusAlarmsRepository _focusRepo;
  final CommsRepository _commsRepo;
  final TopologyRepository _topologyRepo;

  StreamSubscription<AppSettingEntity>? _settingsSub;

  void _initStream() {
    emit(state.copyWith(status: DesktopSettingsStatus.loading));

    _settingsSub = _settingsRepo.watchSettings().listen(
      (settings) {
        emit(
          state.copyWith(
            status: DesktopSettingsStatus.success,
            settings: settings,
          ),
        );
      },
      onError: (Object error) {
        log('DesktopSettingsCubit: Error watching settings: $error');
        emit(
          state.copyWith(
            status: DesktopSettingsStatus.error,
            errorMessage: error.toString(),
          ),
        );
      },
    );
  }

  void _checkAuthStatus() {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      emit(
        state.copyWith(
          isOnline: user != null,
          userEmail: user?.email ?? 'Local Offline Vault',
        ),
      );
    } catch (_) {
      emit(state.copyWith(isOnline: false, userEmail: 'Local Offline Vault'));
    }
  }

  Future<void> updateSetting(AppSettingUpdatePayload payload) async {
    try {
      await _settingsRepo.updateSettings(payload);
    } catch (e) {
      log('DesktopSettingsCubit: Error updating setting: $e');
    }
  }

  Future<void> setPersona(String persona) async {
    await updateSetting(AppSettingUpdatePayload(userPersona: persona));
  }

  Future<void> setHighContrast(bool enabled) async {
    await updateSetting(AppSettingUpdatePayload(isHighContrast: enabled));
  }

  Future<void> setSpeechRate(double rate) async {
    await updateSetting(AppSettingUpdatePayload(speechRate: rate));
  }

  /// 🧭 ضبط همس الغرف الصوتي
  Future<void> setSpatialWhisper(bool enabled) async {
    await updateSetting(AppSettingUpdatePayload(spatialWhisperEnabled: enabled));
  }

  Future<void> forceFullSync() async {
    if (state.isSyncing) return;

    emit(state.copyWith(isSyncing: true, lastSyncMessage: 'Synchronizing with Supabase...'));

    try {
      await Future.wait([
        _settingsRepo.syncPendingSettings(),
        _taskRepo.syncPendingTasksAndMemos(),
        _focusRepo.syncPendingAlarms(),
        _commsRepo.syncPendingComms(),
        _topologyRepo.syncPendingTopology(),
      ]);

      await _settingsRepo.restoreSettingsFromCloud();

      emit(
        state.copyWith(
          isSyncing: false,
          lastSyncMessage: 'Full Vault Sync Complete - Realtime Live',
        ),
      );
    } catch (e) {
      log('DesktopSettingsCubit: Force sync error: $e');
      emit(
        state.copyWith(
          isSyncing: false,
          lastSyncMessage: 'Sync skipped or network offline: $e',
        ),
      );
    }
  }

  @override
  Future<void> close() {
    _settingsSub?.cancel();
    return super.close();
  }
}