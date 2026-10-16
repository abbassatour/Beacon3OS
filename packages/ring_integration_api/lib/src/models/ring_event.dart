import 'package:equatable/equatable.dart';

enum RingEventType {
  ding,       // رنين جرس الباب
  motion,     // رصد حركة محيطية
  offline,    // انقطاع الاتصال
}

enum RingScenarioPreset {
  courierDelivery,   // مندوب توصيل يحمل طرداً أمام الباب
  nightProwler,      // حركة غريبة ليلاً في الحديقة الخلفية
  babyCrying,        // حركة/استيقاظ في سرير الأطفال بالحضانة
  carArriving,       // سيارة تدخل الممر في المرآب
  friendlyNeighbor,  // جار يقف عند الباب ويلوح بيده
}

class RingEvent extends Equatable {
  const RingEvent({
    required this.id,
    required this.deviceId,
    required this.deviceLabel,
    required this.type,
    required this.timestamp,
    required this.snapshotBase64,
    this.scenarioPreset,
    this.aiSceneDescription,
    this.isProcessed = false,
  });

  final String id;
  final String deviceId;
  final String deviceLabel;
  final RingEventType type;
  final DateTime timestamp;
  final String snapshotBase64;
  final RingScenarioPreset? scenarioPreset;
  final String? aiSceneDescription;
  final bool isProcessed;

  RingEvent copyWith({
    String? id,
    String? deviceId,
    String? deviceLabel,
    RingEventType? type,
    DateTime? timestamp,
    String? snapshotBase64,
    RingScenarioPreset? scenarioPreset,
    String? aiSceneDescription,
    bool? isProcessed,
  }) {
    return RingEvent(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      deviceLabel: deviceLabel ?? this.deviceLabel,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      snapshotBase64: snapshotBase64 ?? this.snapshotBase64,
      scenarioPreset: scenarioPreset ?? this.scenarioPreset,
      aiSceneDescription: aiSceneDescription ?? this.aiSceneDescription,
      isProcessed: isProcessed ?? this.isProcessed,
    );
  }

  @override
  List<Object?> get props => [
        id,
        deviceId,
        deviceLabel,
        type,
        timestamp,
        snapshotBase64,
        scenarioPreset,
        aiSceneDescription,
        isProcessed,
      ];
}