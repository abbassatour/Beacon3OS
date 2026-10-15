// packages/launcher_repository/lib/src/domains/assistant_repository.dart
import 'package:voice_ai_api/voice_ai_api.dart';

export 'package:voice_ai_api/voice_ai_api.dart' show VoiceRecognitionEvent;

/// العقد النطاقي المخصص لإدارة المساعد الصوتي، الاستماع المباشر، والـ LLM
abstract class AssistantRepository {
  Future<void> initializeEngines();
  Future<void> setSpeechRate(double rate);

  // --- التدفقات التفاعلية المباشرة (Reactive Streams) ---
  Stream<String> get textStream;
  Stream<double> get soundLevelStream;
  Stream<bool> get isListeningStream;
  Stream<VoiceRecognitionEvent> get recognitionStream;
  bool get isListening;

  // --- التحكم بجلسات الميكروفون ---
  Future<void> startListening({
    Function(String text, bool isFinal)? onResult,
    Function(double level)? onSoundLevel,
  });
  Future<String> stopListening();
  Future<void> cancelListening();

  // --- محرك النطق والتحليل ---
  Future<void> speak(String text);
  Future<void> stopSpeaking();
  Future<String> analyzeVisionFrame({
    required String base64Image,
    required String prompt,
  });
  Future<Map<String, dynamic>> processLlmCommand({
    required String userCommand,
    String? base64Image,
    Map<String, dynamic>? systemContext,
    String? availableIntentsPrompt,
  });
}

class AssistantRepositoryImpl implements AssistantRepository {
  AssistantRepositoryImpl({
    SpeechEngine? speechEngine,
    TtsEngine? ttsEngine,
    LlmAgent? llmAgent,
  })  : _speech = speechEngine ?? SpeechEngine(),
        _tts = ttsEngine ?? TtsEngine(),
        _llm = llmAgent ?? LlmAgent(openRouterApiKey: '');

  final SpeechEngine _speech;
  final TtsEngine _tts;
  final LlmAgent _llm;

  @override
  Future<void> initializeEngines() async {
    await _speech.initialize();
    await _tts.initialize();
  }

  @override
  Future<void> setSpeechRate(double rate) async {
    await _tts.setSpeechRate(rate);
  }

  // --- ربط التدفقات مباشرة مع محرك الصوت الحي ---
  @override
  Stream<String> get textStream => _speech.textStream;

  @override
  Stream<double> get soundLevelStream => _speech.soundLevelStream;

  @override
  Stream<bool> get isListeningStream => _speech.isListeningStream;

  @override
  Stream<VoiceRecognitionEvent> get recognitionStream =>
      _speech.recognitionStream;

  @override
  bool get isListening => _speech.isListening;

  @override
  Future<void> startListening({
    Function(String text, bool isFinal)? onResult,
    Function(double level)? onSoundLevel,
  }) async {
    // 🛡️ إيقاف النطق فوراً قبل فتح الميكروفون لمنع ارتداد صوت السماعة
    await _tts.stop();
    await _speech.startListening(
      onResult: onResult,
      onSoundLevel: onSoundLevel,
    );
  }

  @override
  Future<String> stopListening() => _speech.stopListening();

  @override
  Future<void> cancelListening() => _speech.cancelListening();

  @override
  Future<void> speak(String text) => _tts.speak(text);

  @override
  Future<void> stopSpeaking() => _tts.stop();

  @override
  Future<String> analyzeVisionFrame({
    required String base64Image,
    required String prompt,
  }) async {
    final result = await _llm.processCommand(
      userCommand: prompt,
      base64Image: base64Image,
    );
    return result['spoken_response'] as String? ??
        'Could not inspect the scene.';
  }

  @override
  Future<Map<String, dynamic>> processLlmCommand({
    required String userCommand,
    String? base64Image,
    Map<String, dynamic>? systemContext,
    String? availableIntentsPrompt,
  }) {
    return _llm.processCommand(
      userCommand: userCommand,
      base64Image: base64Image,
      systemContext: systemContext,
      availableIntentsPrompt: availableIntentsPrompt,
    );
  }
}