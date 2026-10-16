// lib/tv/cards/locator/cubit/tv_locator_state.dart
import 'package:equatable/equatable.dart';

enum TvLocatorStatus { idle, pinging, success, error }

class TvLocatorState extends Equatable {
  const TvLocatorState({
    this.status = TvLocatorStatus.idle,
    this.lastPingedAt,
    this.errorMessage,
  });

  final TvLocatorStatus status;
  final DateTime? lastPingedAt;
  final String? errorMessage;

  bool get isPinging => status == TvLocatorStatus.pinging;

  TvLocatorState copyWith({
    TvLocatorStatus? status,
    DateTime? lastPingedAt,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return TvLocatorState(
      status: status ?? this.status,
      lastPingedAt: lastPingedAt ?? this.lastPingedAt,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, lastPingedAt, errorMessage];
}