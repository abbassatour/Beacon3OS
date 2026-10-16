// lib/tv/shell/cubit/tv_shell_cubit.dart
import 'dart:async';
import 'dart:developer';

import 'package:beacon_os/core/audio/sound_controller.dart';
import 'package:beacon_os/core/audio/sound_cue.dart';
import 'package:beacon_os/tv/shell/cubit/tv_shell_state.dart';
import 'package:bloc/bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';

class TvShellCubit extends Cubit<TvShellState> {
  TvShellCubit({
    required CommsRepository commsRepository,
    required AssistantRepository assistantRepository,
    SoundController? soundController,
  })  : _commsRepo = commsRepository,
        _assistant = assistantRepository,
        _sound = soundController ?? SoundController.instance,
        super(TvShellState(currentTime: DateTime.now())) {
    _initEngine();
  }

  final CommsRepository _commsRepo;
  final AssistantRepository _assistant;
  final SoundController _sound;

  Timer? _clockTimer;
  Timer? _screensaverTimer;
  Timer? _alertDismissTimer;

  StreamSubscription<SyncTransportMode>? _transportSub;
  StreamSubscription<String?>? _pairingAuthSub;
  StreamSubscription<RemoteActionEvent>? _remoteActionsSub;

  static const Duration _screensaverTimeout = Duration(seconds: 75);
  static const Duration _alertDismissDuration = Duration(seconds: 20);

  Future<void> _initEngine() async {
    _startClockTicker();
    _resetScreensaverTimer();
    _listenToRemoteActions();

    await _initHybridTransport();
  }

  // ===========================================================================
  // ⏰ 1. إدارة الوقت وشاشة التوقف الخاملة (Ambient & Clock Engine)
  // ===========================================================================

  void _startClockTicker() {
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      final now = DateTime.now();
      if (now.minute != state.currentTime.minute ||
          now.hour != state.currentTime.hour) {
        emit(state.copyWith(currentTime: now));
      }
    });
  }

  void _resetScreensaverTimer() {
    _screensaverTimer?.cancel();
    _screensaverTimer = Timer(_screensaverTimeout, () {
      if (!isClosed && !state.hasActiveAlert) {
        emit(state.copyWith(mode: TvMode.ambient));
      }
    });
  }

  /// إيقاظ الشاشة من وضع الخمول عند الضغط على أي زر في الريموت
  void wakeFromAmbient() {
    _resetScreensaverTimer();
    if (state.isAmbient) {
      final targetMode =
          state.isDeviceLinked ? TvMode.dashboard : TvMode.pairing;
      emit(state.copyWith(mode: targetMode));
    }
  }

  // ===========================================================================
  // 🛰️ 2. النقل الهجين والاقتران اللاتمركزي (Transport & Pairing)
  // ===========================================================================

  Future<void> _initHybridTransport() async {
    try {
      await _commsRepo.initializeHybridTransport(deviceType: 'fire_tv');

      _transportSub?.cancel();
      _transportSub = _commsRepo.transportModeStream.listen((mode) {
        if (isClosed) return;
        final prevMode = state.transportMode;
        emit(state.copyWith(transportMode: mode));
        _announceTransportChange(mode, prevMode);
      });

      final isLinked = await _commsRepo.isDeviceLinked();
      if (isClosed) return;

      if (isLinked) {
        emit(
          state.copyWith(
            mode: TvMode.dashboard,
            isDeviceLinked: true,
          ),
        );
      } else {
        await startNewPairingSession();
      }
    } catch (e) {
      log('TvShellCubit: Error initializing hybrid transport: $e');
      emit(
        state.copyWith(
          mode: TvMode.dashboard,
          errorMessage: 'Running in standalone mode: $e',
        ),
      );
    }
  }

  Future<void> startNewPairingSession() async {
    _pairingAuthSub?.cancel();
    emit(state.copyWith(mode: TvMode.pairing, isDeviceLinked: false));

    final code = await _commsRepo.initiateDevicePairing(deviceType: 'fire_tv');
    if (isClosed || code == null) return;

    emit(state.copyWith(activePairingCode: code));
    _announcePairingCodeAloud(code);

    _pairingAuthSub =
        _commsRepo.listenForDeviceAuthorization(code).listen((vaultId) {
      if (vaultId != null && vaultId.isNotEmpty) {
        _onPairingAuthorized();
      }
    });
  }

  Future<void> _announcePairingCodeAloud(String code) async {
    try {
      final spaced = code.split('').join(', ');
      await _sound.play(SoundCue.wake);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await _assistant.speak(
        'Living Room TV is ready to connect. Hold anywhere on your phone and say: Pair $spaced.',
      );
    } catch (_) {}
  }

  Future<void> _onPairingAuthorized() async {
    await _sound.play(SoundCue.success);
    emit(
      state.copyWith(
        mode: TvMode.dashboard,
        isDeviceLinked: true,
        clearPairingCode: true,
      ),
    );

    try {
      await _assistant.speak(
        'Living Room TV linked successfully! Real-time telemetry and agenda are live.',
      );
    } catch (_) {}
  }

  Future<void> unpairDevice() async {
    await _commsRepo.unpairDevice();
    await startNewPairingSession();
  }

  void continueStandalone() {
    emit(state.copyWith(mode: TvMode.dashboard));
  }

  // ===========================================================================
  // 🚨 3. رادار الطوارئ والـ Ping الوارد (Remote Actions)
  // ===========================================================================

  void _listenToRemoteActions() {
    _remoteActionsSub?.cancel();
    _remoteActionsSub = _commsRepo.remoteActionEvents.listen((event) {
      if (isClosed) return;

      wakeFromAmbient();
      emit(state.copyWith(activeAlert: event));

      if (event.actionType == RemoteActionType.triggerSos) {
        _sound.play(SoundCue.sosAlarm);
      } else if (event.actionType == RemoteActionType.locateDevice) {
        _sound.play(SoundCue.wake);
      }

      _alertDismissTimer?.cancel();
      _alertDismissTimer = Timer(_alertDismissDuration, () {
        dismissActiveAlert();
      });
    });
  }

  void dismissActiveAlert() {
    _alertDismissTimer?.cancel();
    _sound.stopAll();
    if (!isClosed) {
      emit(state.copyWith(clearActiveAlert: true));
    }
  }

  void _announceTransportChange(
    SyncTransportMode mode,
    SyncTransportMode prevMode,
  ) {
    if (mode == prevMode) return;
    if (mode == SyncTransportMode.lanDirect) {
      _sound.play(SoundCue.success);
      _assistant.speak('Living room screen linked via high-speed home network.');
    } else if (mode == SyncTransportMode.cloudRelay &&
        prevMode == SyncTransportMode.lanDirect) {
      _assistant.speak('Local connection paused. Switched to cloud relay.');
    }
  }

  @override
  Future<void> close() {
    _clockTimer?.cancel();
    _screensaverTimer?.cancel();
    _alertDismissTimer?.cancel();
    _transportSub?.cancel();
    _pairingAuthSub?.cancel();
    _remoteActionsSub?.cancel();
    return super.close();
  }
}