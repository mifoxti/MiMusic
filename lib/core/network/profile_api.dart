import 'dart:io';

import 'package:dio/dio.dart';

import 'authenticated_dio.dart';

class MeProfileRemote {
  const MeProfileRemote({
    required this.id,
    required this.nickname,
    this.email,
    this.bio,
    this.avatarStorageKey,
  });

  final int id;
  final String nickname;
  final String? email;
  final String? bio;
  final String? avatarStorageKey;

  factory MeProfileRemote.fromJson(Map<String, dynamic> j) {
    return MeProfileRemote(
      id: (j['id'] as num).toInt(),
      nickname: j['nickname'] as String? ?? '',
      email: j['email'] as String?,
      bio: j['bio'] as String?,
      avatarStorageKey: j['avatarStorageKey'] as String?,
    );
  }
}

class MeStatsRemote {
  const MeStatsRemote({
    required this.tracksCount,
    required this.playlistsCount,
    required this.friendsCount,
  });

  final int tracksCount;
  final int playlistsCount;
  final int friendsCount;

  factory MeStatsRemote.fromJson(Map<String, dynamic> j) {
    return MeStatsRemote(
      tracksCount: (j['tracksCount'] as num?)?.toInt() ?? 0,
      playlistsCount: (j['playlistsCount'] as num?)?.toInt() ?? 0,
      friendsCount: (j['friendsCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class ProfileApi {
  Future<MeProfileRemote> fetchMe() async {
    final dio = await createAuthenticatedDio();
    final res = await dio.get<Map<String, dynamic>>('/me');
    final data = res.data;
    if (data == null) throw StateError('Empty /me');
    return MeProfileRemote.fromJson(data);
  }

  Future<MeStatsRemote> fetchMeStats() async {
    final dio = await createAuthenticatedDio();
    final res = await dio.get<Map<String, dynamic>>('/me/stats');
    final data = res.data;
    if (data == null) throw StateError('Empty /me/stats');
    return MeStatsRemote.fromJson(data);
  }

  /// Смена пароля учётной записи на сервере ([PUT /me/password]).
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final dio = await createAuthenticatedDio();
    await dio.put<void>(
      '/me/password',
      data: <String, dynamic>{
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );
  }

  Future<MeProfileRemote> patchMe({
    String? nickname,
    String? email,
    String? bio,
  }) async {
    final dio = await createAuthenticatedDio();
    final body = <String, dynamic>{
      if (nickname != null) 'nickname': nickname,
      if (email != null) 'email': email,
      if (bio != null) 'bio': bio,
    };
    if (body.isEmpty) {
      return fetchMe();
    }
    final res = await dio.put<Map<String, dynamic>>('/me', data: body);
    final data = res.data;
    if (data == null) throw StateError('Empty /me after patch');
    return MeProfileRemote.fromJson(data);
  }

  Future<void> uploadAvatar(File imageFile) async {
    final dio = await createAuthenticatedDio();
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        imageFile.path,
        filename: imageFile.uri.pathSegments.isNotEmpty ? imageFile.uri.pathSegments.last : 'avatar.png',
      ),
    });
    await dio.post<void>('/upload/avatar', data: form);
  }

  /// Активный ключ или `null`, если [404].
  Future<String?> fetchMyInviteKey() async {
    final dio = await createAuthenticatedDio();
    try {
      final res = await dio.get<Map<String, dynamic>>('/me/invite-key');
      final data = res.data;
      return data?['keyCode'] as String?;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// [PUT /me/now-playing] — `trackId: null` сбрасывает статус на сервере.
  Future<void> putNowPlaying({int? trackId}) async {
    final dio = await createAuthenticatedDio();
    await dio.put<void>(
      '/me/now-playing',
      data: <String, dynamic>{'trackId': trackId},
    );
  }

  Future<String> postMyInviteKey({String? keyCode}) async {
    final dio = await createAuthenticatedDio();
    final res = await dio.post<Map<String, dynamic>>(
      '/me/invite-key',
      data: {if (keyCode != null && keyCode.trim().isNotEmpty) 'keyCode': keyCode.trim()},
    );
    final k = res.data?['keyCode'] as String?;
    if (k == null || k.isEmpty) throw StateError('No keyCode in response');
    return k;
  }
}
