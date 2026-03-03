import 'package:just_audio/just_audio.dart';

/// На web воспроизведение с файлового пути не поддерживается.
AudioSource createAudioSource(String path) {
  if (!path.startsWith('assets/')) {
    throw UnsupportedError('Воспроизведение из файла недоступно на этой платформе');
  }
  return AudioSource.asset(path);
}
