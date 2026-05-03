import 'package:dio/dio.dart';

import '../auth/invite_key_format.dart';
import 'api_config.dart';

class AuthApiException implements Exception {
  AuthApiException(this.messageKey, {this.statusCode});

  /// Ключ для [AppLocalization], например `auth.error.network`.
  final String messageKey;
  final int? statusCode;

  @override
  String toString() => 'AuthApiException($messageKey, $statusCode)';
}

class AuthSessionDto {
  const AuthSessionDto({
    required this.token,
    required this.userId,
    required this.nickname,
    this.email,
  });

  final String token;
  final int userId;
  final String nickname;
  final String? email;

  static AuthSessionDto fromJson(Map<String, dynamic> json) {
    return AuthSessionDto(
      token: json['token'] as String,
      userId: (json['id'] as num).toInt(),
      nickname: json['nickname'] as String? ?? '',
      email: json['email'] as String?,
    );
  }
}

/// Регистрация и вход на сервере MiMusic (Ktor + PostgreSQL).
class AuthApi {
  AuthApi({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: ApiConfig.baseUrl,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 20),
                headers: {'Content-Type': 'application/json'},
              ),
            );

  final Dio _dio;

  Future<AuthSessionDto> register({
    required String email,
    required String nickname,
    required String password,
    String? inviteCode,
  }) async {
    try {
      final body = <String, dynamic>{
        'login': nickname,
        'email': email,
        'password': password,
      };
      final ic = inviteCode?.trim();
      if (ic != null && ic.isNotEmpty) {
        body['inviteCode'] = InviteKeyFormat.normalize(ic);
      }
      final res = await _dio.post<Map<String, dynamic>>('/register', data: body);
      final data = res.data;
      if (data == null) {
        throw AuthApiException('auth.error.server', statusCode: res.statusCode);
      }
      return AuthSessionDto.fromJson(data);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  Future<AuthSessionDto> login({
    required String emailOrNickname,
    required String password,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/login',
        data: {
          'login': emailOrNickname.trim(),
          'password': password,
        },
      );
      final data = res.data;
      if (data == null) {
        throw AuthApiException('auth.error.server', statusCode: res.statusCode);
      }
      return AuthSessionDto.fromJson(data);
    } on DioException catch (e) {
      throw _mapDio(e);
    }
  }

  AuthApiException _mapDio(DioException e) {
    final code = e.response?.statusCode;
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return AuthApiException('auth.error.network', statusCode: code);
    }
    if (code == 401) {
      return AuthApiException('auth.error.badCredentials', statusCode: code);
    }
    if (code == 409) {
      final body = e.response?.data?.toString() ?? '';
      if (body.contains('Email')) {
        return AuthApiException('auth.error.emailTaken', statusCode: code);
      }
      return AuthApiException('auth.error.accountExists', statusCode: code);
    }
    if (code == 400) {
      final msg = e.response?.data?.toString() ?? '';
      if (msg.toLowerCase().contains('invite')) {
        return AuthApiException('auth.error.inviteInvalid', statusCode: code);
      }
      return AuthApiException('auth.error.badCredentials', statusCode: code);
    }
    return AuthApiException('auth.error.server', statusCode: code);
  }
}
