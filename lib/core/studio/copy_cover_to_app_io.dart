import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Копирует выбранное изображение в папку приложения и возвращает путь к копии.
Future<String?> copyPickedCoverToApp(String sourcePath, String id) async {
  try {
    final source = File(sourcePath);
    if (!await source.exists()) return null;
    final ext = sourcePath.contains('.') ? '.${sourcePath.split('.').last}' : '.jpg';
    final dir = await getApplicationDocumentsDirectory();
    final coverDir = Directory('${dir.path}/mimusic_covers');
    await coverDir.create(recursive: true);
    final dest = File('${coverDir.path}/$id$ext');
    await source.copy(dest.path);
    return dest.path;
  } catch (_) {
    return null;
  }
}
