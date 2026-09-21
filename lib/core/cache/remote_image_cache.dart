import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../network/api_config.dart';
import '../network/authenticated_dio.dart';
import '../profile/me_profile_avatar_disk.dart';

/// Дисковый кэш HTTP-обложек и аватаров (каталог cache приложения).
class RemoteImageCache {
  RemoteImageCache._();

  static final RemoteImageCache instance = RemoteImageCache._();

  Directory? _dir;
  final Map<String, Future<File?>> _inFlight = {};
  int _temporaryFileId = 0;

  Future<Directory> _cacheDir() async {
    if (kIsWeb) {
      throw UnsupportedError('RemoteImageCache is not supported on web');
    }
    final existing = _dir;
    if (existing != null) return existing;
    final base = await getApplicationCacheDirectory();
    final dir = Directory('${base.path}/mimusic_images');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _dir = dir;
    return dir;
  }

  /// Ключ на диске: для аватаров без query (`?cb=`), чтобы кэш переживал ревизии UI.
  String _diskCacheKey(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    final path = uri.path;
    if (path.endsWith('/me/avatar') ||
        RegExp(r'/users/\d+/avatar$').hasMatch(path)) {
      return uri.replace(query: null, fragment: null).toString();
    }
    return url;
  }

  String _fileNameForUrl(String url) {
    final digest = sha256.convert(utf8.encode(_diskCacheKey(url)));
    return digest.toString();
  }

  bool _isMeAvatarUrl(String url) {
    final uri = Uri.tryParse(url);
    return uri != null && uri.path.endsWith('/me/avatar');
  }

  /// Только аватары требуют Bearer. [GET /tracks/{id}/cover] — публичный.
  bool requiresAuth(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !_isApiOrigin(uri)) return false;
    return uri.path.endsWith('/me/avatar') ||
        RegExp(r'/users/\d+/avatar$').hasMatch(uri.path);
  }

  bool _isApiOrigin(Uri uri) {
    final base = Uri.parse(ApiConfig.baseUrl);
    return uri.scheme == base.scheme &&
        uri.host == base.host &&
        uri.port == base.port;
  }

  /// Возвращает файл из кэша или скачивает в кэш. При ошибке сети — старый файл, если есть.
  Future<File?> fileForUrl(
    String url, {
    bool? requireAuth,
    bool forceRefresh = false,
  }) async {
    if (kIsWeb || url.isEmpty) return null;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return null;
    }
    final auth =
        (requireAuth ?? requiresAuth(url)) && _isApiOrigin(Uri.parse(url));
    final key = '$auth:$url';
    final existing = _inFlight[key];
    if (existing != null) return existing;
    final future = _loadFile(url, auth: auth, forceRefresh: forceRefresh);
    _inFlight[key] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(key);
    }
  }

  Future<File?> _loadFile(
    String url, {
    required bool auth,
    required bool forceRefresh,
  }) async {
    final dir = await _cacheDir();
    final file = File('${dir.path}/${_fileNameForUrl(url)}');
    if (!forceRefresh && await file.exists()) {
      final len = await file.length();
      if (len > 0) return file;
    }

    File? temporary;
    Dio? dio;
    try {
      dio = auth
          ? await createAuthenticatedDio()
          : Dio(
              BaseOptions(
                baseUrl: ApiConfig.baseUrl.replaceAll(RegExp(r'/+$'), ''),
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 45),
              ),
            );
      final res = await dio.get<List<int>>(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          validateStatus: (s) => s != null && s >= 200 && s < 300,
        ),
      );
      final data = res.data;
      if (data == null || data.isEmpty) {
        return await file.exists() ? file : null;
      }
      temporary = File('${file.path}.${_temporaryFileId++}.tmp');
      await temporary.writeAsBytes(data, flush: true);
      await temporary.rename(file.path);
      if (_isMeAvatarUrl(url)) {
        await MeProfileAvatarDisk.saveFrom(file);
      }
      return file;
    } catch (_) {
      if (await file.exists() && await file.length() > 0) {
        return file;
      }
      return null;
    } finally {
      dio?.close();
      if (temporary != null && await temporary.exists()) {
        try {
          await temporary.delete();
        } catch (_) {}
      }
    }
  }

  Future<void> evictUrl(String url) async {
    if (kIsWeb || url.isEmpty) return;
    final dir = await _cacheDir();
    final file = File('${dir.path}/${_fileNameForUrl(url)}');
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (_) {}
    }
    if (_isMeAvatarUrl(url)) {
      await MeProfileAvatarDisk.clear();
    }
  }
}
