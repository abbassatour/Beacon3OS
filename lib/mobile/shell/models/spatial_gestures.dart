// lib/mobile/shell/models/spatial_gestures.dart

/// الكتالوج المركزي الموحد لإيماءات النظام (Spatial Interaction Tokens)
enum SpatialGesture {
  // 🏢 1. مصعد الطوابق (Z-Axis Elevator)
  ascendToSettings(
    symbol: '👐',
    shortLabel: 'Spread 2 Fingers',
    visualHint: '👐 Spread 2 fingers to enter Floor 1 (Settings)',
    spokenPrompt:
        'Elevator activated. Spreading two fingers apart ascends to the Settings floor.',
    onboardingStepLabel: 'Spread 2 fingers 👐 to dive into Settings Floor',
  ),
  descendToGround(
    symbol: '🤏',
    shortLabel: 'Pinch 2 Fingers',
    visualHint: '🤏 Pinch 2 fingers or tap HUD to return to Cockpit',
    spokenPrompt:
        'Pinching two fingers together descends back to your Cockpit.',
    onboardingStepLabel: 'Pinch together 🤏 to return to Ground Floor',
  ),

  // 🧭 2. إيماءات الملاحة الفضائية بين الغرف (Two-Finger Compass Pan)
  swipeToFocus(
    symbol: '⬆️',
    shortLabel: '2-Finger Swipe North',
    visualHint: 'Swipe UP with 2 fingers ⬆️ to visit Focus & Alarms',
    spokenPrompt:
        'Swipe up with two fingers to open your Focus timer and scheduled alarms.',
    onboardingStepLabel: 'Swipe UP with 2 fingers ⬆️ to visit Focus & Alarms',
  ),
  swipeToComms(
    symbol: '⬇️',
    shortLabel: '2-Finger Swipe South',
    visualHint: 'Swipe DOWN with 2 fingers ⬇️ to visit Communications',
    spokenPrompt:
        'Swipe down with two fingers to open Communications and Emergency radar.',
    onboardingStepLabel: 'Swipe DOWN with 2 fingers ⬇️ to visit Communications',
  ),
  swipeToAgenda(
    symbol: '⬅️',
    shortLabel: '2-Finger Swipe West',
    visualHint: 'Swipe LEFT with 2 fingers ⬅️ to visit Agenda',
    spokenPrompt:
        'Swipe left with two fingers to open your Agenda, tasks, and notes.',
    onboardingStepLabel: 'Swipe LEFT with 2 fingers ⬅️ to visit Agenda',
  ),
  swipeToVision(
    symbol: '➡️',
    shortLabel: '2-Finger Swipe East',
    visualHint: 'Swipe RIGHT with 2 fingers ➡️ to visit AI Vision',
    spokenPrompt:
        'Swipe right with two fingers to open the AI Vision camera studio.',
    onboardingStepLabel: 'Swipe RIGHT with 2 fingers ➡️ to visit AI Vision',
  ),

  // 🚨 3. إيماءات الطوارئ والتفاعل الصامت
  tripleTapSos(
    symbol: '🚨',
    shortLabel: 'Triple Tap (1 Finger)',
    visualHint: 'Tap 3 times anywhere for Emergency SOS',
    spokenPrompt:
        'Triple tapping rapidly anywhere on screen broadcasts your emergency radar and GPS.',
    onboardingStepLabel: 'Triple tap rapidly for Emergency SOS',
  ),
  twoFingerTapContext(
    symbol: '✌️',
    shortLabel: '2-Finger Double Tap',
    visualHint: 'Double-tap with 2 fingers to hear location',
    spokenPrompt:
        'Double tap anywhere with two fingers to announce your current room location.',
    onboardingStepLabel: 'Double tap with 2 fingers to hear location',
  ),

  // 🎙️ 4. التفاعل الصوتي الحسي (Tactile Voice Summoning)
  holdToSpeak(
    symbol: '🎙️',
    shortLabel: 'Hold to Speak (1 Finger)',
    visualHint: 'Press & hold anywhere to talk with Beacon AI',
    spokenPrompt:
        'Press and hold anywhere on the screen with one finger to talk, then release when finished.',
    onboardingStepLabel: 'Hold anywhere on screen to speak with Beacon AI',
  ),
  cornerSwipeAssistant(
    symbol: '📐',
    shortLabel: 'Corner Swipe',
    visualHint:
        'Swipe diagonally inward from bottom corners to summon Beacon AI',
    spokenPrompt:
        'Swipe diagonally inward from either bottom corner of your device to speak with your assistant.',
    onboardingStepLabel: 'Swipe from bottom corner for Voice Assistant',
  );

  const SpatialGesture({
    required this.symbol,
    required this.shortLabel,
    required this.visualHint,
    required this.spokenPrompt,
    required this.onboardingStepLabel,
  });

  final String symbol;
  final String shortLabel;
  final String visualHint;
  final String spokenPrompt;
  final String onboardingStepLabel;
}