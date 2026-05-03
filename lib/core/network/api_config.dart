import 'package:flutter/foundation.dart'
    show debugPrint, kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart';

/// Базовый URL Ktor API.
///
/// На **Android** после [ensureAndroidDevBaseUrl] подставляется URL с нативной стороны
/// (эмулятор → `10.0.2.2`, USB + reverse → `127.0.0.1`).
///
/// **Wi‑Fi:** в `android/local.properties`: `flutter.apiBaseUrl=http://IP_ПК:8080`
///
/// **Dart-define:** `--dart-define=API_BASE_URL=...` (compile-time), перекрывает эвристику, если не пустой.
abstract final class ApiConfig {
  static const String _fromEnv = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  /// Подмена с Android (MethodChannel), иначе null.
  static String? _androidResolved;

  static String get baseUrl {
    final android = _androidResolved?.trim();
    if (android != null && android.isNotEmpty) return android;
    final fromCompile = _fromEnv.trim();
    if (fromCompile.isNotEmpty) return fromCompile;
    if (kIsWeb) return 'http://localhost:8080';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://127.0.0.1:8080';
    }
    return 'http://127.0.0.1:8080';
  }

  /// Вызови из `main()` после [WidgetsFlutterBinding.ensureInitialized].
  static Future<void> ensureAndroidDevBaseUrl() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      const ch = MethodChannel('com.example.mimusic/api_config');
      final url = await ch.invokeMethod<String>('getBaseUrl');
      if (url != null && url.trim().isNotEmpty) {
        _androidResolved = url.trim();
        debugPrint('ApiConfig: baseUrl=$_androidResolved');
      }
    } catch (e, st) {
      debugPrint('ApiConfig: MethodChannel getBaseUrl failed: $e\n$st');
    }
  }
}
