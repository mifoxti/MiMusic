import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Стабильный файл аватара текущего пользователя (не зависит от `?cb=` в URL).
abstract final class MeProfileAvatarDisk {
  static const String _fileName = 'me_profile_avatar.img';

  static Future<File?> cachedFile() async {
    if (kIsWeb) return null;
    final f = await _targetFile();
    if (await f.exists() && await f.length() > 0) return f;
    return null;
  }

  static Future<void> saveFrom(File source) async {
    if (kIsWeb) return;
    if (!await source.exists()) return;
    final len = await source.length();
    if (len <= 0) return;
    final target = await _targetFile();
    await source.copy(target.path);
  }

  static Future<void> clear() async {
    if (kIsWeb) return;
    final f = await _targetFile();
    if (await f.exists()) {
      try {
        await f.delete();
      } catch (_) {}
    }
  }

  static Future<File> _targetFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }
}
