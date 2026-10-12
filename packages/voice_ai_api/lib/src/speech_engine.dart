// packages/voice_ai_api/lib/src/speech_engine.dart
import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:speech_to_text/speech_to_text.dart';

/// حدث استلام الكلمات المنطوقة من الميكروفون
class VoiceRecognitionEvent {
  const VoiceRecognitionEvent({
    required this.text,
    required this.isFinal,
  });

  /// النص المنطوق حتى اللحظة
  final String text;

  /// هل انتهت الجملة تماماً واعتمدها المحرك
  final bool isFinal;

  @override
  String toString() => 'VoiceRecognitionEvent(text: "$text", isFinal: $isFinal)';
}

/// محرك التعرف على الصوت الحي مع تدفقات لحظية (Reactive Speech-to-Text Engine)
class SpeechEngine {
  SpeechEngine({SpeechToText? speechToText})
      : _speechToText = speechToText ?? SpeechToText();

  final SpeechToText _speechToText;
  bool _isInitialized = false;

  bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  // --- Broadcast StreamControllers للبث الحي لعدة مستمعين في وقت واحد ---
  final _textController = StreamController<String>.broadcast();
  final _soundLevelController = StreamController<double>.broadcast();
  final _isListeningController = StreamController<bool>.broadcast();
  final _recognitionController =
      StreamController<VoiceRecognitionEvent>.broadcast();

  /// تدفق الكلمات المنطوقة لحظة بلحظة
  Stream<String> get textStream => _textController.stream;

  /// تدفق قياس شدة الصوت اللحظية (Decibels Level)
  Stream<double> get soundLevelStream => _soundLevelController.stream;

  /// تدفق حالة الميكروفون الحية (نشط / خامل)
  Stream<bool> get isListeningStream => _isListeningController.stream;

  /// تدفق أحداث التعرف الكاملة مع وسم اعتماد الجملة النهائية
  Stream<VoiceRecognitionEvent> get recognitionStream =>
      _recognitionController.stream;

  bool get isListening => _isMobile && _speechToText.isListening;
  bool get isInitialized => _isInitialized;

  /// تهيئة المحرك وربط مستمعي الحالة والأخطاء (محصن ضد انهيار سطح المكتب)
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    // 🛡️ حماية سطح المكتب: مكتبة speech_to_text لا تدعم ويندوز
    if (!_isMobile) {
      log('SpeechEngine: Desktop environment detected. Operating in passive mode.');
      _isInitialized = false;
      return false;
    }

    try {
      _isInitialized = await _speechToText.initialize(
        onError: (error) {
          log('SpeechEngine: Error occurred: ${error.errorMsg}');
          _isListeningController.add(false);
        },
        onStatus: (status) {
          log('SpeechEngine: Status changed -> $status');
          final isCurrentlyListening = status == 'listening';
          _isListeningController.add(isCurrentlyListening);
        },
        debugLogging: false,
      );
      return _isInitialized;
    } catch (e, st) {
      log('SpeechEngine: Init exception: $e', stackTrace: st);
      _isInitialized = false;
      return false;
    }
  }

  /// بدء الاستماع الحي مع ضخ النتائج عبر الـ Streams فوراً
  Future<void> startListening({
    Function(String text, bool isFinal)? onResult,
    Function(double level)? onSoundLevel,
    Duration pauseFor = const Duration(seconds: 3),
    Duration listenFor = const Duration(seconds: 30),
  }) async {
    if (!_isMobile) {
      log('SpeechEngine: startListening is bypassed on Desktop.');
      return;
    }

    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        log('SpeechEngine: Unable to start listening, initialization failed.');
        return;
      }
    }

    if (_speechToText.isListening) {
      await stopListening();
    }

    _isListeningController.add(true);

    try {
      await _speechToText.listen(
        onResult: (result) {
          final words = result.recognizedWords;
          final isFinal = result.finalResult;

          _textController.add(words);
          _recognitionController.add(
            VoiceRecognitionEvent(text: words, isFinal: isFinal),
          );

          onResult?.call(words, isFinal);
        },
        onSoundLevelChange: (level) {
          _soundLevelController.add(level);
          onSoundLevel?.call(level);
        },
        listenMode: ListenMode.dictation,
        cancelOnError: false,
        partialResults: true,
        pauseFor: pauseFor,
        listenFor: listenFor,
      );
    } catch (e) {
      log('SpeechEngine: Error during listen: $e');
      _isListeningController.add(false);
    }
  }

  /// إيقاف الاستماع مع إرجاع النص النهائي المنطوق
  Future<String> stopListening() async {
    if (!_isMobile) return '';

    if (_speechToText.isListening) {
      await _speechToText.stop();
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    _isListeningController.add(false);
    return _speechToText.lastRecognizedWords;
  }

  /// إلغاء جلسة الاستماع وتجاهل النتائج فوراً
  Future<void> cancelListening() async {
    if (!_isMobile) return;

    if (_speechToText.isListening) {
      await _speechToText.cancel();
    }
    _isListeningController.add(false);
  }

  /// تحرير الموارد وإغلاق التدفقات بأمان لمنع أي تسريب ذاكرة
  Future<void> dispose() async {
    await stopListening();
    await _textController.close();
    await _soundLevelController.close();
    await _isListeningController.close();
    await _recognitionController.close();
  }
}