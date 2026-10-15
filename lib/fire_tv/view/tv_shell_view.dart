import 'dart:async';
import 'package:beacon_os/core/audio/sound_controller.dart';
import 'package:beacon_os/core/audio/sound_cue.dart';
import 'package:beacon_os/core/theme/app_theme.dart';
import 'package:beacon_os/fire_tv/widgets/tv_ambient_screensaver.dart';
import 'package:beacon_os/fire_tv/widgets/tv_dashboard_view.dart';
import 'package:beacon_os/fire_tv/widgets/tv_pairing_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:launcher_repository/launcher_repository.dart';

class TvShellView extends StatefulWidget {
  const TvShellView({super.key});

  @override
  State<TvShellView> createState() => _TvShellViewState();
}

class _TvShellViewState extends State<TvShellView> {
  late Timer _clockTimer;
  DateTime _currentTime = DateTime.now();

  bool _isCheckingLink = true;
  bool _isDeviceLinked = false;
  String? _activePairingCode;
  StreamSubscription<String?>? _pairingSubscription;

  SyncTransportMode _transportMode = SyncTransportMode.discovering;
  StreamSubscription<SyncTransportMode>? _transportSubscription;

  StreamSubscription<RemoteActionEvent>? _remoteSub;
  RemoteActionEvent? _activeAlert;
  Timer? _alertDismissTimer;

  Timer? _screensaverTimer;
  bool _isAmbientMode = false;

