// lib/core/voice_bus/ambient_voice/cubit/ambient_voice_state.dart
import 'package:equatable/equatable.dart';

enum AmbientVoiceStatus {
  idle,
  listening,
  processing,
  speaking,
  error,
}

class AmbientVoiceState extends Equatable {
  const AmbientVoiceState({
    this.status = AmbientVoiceStatus.idle,
    this.liveTranscript = '',
    this.soundLevel = 0.0,
    this.spokenResponse = '',
    this.intent,
    this.errorMessage,
  });

  final AmbientVoiceStatus status;
  final String liveTranscript;
  final double soundLevel;
  final String spokenResponse;
  final String? intent;
  final String? errorMessage;

  bool get isOpen => status != AmbientVoiceStatus.idle;
  bool get isListening => status == AmbientVoiceStatus.listening;
  bool get isProcessing => status == AmbientVoiceStatus.processing;
  bool get isSpeaking => status == AmbientVoiceStatus.speaking;

  AmbientVoiceState copyWith({
    AmbientVoiceStatus? status,
    String? liveTranscript,
    double? soundLevel,
    String? spokenResponse,
    String? intent,
    String? errorMessage,
  }) {
    return AmbientVoiceState(
      status: status ?? this.status,
      liveTranscript: liveTranscript ?? this.liveTranscript,
      soundLevel: soundLevel ?? this.soundLevel,
      spokenResponse: spokenResponse ?? this.spokenResponse,
      intent: intent ?? this.intent,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        liveTranscript,
        soundLevel,
        spokenResponse,
        intent,
        errorMessage,
      ];
}