// lib/tv/cards/safety/cubit/tv_safety_state.dart
import 'package:equatable/equatable.dart';

enum TvSafetyStatus { idle, broadcasting, success, error }

class TvSafetyState extends Equatable {
  const TvSafetyState({
    this.status = TvSafetyStatus.idle,
    this.lastSosAlertId,
    this.isArbitrumAttested = true,
    this.errorMessage,
  });

  final TvSafetyStatus status;
  final String? lastSosAlertId;
  final bool isArbitrumAttested;
  final String? errorMessage;

  bool get isBroadcasting => status == TvSafetyStatus.broadcasting;

  TvSafetyState copyWith({
    TvSafetyStatus? status,
    String? lastSosAlertId,
    bool? isArbitrumAttested,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return TvSafetyState(
      status: status ?? this.status,
      lastSosAlertId: lastSosAlertId ?? this.lastSosAlertId,
      isArbitrumAttested: isArbitrumAttested ?? this.isArbitrumAttested,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        lastSosAlertId,
        isArbitrumAttested,
        errorMessage,
      ];
}