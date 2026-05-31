import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Установка APK на Android через системный инсталлер.
abstract final class AppUpdateInstaller {
  static const _channel = MethodChannel('com.example.mimusic/app_update');

  static bool get isSupported =>
      !kIsWeb && Platform.isAndroid;

  static Future<void> installApk(String filePath) async {
    if (!isSupported) {
      throw UnsupportedError('APK install is Android-only');
    }
    await _channel.invokeMethod<void>('installApk', <String, dynamic>{
      'path': filePath,
    });
  }
}
