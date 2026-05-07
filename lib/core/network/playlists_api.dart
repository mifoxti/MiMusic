import 'dart:io';

import 'package:dio/dio.dart';

import 'api_config.dart';
import 'authenticated_dio.dart';

String playlistCoverUrl(int playlistId) {
  final b = ApiConfig.baseUrl.replaceAll(RegExp(r'/+$'), '');
  return '$b/playlists/$playlistId/cover';
}

String userAvatarUrl(int userId, {int? cacheBust}) {
  final b = ApiConfig.baseUrl.replaceAll(RegExp(r'/+$'), '');
  final u = '$b/users/$userId/avatar';
  if (cacheBust == null) return u;
  return '$u?cb=$cacheBust';
}

int? parseServerPlaylistId(String playlistId) {
  const p = 'srv:';
  if (!playlistId.startsWith(p)) return null;
  return int.tryParse(playlistId.substring(p.length));
}

/// Элемент [GET /me/playlists].
class MyPlaylistListItemRemote {
  const MyPlaylistListItemRemote({
    required this.id,
    required this.title,
    required this.isPublic,
    required this.trackCount,
    this.coverStorageKey,
  });

  final int id;
  final String? title;
  final bool? isPublic;
  final int trackCount;
  final String? coverStorageKey;

  factory MyPlaylistListItemRemote.fromJson(Map<String, dynamic> j) {
    return MyPlaylistListItemRemote(
      id: (j['id'] as num).toInt(),
      title: j['title'] as String?,
      isPublic: j['isPublic'] as bool?,
      trackCount: (j['trackCount'] as num?)?.toInt() ?? 0,
      coverStorageKey: j['coverStorageKey'] as String?,
    );
  }
}

/// Публичный плейлист [GET /playlists/public].
class PublicPlaylistItemRemote {
  const PublicPlaylistItemRemote({
    required this.id,
    required this.title,
    required this.ownerUserId,
    this.ownerNickname,
    required this.likesCount,
    required this.trackCount,
  });

  final int id;
  final String? title;
  final int ownerUserId;
  final String? ownerNickname;
  final int likesCount;
  final int trackCount;

