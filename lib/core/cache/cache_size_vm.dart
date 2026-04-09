import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';

/// Суммарный размер временных и системных каталогов кэша приложения.
Future<int> getAppCacheSizeBytes() async {
  if (kIsWeb) return 0;
  var total = 0;
  try {
    final temp = await getTemporaryDirectory();
    total += _directorySizeSync(Directory(temp.path));
    try {
      final cache = await getApplicationCacheDirectory();
      total += _directorySizeSync(Directory(cache.path));
    } catch (_) {}
  } catch (_) {}
  return total;
}

/// Удаляет содержимое temp и application cache (не сами корневые папки).
Future<void> clearAppCache() async {
  if (kIsWeb) return;
  try {
    await _clearChildren(await getTemporaryDirectory());
    try {
      final cache = await getApplicationCacheDirectory();
      await _clearChildren(Directory(cache.path));
    } catch (_) {}
  } catch (_) {}
}

int _directorySizeSync(Directory dir) {
  if (!dir.existsSync()) return 0;
  var total = 0;
  try {
    for (final entity in dir.listSync(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          total += entity.lengthSync();
        } catch (_) {}
      }
    }
  } catch (_) {}
  return total;
}

Future<void> _clearChildren(Directory dir) async {
  if (!await dir.exists()) return;
  final list = await dir.list(followLinks: false).toList();
  for (final entity in list) {
    try {
      if (entity is File) {
        await entity.delete();
      } else if (entity is Directory) {
        await entity.delete(recursive: true);
      }
    } catch (_) {}
  }
}
