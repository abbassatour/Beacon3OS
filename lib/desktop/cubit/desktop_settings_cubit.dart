// lib/desktop/cubit/desktop_settings_cubit.dart
import 'dart:async';
import 'dart:developer';

import 'package:beacon_os/desktop/cubit/desktop_settings_state.dart';
import 'package:bloc/bloc.dart';
import 'package:drift/drift.dart';
import 'package:launcher_repository/launcher_repository.dart';
import 'package:local_vault_api/local_vault_api.dart';
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

  StreamSubscription<AppSetting>? _settingsSub;

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

  Future<void> updateSetting(AppSettingsCompanion companion) async {
    try {
      await _settingsRepo.updateSettings(companion);
    } catch (e) {
      log('DesktopSettingsCubit: Error updating setting: $e');
    }
  }

  Future<void> setPersona(String persona) async {
    await updateSetting(AppSettingsCompanion(userPersona: Value(persona)));
  }

  Future<void> setHighContrast(bool enabled) async {
    await updateSetting(AppSettingsCompanion(isHighContrast: Value(enabled)));
  }

  Future<void> setSpeechRate(double rate) async {
    await updateSetting(AppSettingsCompanion(speechRate: Value(rate)));
  }

  /// إجبار المزامنة الثنائية الكاملة عبر كافة المستودعات
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
          lastSyncMessage: 'Full Vault Sync Complete • Realtime Live',
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