  final FocusNode _locateCardFocus = FocusNode();
  final FocusNode _sosCardFocus = FocusNode();
  final FocusNode _agendaFocus = FocusNode();
  final FocusNode _alarmsFocus = FocusNode();
  final FocusNode _refreshCodeFocus = FocusNode();
  final FocusNode _skipPairingFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _currentTime = DateTime.now());
    });

    _resetScreensaverTimer();
    _initHybridEngineAndPairing();
    _listenToRemoteActions();
  }

  Future<void> _initHybridEngineAndPairing() async {
    final commsRepo = context.read<CommsRepository>();

    await commsRepo.initializeHybridTransport(deviceType: 'fire_tv');

    _transportMode = commsRepo.currentTransportMode;
    _transportSubscription = commsRepo.transportModeStream.listen((mode) {
      if (!mounted) return;
      final prevMode = _transportMode;
      setState(() => _transportMode = mode);
      _announceTransportModeAloud(mode, prevMode);
    });

    final isLinked = await commsRepo.isDeviceLinked();
    if (!mounted) return;

    if (isLinked) {
      setState(() {
        _isDeviceLinked = true;
        _isCheckingLink = false;
      });
      _focusInitialDashboardCard();
    } else {
      setState(() => _isCheckingLink = false);
      _startNewPairingSession();
    }
  }

  Future<void> _announceTransportModeAloud(
    SyncTransportMode mode,
    SyncTransportMode prevMode,
  ) async {
    if (mode == prevMode) return;
    try {
      final assistant = context.read<AssistantRepository>();
      if (mode == SyncTransportMode.lanDirect) {
        await SoundController.instance.play(SoundCue.success);
        await assistant.speak('Living room screen linked on high-speed home network.');
      } else if (mode == SyncTransportMode.cloudRelay && prevMode == SyncTransportMode.lanDirect) {
        await assistant.speak('Local connection paused. Switched to cloud relay.');
      }
    } catch (_) {}
  }

  Future<void> _startNewPairingSession() async {
    _pairingSubscription?.cancel();
    final commsRepo = context.read<CommsRepository>();

    final code = await commsRepo.initiateDevicePairing(deviceType: 'fire_tv');
    if (!mounted) return;

    if (code != null) {
      setState(() => _activePairingCode = code);
      _announcePairingCodeAloud(code);

      _pairingSubscription = commsRepo.listenForDeviceAuthorization(code).listen((vaultId) {
        if (!mounted) return;
        if (vaultId != null && vaultId.isNotEmpty) {
          _onPairingSuccessful();
        }
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isDeviceLinked) {
        _refreshCodeFocus.requestFocus();
      }
    });
  }

  Future<void> _announcePairingCodeAloud(String code) async {
    try {
      final assistant = context.read<AssistantRepository>();
      final spacedDigits = code.split('').join(', ');
      await SoundController.instance.play(SoundCue.wake);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await assistant.speak(
        'Living Room TV is ready to connect. Hold anywhere on your Beacon phone and say: Pair $spacedDigits.',
      );
    } catch (_) {}
  }

  Future<void> _onPairingSuccessful() async {
    await SoundController.instance.play(SoundCue.success);

    try {
      final assistant = context.read<AssistantRepository>();
      await assistant.speak(
        'Living Room TV linked successfully! Telemetry, agenda, and safety radar are now synchronized.',
      );
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isDeviceLinked = true;
        _activePairingCode = null;
      });
      _focusInitialDashboardCard();
    }
  }

  Future<void> _unpairDevice() async {
    final commsRepo = context.read<CommsRepository>();
    await commsRepo.unpairDevice();
    if (mounted) {
      setState(() => _isDeviceLinked = false);
      _startNewPairingSession();
    }
  }

  void _listenToRemoteActions() {
    final commsRepo = context.read<CommsRepository>();
    _remoteSub = commsRepo.remoteActionEvents.listen((event) {
      if (!mounted) return;

      _wakeFromAmbient();
      setState(() => _activeAlert = event);

      if (event.actionType == RemoteActionType.triggerSos) {
        SoundController.instance.play(SoundCue.sosAlarm);
      } else if (event.actionType == RemoteActionType.locateDevice) {
        SoundController.instance.play(SoundCue.wake);
      }

      _alertDismissTimer?.cancel();
      _alertDismissTimer = Timer(const Duration(seconds: 20), () {
        if (mounted) {
          setState(() => _activeAlert = null);
          SoundController.instance.stopAll();
        }
      });
    });
  }

  void _focusInitialDashboardCard() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isDeviceLinked) {
        _locateCardFocus.requestFocus();
      }
    });
  }

  void _resetScreensaverTimer() {
    _screensaverTimer?.cancel();
    _screensaverTimer = Timer(const Duration(seconds: 75), () {
      if (mounted && _activeAlert == null) {
        setState(() => _isAmbientMode = true);
      }
    });
  }

  void _wakeFromAmbient() {
    _resetScreensaverTimer();
    if (_isAmbientMode) {
      setState(() => _isAmbientMode = false);
      if (_isDeviceLinked) {
        _locateCardFocus.requestFocus();
      } else {
        _refreshCodeFocus.requestFocus();
      }
    }
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _screensaverTimer?.cancel();
    _alertDismissTimer?.cancel();
    _remoteSub?.cancel();
    _pairingSubscription?.cancel();
    _transportSubscription?.cancel();
    _locateCardFocus.dispose();
    _sosCardFocus.dispose();
    _agendaFocus.dispose();
    _alarmsFocus.dispose();
    _refreshCodeFocus.dispose();
    _skipPairingFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          _wakeFromAmbient();
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: context.scaffoldBg,
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            child: _resolveActiveScreen(context),
          ),
        ),
      ),
    );
  }

  Widget _resolveActiveScreen(BuildContext context) {
    if (_isCheckingLink) {
      return const Center(
        key: ValueKey('tv_checking_link'),
        child: CircularProgressIndicator(),
      );
    }

    if (_isAmbientMode) {
      return TvAmbientScreensaver(currentTime: _currentTime);
    }

    if (!_isDeviceLinked) {
      return TvPairingView(
        pairingCode: _activePairingCode,
        refreshCodeFocus: _refreshCodeFocus,
        skipPairingFocus: _skipPairingFocus,
        onRefreshCode: _startNewPairingSession,
        onContinueStandalone: () {
          setState(() => _isDeviceLinked = true);
          _focusInitialDashboardCard();
        },
      );
    }

    return TvDashboardView(
      currentTime: _currentTime,
      transportMode: _transportMode,
      activeAlert: _activeAlert,
      locateCardFocus: _locateCardFocus,
      sosCardFocus: _sosCardFocus,
      agendaFocus: _agendaFocus,
      alarmsFocus: _alarmsFocus,
      onUnpair: _unpairDevice,
      onDismissAlert: () {
        setState(() => _activeAlert = null);
        SoundController.instance.stopAll();
      },
    );
  }
}