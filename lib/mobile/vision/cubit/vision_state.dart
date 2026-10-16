// lib/vision/cubit/vision_state.dart
import 'package:equatable/equatable.dart';

enum VisionStatus { idle, capturing, analyzing, speaking, error }

enum VisionMode {
  surroundings, // المحيط والعوائق
  textReader,   // قراءة المستندات واللافتات
  currency,     // قراءة النقود والعملات
  productExpiry // اسم المنتج وتاريخ الصلاحية
}

class VisionState extends Equatable {
  const VisionState({
    this.status = VisionStatus.idle,
    this.activeMode = VisionMode.surroundings,
    this.lastSpokenResult = '',
    this.isTorchOn = false,
    this.isSavingNote = false,
    this.errorMessage,
  });

  final VisionStatus status;
  final VisionMode activeMode;
  final String lastSpokenResult;
  final bool isTorchOn;
  final bool isSavingNote;
  final String? errorMessage;

  bool get isBusy =>
      status == VisionStatus.capturing || status == VisionStatus.analyzing;

  bool get isSpeaking => status == VisionStatus.speaking;

  VisionState copyWith({
    VisionStatus? status,
    VisionMode? activeMode,
    String? lastSpokenResult,
    bool? isTorchOn,
    bool? isSavingNote,
    String? errorMessage,
  }) {
    return VisionState(
      status: status ?? this.status,
      activeMode: activeMode ?? this.activeMode,
      lastSpokenResult: lastSpokenResult ?? this.lastSpokenResult,
      isTorchOn: isTorchOn ?? this.isTorchOn,
      isSavingNote: isSavingNote ?? this.isSavingNote,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        activeMode,
        lastSpokenResult,
        isTorchOn,
        isSavingNote,
        errorMessage,
      ];
}
