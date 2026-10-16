// lib/tv/shell/cubit/tv_shell_state.dart
import 'package:equatable/equatable.dart';
import 'package:launcher_repository/launcher_repository.dart';

/// أنماط العرض الرئيسية لشاشة التلفاز
enum TvMode {
  checkingLink, // جاري التحقق من حالة الارتباط السابقة
  pairing,      // شاشة الاقتران السيادي الصفرية (6 أرقام)
  dashboard,    // اللوحة التفاعلية للبطاقات الأربع (2x2 Matrix)
  ambient,      // شاشة التوقف الخاملة والساعة التسكينية
}

class TvShellState extends Equatable {
  const TvShellState({
    this.mode = TvMode.checkingLink,
    this.isDeviceLinked = false,
    this.activePairingCode,
    this.transportMode = SyncTransportMode.discovering,
    this.activeAlert,
    required this.currentTime,
    this.errorMessage,
  });

  final TvMode mode;
  final bool isDeviceLinked;
  final String? activePairingCode;
  final SyncTransportMode transportMode;
  final RemoteActionEvent? activeAlert;
  final DateTime currentTime;
  final String? errorMessage;

  bool get isCheckingLink => mode == TvMode.checkingLink;
  bool get isPairing => mode == TvMode.pairing;
  bool get isDashboard => mode == TvMode.dashboard;
  bool get isAmbient => mode == TvMode.ambient;
  bool get hasActiveAlert => activeAlert != null;

  TvShellState copyWith({
    TvMode? mode,
    bool? isDeviceLinked,
    String? activePairingCode,
    bool clearPairingCode = false,
    SyncTransportMode? transportMode,
    RemoteActionEvent? activeAlert,
    bool clearActiveAlert = false,
    DateTime? currentTime,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return TvShellState(
      mode: mode ?? this.mode,
      isDeviceLinked: isDeviceLinked ?? this.isDeviceLinked,
      activePairingCode: clearPairingCode
          ? null
          : (activePairingCode ?? this.activePairingCode),
      transportMode: transportMode ?? this.transportMode,
      activeAlert:
          clearActiveAlert ? null : (activeAlert ?? this.activeAlert),
      currentTime: currentTime ?? this.currentTime,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        mode,
        isDeviceLinked,
        activePairingCode,
        transportMode,
        activeAlert,
        currentTime,
        errorMessage,
      ];
}