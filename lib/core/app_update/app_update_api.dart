import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../network/api_config.dart';

class AppUpdateCheckResult {
  const AppUpdateCheckResult({
    required this.updateAvailable,
    required this.latestVersionCode,
    required this.latestVersionName,
    required this.downloadUrl,
    required this.sha256,
    required this.releaseNotes,
    required this.mandatory,
    required this.currentVersionCode,
    required this.currentVersionName,
  });

  final bool updateAvailable;
  final int latestVersionCode;
  final String latestVersionName;
  final String downloadUrl;
  final String sha256;
  final String releaseNotes;
  final bool mandatory;
  final int currentVersionCode;
  final String currentVersionName;

  String get absoluteDownloadUrl {
    final path = downloadUrl.trim();
    if (path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final base = ApiConfig.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final rel = path.startsWith('/') ? path : '/$path';
    return '$base$rel';
  }

  factory AppUpdateCheckResult.fromJson(
    Map<String, dynamic> json, {
    required int currentVersionCode,
    required String currentVersionName,
  }) {
    return AppUpdateCheckResult(
      updateAvailable: json['updateAvailable'] as bool? ?? false,
      latestVersionCode: (json['latestVersionCode'] as num?)?.toInt() ?? 0,
      latestVersionName: json['latestVersionName'] as String? ?? '',
      downloadUrl: json['downloadUrl'] as String? ?? '',
      sha256: (json['sha256'] as String? ?? '').trim().toLowerCase(),
      releaseNotes: json['releaseNotes'] as String? ?? '',
      mandatory: json['mandatory'] as bool? ?? false,
      currentVersionCode: currentVersionCode,
      currentVersionName: currentVersionName,
    );
  }
}

class AppUpdateApi {
  AppUpdateApi({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: ApiConfig.baseUrl,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 30),
              ),
            );

  final Dio _dio;

  Future<AppUpdateCheckResult> checkAndroidUpdate({
    required int versionCode,
    required String versionName,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/app/update/android',
      queryParameters: {
        'versionCode': versionCode,
        'versionName': versionName,
      },
    );
    final data = res.data;
    if (data == null) {
      throw StateError('Empty update check response');
    }
    return AppUpdateCheckResult.fromJson(
      data,
      currentVersionCode: versionCode,
      currentVersionName: versionName,
    );
  }

  static Future<({int code, String name})> currentAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    final code = int.tryParse(info.buildNumber) ?? 0;
    return (code: code, name: info.version);
  }
}
