import 'package:dio/dio.dart';

import 'api_config.dart';

class UserSearchResult {
  const UserSearchResult({required this.id, required this.nickname});

  final int id;
  final String nickname;

  factory UserSearchResult.fromJson(Map<String, dynamic> j) {
    return UserSearchResult(
      id: (j['id'] as num).toInt(),
      nickname: j['nickname'] as String? ?? '',
    );
  }
}

/// Поиск пользователей по нику ([GET /users/search]) — без авторизации.
class UsersApi {
  UsersApi({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: ApiConfig.baseUrl,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 20),
              ),
            );

  final Dio _dio;

  Future<List<UserSearchResult>> searchUsers(String query) async {
    final q = query.trim();
    if (q.length < 2) return [];
    final res = await _dio.get<List<dynamic>>(
      '/users/search',
      queryParameters: {'q': q},
    );
    final data = res.data;
    if (data == null) return [];
    return data
        .map((e) => UserSearchResult.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// [GET /users/nickname-available] — для регистрации и смены ника.
  Future<bool> isNicknameAvailable(String nickname, {int? exceptUserId}) async {
    final nick = nickname.trim();
    if (nick.length < 2) return false;
    final qp = <String, dynamic>{'nick': nick};
    if (exceptUserId != null) {
      qp['exceptUserId'] = exceptUserId;
    }
    final res = await _dio.get<Map<String, dynamic>>(
      '/users/nickname-available',
      queryParameters: qp,
    );
    final data = res.data;
    if (data == null) return false;
    return data['available'] == true;
  }
}
