// lib/core/audio/sound_cue.dart

/// كتالوج أصوات النظام ونغمات الملاحة الفضائية الموحد (Sound Design Tokens)
enum SoundCue {
  // --- إيماءات الملاحة الفضائية الديناميكية (Dynamic Spatial Pan) ---
  navMove('audio/nav_move.mp3', volume: 0.35, allowFloorPitchShift: true),
  navReturn('audio/nav_return.mp3', volume: 0.30, allowFloorPitchShift: true),

  // نغمات ثابتة إضافية (للتوافق المعماري القديم)
  navNorth('audio/nav_move.mp3', volume: 0.35, allowFloorPitchShift: true),
  navSouth('audio/nav_move.mp3', volume: 0.35, allowFloorPitchShift: true),
  navEast('audio/nav_move.mp3', volume: 0.35, allowFloorPitchShift: true),
  navWest('audio/nav_move.mp3', volume: 0.35, allowFloorPitchShift: true),
  navCenter('audio/nav_return.mp3', volume: 0.30, allowFloorPitchShift: true),

  // --- المصعد الرأسي بين الطوابق (Vertical Z-Axis) ---
  elevatorUp('audio/elevator_up.mp3', volume: 0.38),
  elevatorDown('audio/elevator_down.mp3', volume: 0.35),
  elevatorLoop('audio/elevator_up.mp3', volume: 0.28, isLooping: true),

  // --- الرادار الصوتي المستمر والمؤثرات المكانية (Continuous Spatial Sonification) ---
  /// خامة صوتية دورية للرادار تعزف بنعومة أثناء استمرار لمس وسحب الإصبع
  radarDrone('audio/nav_move.mp3', volume: 0.22, isLooping: true),

  /// نغمة الجاذبية المطمئنة لمركز قمرة القيادة (0, 0)
  coreChime('audio/wake.mp3', volume: 0.28),

  /// صوت الصدمة الجدارية الناعمة عند الارتطام بحدود الغرف أو الطوابق
  boundaryThud('audio/error.mp3', volume: 0.35),

  // --- الواجهة الصفرية وحالات الاستماع (Zero-UI Cues) ---
  wake('audio/wake.mp3', volume: 0.6),
  processing('audio/processing.mp3', volume: 0.5),
  success('audio/success.mp3', volume: 0.7),
  error('audio/error.mp3', volume: 0.8),
  sosAlarm('audio/sos.mp3', volume: 1.0, isLooping: true);

  const SoundCue(
    this.path, {
    this.volume = 1.0,
    this.allowFloorPitchShift = false,
    this.isLooping = false,
  });

  final String path;
  final double volume;
  final bool allowFloorPitchShift;
  final bool isLooping;
}