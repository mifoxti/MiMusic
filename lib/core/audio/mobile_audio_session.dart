import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';

/// Категория воспроизведения для lock screen / Control Center / Bluetooth (iOS и Android).
Future<void> configureMobilePlaybackAudioSession() async {
  if (kIsWeb) return;
  try {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    await session.setActive(true);
  } catch (e, st) {
    debugPrint('AudioSession configure failed: $e\n$st');
  }
}
