// packages/voice_ai_api/lib/src/tts_engine.dart
import 'dart:developer';
import 'dart:io';
import 'package:flutter_tts/flutter_tts.dart';

class TtsEngine {
  final FlutterTts _flutterTts = FlutterTts();
  double _currentRate = 0.5;

  double get currentRate => _currentRate;
  bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  Future<void> initialize() async {
    if (!_isMobile) {
      log('TtsEngine: Desktop environment detected. Bypassing mobile flutter_tts engine.');
      return;
    }

    try {
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(_currentRate);
      await _flutterTts.setPitch(1.0);
      await _flutterTts.awaitSpeakCompletion(true);
    } catch (e) {
      log('TtsEngine: Init error: $e');
    }
  }

  /// ⚡️ ضبط سرعة النطق
  Future<void> setSpeechRate(double rate) async {
    _currentRate = rate.clamp(0.2, 1.0);
    if (!_isMobile) return;
    try {
      await _flutterTts.setSpeechRate(_currentRate);
    } catch (_) {}
  }

  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    if (!_isMobile) {
      log('TtsEngine (Desktop Voice): "$text"');
      return;
    }

    try {
      await stop();
      final cleanText = _sanitizeForSpeech(text);
      await _flutterTts.speak(cleanText);
    } catch (e) {
      log('TtsEngine: Speak error: $e');
    }
  }

  Future<void> stop() async {
    if (!_isMobile) return;
    try {
      await _flutterTts.stop();
    } catch (_) {}
  }

  String _sanitizeForSpeech(String raw) {
    return raw
        .replaceAll(RegExp(r'\*\*|\*|__|_|`|#+'), '')
        .replaceAll(RegExp(r'https?:\/\/\S+'), 'link')
        .trim();
  }
}