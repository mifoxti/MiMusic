import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Копирует выбранный аудиофайл в папку приложения и возвращает путь к копии.
Future<String?> copyPickedAudioToApp(String sourcePath, String trackId) async {
  try {
    final source = File(sourcePath);
    if (!await source.exists()) return null;
    final ext = sourcePath.contains('.') ? '.${sourcePath.split('.').last}' : '.mp3';
    final dir = await getApplicationDocumentsDirectory();
    final trackDir = Directory('${dir.path}/mimusic_tracks');
    await trackDir.create(recursive: true);
    final dest = File('${trackDir.path}/$trackId$ext');
    await source.copy(dest.path);
    return dest.path;
  } catch (_) {
    return null;
  }
}