  factory PublicPlaylistItemRemote.fromJson(Map<String, dynamic> j) {
    return PublicPlaylistItemRemote(
      id: (j['id'] as num).toInt(),
      title: j['title'] as String?,
      ownerUserId: (j['ownerUserId'] as num).toInt(),
      ownerNickname: j['ownerNickname'] as String?,
      likesCount: (j['likesCount'] as num?)?.toInt() ?? 0,
      trackCount: (j['trackCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class PlaylistTrackEntryRemote {
  const PlaylistTrackEntryRemote({
    required this.position,
    required this.trackId,
    this.title,
    this.artist,
  });

  final int position;
  final int trackId;
  final String? title;
  final String? artist;

  factory PlaylistTrackEntryRemote.fromJson(Map<String, dynamic> j) {
    return PlaylistTrackEntryRemote(
      position: (j['position'] as num).toInt(),
      trackId: (j['trackId'] as num).toInt(),
      title: j['title'] as String?,
      artist: j['artist'] as String?,
    );
  }
}

class PlaylistDetailRemote {
  const PlaylistDetailRemote({
    required this.id,
    required this.title,
    required this.isPublic,
    required this.ownerUserId,
    this.ownerNickname,
    required this.likesCount,
    required this.tracks,
  });

  final int id;
  final String? title;
  final bool isPublic;
  final int ownerUserId;
  final String? ownerNickname;
  final int likesCount;
  final List<PlaylistTrackEntryRemote> tracks;

  factory PlaylistDetailRemote.fromJson(Map<String, dynamic> j) {
    final raw = j['tracks'];
    final list = raw is List
        ? raw
            .map((e) => PlaylistTrackEntryRemote.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList()
        : const <PlaylistTrackEntryRemote>[];
    return PlaylistDetailRemote(
      id: (j['id'] as num).toInt(),
      title: j['title'] as String?,
      isPublic: j['isPublic'] as bool? ?? false,
      ownerUserId: (j['ownerUserId'] as num).toInt(),
      ownerNickname: j['ownerNickname'] as String?,
      likesCount: (j['likesCount'] as num?)?.toInt() ?? 0,
      tracks: list,
    );
  }
}

class PlaylistLikeStatusRemote {
  const PlaylistLikeStatusRemote({required this.liked, required this.likesCount});

  final bool liked;
  final int likesCount;

  factory PlaylistLikeStatusRemote.fromJson(Map<String, dynamic> j) {
    return PlaylistLikeStatusRemote(
      liked: j['liked'] as bool? ?? false,
      likesCount: (j['likesCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class PlaylistsApi {
  Future<List<MyPlaylistListItemRemote>> fetchMyPlaylists() async {
    final dio = await createAuthenticatedDio();
    final res = await dio.get<List<dynamic>>('/me/playlists');
    final data = res.data;
    if (data == null) return [];
    return data
        .map((e) => MyPlaylistListItemRemote.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<PublicPlaylistItemRemote>> fetchPublicPlaylists({
    String? query,
    int limit = 50,
  }) async {
    final dio = await createAuthenticatedDio();
    final res = await dio.get<List<dynamic>>(
      '/playlists/public',
      queryParameters: {
        'limit': limit,
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      },
    );
    final data = res.data;
    if (data == null) return [];
    return data
        .map((e) => PublicPlaylistItemRemote.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<PlaylistDetailRemote> fetchPlaylistDetail(int id) async {
    final dio = await createAuthenticatedDio();
    final res = await dio.get<Map<String, dynamic>>('/playlists/$id');
    final data = res.data;
    if (data == null) {
      throw StateError('Empty playlist response');
    }
    return PlaylistDetailRemote.fromJson(data);
  }

  Future<int> createPlaylist({required String title, required bool isPublic}) async {
    final dio = await createAuthenticatedDio();
    final res = await dio.post<Map<String, dynamic>>(
      '/playlists',
      data: {'title': title, 'isPublic': isPublic},
    );
    final id = (res.data?['id'] as num?)?.toInt();
    if (id == null) {
      throw StateError('No playlist id in response');
    }
    return id;
  }

  Future<void> updatePlaylist(int id, {String? title, bool? isPublic}) async {
    final dio = await createAuthenticatedDio();
    final body = <String, dynamic>{
      if (title != null) 'title': title,
      if (isPublic != null) 'isPublic': isPublic,
    };
    if (body.isEmpty) return;
    await dio.put<void>('/playlists/$id', data: body);
  }

  Future<void> setPlaylistTracks(int playlistId, List<int> trackIds) async {
    final dio = await createAuthenticatedDio();
    await dio.put<void>(
      '/playlists/$playlistId/tracks',
      data: {'trackIds': trackIds.map((e) => e.toInt()).toList()},
    );
  }

  Future<void> deletePlaylist(int id) async {
    final dio = await createAuthenticatedDio();
    await dio.delete<void>('/playlists/$id');
  }

  Future<void> uploadPlaylistCover(int playlistId, File imageFile) async {
    final dio = await createAuthenticatedDio();
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        imageFile.path,
        filename: imageFile.uri.pathSegments.isNotEmpty ? imageFile.uri.pathSegments.last : 'cover.png',
      ),
    });
    await dio.post<void>('/upload/playlists/$playlistId/cover', data: form);
  }

  Future<PlaylistLikeStatusRemote> postPlaylistLike(int playlistId) async {
    final dio = await createAuthenticatedDio();
    final res = await dio.post<Map<String, dynamic>>('/playlists/$playlistId/like');
    final data = res.data;
    if (data == null) {
      throw StateError('Empty like response');
    }
    return PlaylistLikeStatusRemote.fromJson(data);
  }

  Future<PlaylistLikeStatusRemote> getPlaylistLike(int playlistId) async {
    final dio = await createAuthenticatedDio();
    final res = await dio.get<Map<String, dynamic>>('/playlists/$playlistId/like');
    final data = res.data;
    if (data == null) {
      throw StateError('Empty like response');
    }
    return PlaylistLikeStatusRemote.fromJson(data);
  }
}
