import 'package:flutter/foundation.dart'
    show debugPrint, defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/services.dart';

/// Повторно включает like/dislike в MPRemoteCommandCenter после setState audio_service.
abstract final class MiMusicIosRemoteCommands {
  static const _channel = MethodChannel('mimusic/remote_commands');

  static Future<void> refreshIfNeeded() async {
    if (kIsWeb) return;
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        break;
      default:
        return;
    }
    try {
      await _channel.invokeMethod<void>('refresh');
    } catch (e, st) {
      debugPrint('MiMusicIosRemoteCommands.refresh failed: $e\n$st');
    }
  }
}
