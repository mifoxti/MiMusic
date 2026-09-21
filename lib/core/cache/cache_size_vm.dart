import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';

/// Суммарный размер временных и системных каталогов кэша приложения.
Future<int> getAppCacheSizeBytes() async {
  if (kIsWeb) return 0;
  var total = 0;
  for (final dir in await _cacheDirectories()) {
    total += await _directorySize(dir);
  }
  return total;
}

/// Удаляет содержимое temp и application cache (не сами корневые папки).
Future<void> clearAppCache() async {
  if (kIsWeb) return;
  for (final dir in await _cacheDirectories()) {
    try {
      await _clearChildren(dir);
    } catch (_) {}
  }
}

Future<List<Directory>> _cacheDirectories() async {
  final directories = <String, Directory>{};
  for (final resolve in [getTemporaryDirectory, getApplicationCacheDirectory]) {
    try {
      final dir = await resolve();
      final path = await dir.resolveSymbolicLinks();
      directories[Platform.isWindows ? path.toLowerCase() : path] = Directory(
        path,
      );
    } catch (_) {}
  }
  // Nested cache roots must also be counted only once.
  return directories.entries
      .where(
        (entry) => !directories.keys.any(
          (other) =>
              other != entry.key &&
              entry.key.startsWith(
                other.endsWith(Platform.pathSeparator)
                    ? other
                    : '$other${Platform.pathSeparator}',
              ),
        ),
      )
      .map((entry) => entry.value)
      .toList();
}

Future<int> _directorySize(Directory dir) async {
  var total = 0;
  try {
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          total += await entity.length();
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
