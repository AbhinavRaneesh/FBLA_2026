import 'package:flutter_tts/flutter_tts.dart';

/// Speaks text aloud for accessibility (read-aloud mode).
class TextToSpeechService {
  TextToSpeechService._();

  static final FlutterTts _tts = FlutterTts();
  static bool _ready = false;

  static Future<void> ensureReady() async {
    if (_ready) return;
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
    _ready = true;
  }

  static Future<void> speak(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    await ensureReady();
    await _tts.stop();
    await _tts.speak(trimmed);
  }

  static Future<void> stop() => _tts.stop();
}
