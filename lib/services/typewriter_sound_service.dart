import 'dart:math';

import 'package:audioplayers/audioplayers.dart';

/// Short mechanical clicks for the cybersecurity typewriter intro.
class TypewriterSoundService {
  TypewriterSoundService._();
  static final TypewriterSoundService instance = TypewriterSoundService._();

  final AudioPlayer _player = AudioPlayer();
  final _random = Random();
  bool _ready = false;

  Future<void> ensureReady() async {
    if (_ready) return;
    await _player.setReleaseMode(ReleaseMode.stop);
    _ready = true;
  }

  Future<void> playClick() async {
    try {
      await ensureReady();
      final asset = _random.nextBool()
          ? 'sounds/typewriter_click.wav'
          : 'sounds/typewriter_click_alt.wav';
      await _player.play(AssetSource(asset));
    } catch (_) {
      // Lesson should still work if audio fails (web/desktop without asset).
    }
  }

  Future<void> dispose() async {
    await _player.dispose();
    _ready = false;
  }
}
