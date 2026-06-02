import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_update_api.dart';
import 'app_update_installer.dart';

/// Проверка, загрузка и установка OTA-обновлений (Android).
class AppUpdateService {
  AppUpdateService._();

  static final AppUpdateService instance = AppUpdateService._();

  static const _prefsLastAutoCheckMs = 'app_update_last_auto_check_ms';
  static const _autoCheckInterval = Duration(hours: 12);

  final AppUpdateApi _api = AppUpdateApi();
  final ValueNotifier<double?> downloadProgress = ValueNotifier(null);

  AppUpdateCheckResult? _cachedResult;
  AppUpdateCheckResult? get lastCheck => _cachedResult;

  bool get isAndroid => !kIsWeb && Platform.isAndroid;

  Future<AppUpdateCheckResult?> checkForUpdate({bool force = false}) async {
    if (!isAndroid) return null;
    final ver = await AppUpdateApi.currentAppVersion();
    try {
      final result = await _api.checkAndroidUpdate(
        versionCode: ver.code,
        versionName: ver.name,
      );
      _cachedResult = result;
      return result;
    } catch (_) {
      return null;
    }
  }

  /// Автопроверка: не чаще [_autoCheckInterval] ходим в API, если уже есть
  /// закэшированное обновление — можно вернуть сразу. Раньше при «нет обновления»
  /// кэш блокировал повторный запрос 12 ч (настройки при этом проверяли заново).
  Future<AppUpdateCheckResult?> checkIfStale({bool force = false}) async {
    if (!isAndroid) return null;
    if (!force) {
      final prefs = await SharedPreferences.getInstance();
      final lastMs = prefs.getInt(_prefsLastAutoCheckMs) ?? 0;
      final last = DateTime.fromMillisecondsSinceEpoch(lastMs);
      final withinInterval =
          DateTime.now().difference(last) < _autoCheckInterval;
      if (withinInterval && _cachedResult?.updateAvailable == true) {
        return _cachedResult;
      }
    }
    final result = await checkForUpdate(force: force);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _prefsLastAutoCheckMs,
      DateTime.now().millisecondsSinceEpoch,
    );
    if (result != null && result.updateAvailable) return result;
    return null;
  }

  Future<String> downloadApk(
    AppUpdateCheckResult update, {
    void Function(double progress)? onProgress,
  }) async {
    final url = update.absoluteDownloadUrl;
    if (url.isEmpty) {
      throw StateError('Download URL is empty');
    }

    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}${Platform.pathSeparator}mimusic_update_${update.latestVersionCode}.apk',
    );
    if (await file.exists()) {
      await file.delete();
    }

    downloadProgress.value = 0;
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(minutes: 30),
      ),
    );

    try {
      await dio.download(
        url,
        file.path,
        onReceiveProgress: (received, total) {
          if (total <= 0) return;
          final p = received / total;
          downloadProgress.value = p;
          onProgress?.call(p);
        },
      );
    } finally {
      downloadProgress.value = null;
    }

    final expectedSha = update.sha256.trim().toLowerCase();
    if (expectedSha.isNotEmpty) {
      final actual = await _sha256HexOfFile(file);
      if (actual != expectedSha) {
        await file.delete();
        throw AppUpdateSha256MismatchException(expectedSha, actual);
      }
    }

    return file.path;
  }

  Future<void> installDownloadedApk(String path) =>
      AppUpdateInstaller.installApk(path);

  Future<String> downloadAndInstall(
    AppUpdateCheckResult update, {
    void Function(double progress)? onProgress,
  }) async {
    final path = await downloadApk(update, onProgress: onProgress);
    await installDownloadedApk(path);
    return path;
  }

  static Future<String> _sha256HexOfFile(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }
}

class AppUpdateSha256MismatchException implements Exception {
  AppUpdateSha256MismatchException(this.expected, this.actual);

  final String expected;
  final String actual;

  @override
  String toString() =>
      'SHA-256 mismatch (expected $expected, got $actual)';
}
