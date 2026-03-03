import 'package:just_audio/just_audio.dart';

bool _isFilePath(String path) {
  if (path.startsWith('assets/')) return false;
  if (path.startsWith('/')) return true;
  if (path.length >= 2 && path[1] == ':') return true;
  return false;
}

AudioSource createAudioSource(String path) {
  if (_isFilePath(path)) {
    return AudioSource.file(path);
  }
  return AudioSource.asset(path);
}
