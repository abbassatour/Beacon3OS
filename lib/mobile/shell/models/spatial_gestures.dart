// lib/spatial_shell/models/spatial_gestures.dart

/// الكتالوج المركزي الموحد لإيماءات النظام (Spatial Interaction Tokens)
enum SpatialGesture {
  // 🏢 1. مصعد الطوابق (Z-Axis Elevator)
  ascendToSettings(
    symbol: '👐',
    shortLabel: 'Spread apart',
    visualHint: '👐 Spread 2 fingers to enter Floor 1 (Settings)',
    spokenPrompt:
        'Elevator activated. Spreading two fingers apart ascends to the Settings floor.',
    onboardingStepLabel: 'Spread 2 fingers 👐 to dive into Settings Floor',
  ),
  descendToGround(
    symbol: '🤏',
    shortLabel: 'Pinch together',
    visualHint: '🤏 Pinch 2 fingers or tap HUD to return to Cockpit',
    spokenPrompt:
        'Pinching two fingers together descends back to your Cockpit.',
    onboardingStepLabel: 'Pinch together 🤏 to return to Ground Floor',
  ),

  // 🧭 2. إيماءات الملاحة الفضائية (Compass Pan)
  swipeToFocus(
    symbol: '⬆️',
    shortLabel: 'Swipe North',
    visualHint: 'Swipe UP ⬆️ to visit Focus & Alarms',
    spokenPrompt:
        'Swipe up to open your Focus timer and scheduled alarms.',
    onboardingStepLabel: 'Swipe UP ⬆️ to visit Focus & Alarms',
  ),
  swipeToComms(
    symbol: '⬇️',
    shortLabel: 'Swipe South',
    visualHint: 'Swipe DOWN ⬇️ to visit Communications',
    spokenPrompt:
        'Swipe down to open Communications and Emergency radar.',
    onboardingStepLabel: 'Swipe DOWN ⬇️ to visit Communications',
  ),
  swipeToAgenda(
    symbol: '⬅️',
    shortLabel: 'Swipe West',
    visualHint: 'Swipe LEFT ⬅️ to visit Agenda',
    spokenPrompt:
        'Swipe left to open your Agenda, tasks, and notes.',
    onboardingStepLabel: 'Swipe LEFT ⬅️ to visit Agenda',
  ),
  swipeToVision(
    symbol: '➡️',
    shortLabel: 'Swipe East',
    visualHint: 'Swipe RIGHT ➡️ to visit AI Vision',
    spokenPrompt:
        'Swipe right to open the AI Vision camera studio.',
    onboardingStepLabel: 'Swipe RIGHT ➡️ to visit AI Vision',
  ),

  // 🚨 3. إيماءات الطوارئ والتفاعل الصامت
  tripleTapSos(
    symbol: '🚨',
    shortLabel: 'Triple Tap',
    visualHint: 'Tap 3 times anywhere for Emergency SOS',
    spokenPrompt:
        'Triple tapping rapidly anywhere on screen broadcasts your emergency radar and GPS.',
    onboardingStepLabel: 'Triple tap rapidly for Emergency SOS',
  ),
  twoFingerTapContext(
    symbol: '✌️',
    shortLabel: '2-Finger Tap',
    visualHint: 'Double-tap with 2 fingers to hear location',
    spokenPrompt:
        'Double tap anywhere with two fingers to announce your current room location.',
    onboardingStepLabel: 'Double tap with 2 fingers to hear location',
  ),

  // 🎙️ 4. التفاعل الصوتي الحسي (Tactile Voice Summoning)
  holdToSpeak(
    symbol: '🎙️',
    shortLabel: 'Hold to Speak',
    visualHint: 'Press & hold anywhere to talk with Beacon AI',
    spokenPrompt:
        'Press and hold anywhere on the screen to talk, then release when finished.',
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