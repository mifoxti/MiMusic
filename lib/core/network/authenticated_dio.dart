import 'package:dio/dio.dart';

import '../auth/auth_session_store.dart';
import 'api_config.dart';

/// Dio с [Authorization: Bearer] при наличии серверной сессии.
Future<Dio> createAuthenticatedDio() async {
  final acc = await AuthSessionStore.readAccount();
  final token = acc?.sessionToken.trim() ?? '';
  final base = ApiConfig.baseUrl.replaceAll(RegExp(r'/+$'), '');
  return Dio(
    BaseOptions(
      baseUrl: base,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    ),
  );
}
