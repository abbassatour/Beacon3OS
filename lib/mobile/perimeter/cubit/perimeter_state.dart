// lib/mobile/perimeter/cubit/perimeter_state.dart
import 'package:equatable/equatable.dart';
import 'package:launcher_repository/launcher_repository.dart';

enum PerimeterStatus {
  initial,
  loading,
  success,
  inspecting,
  speaking,
  answeringAudio,
  error,
}

class PerimeterState extends Equatable {
  const PerimeterState({
    this.status = PerimeterStatus.initial,
    this.devices = const [],
    this.recentEvents = const [],
    this.selectedDeviceId,
    this.liveInspectionText,
    this.isTwoWayAudioActive = false,
    this.activeAudioDeviceId,
    this.errorMessage,
  });

  final PerimeterStatus status;
  final List<RingDeviceEntity> devices;
  final List<RingEventEntity> recentEvents;
  final String? selectedDeviceId;
  final String? liveInspectionText;
  final bool isTwoWayAudioActive;
  final String? activeAudioDeviceId;
  final String? errorMessage;

  bool get isLoading => status == PerimeterStatus.loading;
  bool get isInspecting => status == PerimeterStatus.inspecting;
  bool get isSpeaking => status == PerimeterStatus.speaking;

  /// الكاميرا المحددة حالياً للمعاينة في الواجهة
  RingDeviceEntity? get selectedDevice {
    if (devices.isEmpty) return null;
    if (selectedDeviceId == null) return devices.first;
    return devices.where((d) => d.id == selectedDeviceId).firstOrNull ??
        devices.first;
  }

  /// كاميرا جرس الباب الأمامي
  RingDeviceEntity? get frontDoorCamera {
    return devices.where((d) => d.location == 'frontDoor').firstOrNull;
  }

  /// كاميرا الحديقة الخلفية
  RingDeviceEntity? get backyardCamera {
    return devices.where((d) => d.location == 'backyard').firstOrNull;
  }

  /// كاميرا الحضانة / غرفة الأطفال
  RingDeviceEntity? get nurseryCamera {
    return devices.where((d) => d.location == 'nursery').firstOrNull;
  }

  /// كاميرا المرآب / مدخل السيارات
  RingDeviceEntity? get garageCamera {
    return devices.where((d) => d.location == 'garage').firstOrNull;
  }

  /// عدد التنبيهات والأحداث الأمنية غير المقروءة
  int get unreadEventsCount =>
      recentEvents.where((e) => !e.isRead).length;

  PerimeterState copyWith({
    PerimeterStatus? status,
    List<RingDeviceEntity>? devices,
    List<RingEventEntity>? recentEvents,
    String? selectedDeviceId,
    String? liveInspectionText,
    bool clearInspectionText = false,
    bool? isTwoWayAudioActive,
    String? activeAudioDeviceId,
    bool clearAudioDevice = false,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return PerimeterState(
      status: status ?? this.status,
      devices: devices ?? this.devices,
      recentEvents: recentEvents ?? this.recentEvents,
      selectedDeviceId: selectedDeviceId ?? this.selectedDeviceId,
      liveInspectionText: clearInspectionText
          ? null
          : (liveInspectionText ?? this.liveInspectionText),
      isTwoWayAudioActive: isTwoWayAudioActive ?? this.isTwoWayAudioActive,
      activeAudioDeviceId: clearAudioDevice
          ? null
          : (activeAudioDeviceId ?? this.activeAudioDeviceId),
      errorMessage:
          clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        devices,
        recentEvents,
        selectedDeviceId,
        liveInspectionText,
        isTwoWayAudioActive,
        activeAudioDeviceId,
        errorMessage,
      ];
}