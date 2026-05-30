import 'package:dio/dio.dart';

import 'api_config.dart';
import 'authenticated_dio.dart';

String albumCoverUrl(int albumId) {
  final b = ApiConfig.baseUrl.replaceAll(RegExp(r'/+$'), '');
  return '$b/albums/$albumId/cover';
}

/// Публичный альбом из [GET /albums/public].
class PublicAlbumItemRemote {
  const PublicAlbumItemRemote({
    required this.id,
    required this.title,
    required this.ownerUserId,
    this.ownerNickname,
    required this.trackCount,
  });

  final int id;
  final String? title;
  final int ownerUserId;
  final String? ownerNickname;
  final int trackCount;

  factory PublicAlbumItemRemote.fromJson(Map<String, dynamic> j) {
    return PublicAlbumItemRemote(
      id: (j['id'] as num).toInt(),
      title: j['title'] as String?,
      ownerUserId: (j['ownerUserId'] as num).toInt(),
      ownerNickname: j['ownerNickname'] as String?,
      trackCount: (j['trackCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class AlbumDetailRemote {
  const AlbumDetailRemote({
    required this.id,
    required this.title,
    required this.tracks,
  });

  final int id;
  final String? title;
  final List<AlbumTrackEntryRemote> tracks;

  factory AlbumDetailRemote.fromJson(Map<String, dynamic> j) {
    final raw = j['tracks'];
    return AlbumDetailRemote(
      id: (j['id'] as num).toInt(),
      title: j['title'] as String?,
      tracks: raw is List
          ? raw
              .map(
                (e) => AlbumTrackEntryRemote.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList()
          : const [],
    );
  }
}

class AlbumTrackEntryRemote {
  const AlbumTrackEntryRemote({
    required this.position,
    required this.trackId,
    this.title,
    this.artist,
  });

  final int position;
  final int trackId;
  final String? title;
  final String? artist;

  factory AlbumTrackEntryRemote.fromJson(Map<String, dynamic> j) {
    return AlbumTrackEntryRemote(
      position: (j['position'] as num?)?.toInt() ?? 0,
      trackId: (j['trackId'] as num).toInt(),
      title: j['title'] as String?,
      artist: j['artist'] as String?,
    );
  }
}

class MyAlbumListItemRemote {
  const MyAlbumListItemRemote({
    required this.id,
    required this.title,
    required this.isPublic,
    required this.trackCount,
  });

  final int id;
  final String? title;
  final bool? isPublic;
  final int trackCount;

  factory MyAlbumListItemRemote.fromJson(Map<String, dynamic> j) {
    return MyAlbumListItemRemote(
      id: (j['id'] as num).toInt(),
      title: j['title'] as String?,
      isPublic: j['isPublic'] as bool?,
      trackCount: (j['trackCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class AlbumsApi {
  Future<List<MyAlbumListItemRemote>> fetchMyAlbums() async {
    final dio = await createAuthenticatedDio();
    final res = await dio.get<List<dynamic>>('/me/albums');
    final data = res.data;
    if (data == null) return [];
    return data
        .map((e) => MyAlbumListItemRemote.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<int> createAlbum({
    required String title,
    required List<String> genreSlugs,
    bool isPublic = false,
    bool normalizeGenreWeights = false,
  }) async {
    final dio = await createAuthenticatedDio();
    final res = await dio.post<Map<String, dynamic>>(
      '/albums',
      data: {
        'title': title,
        'genreSlugs': genreSlugs,
        'isPublic': isPublic,
        'normalizeGenreWeights': normalizeGenreWeights,
      },
      options: Options(contentType: Headers.jsonContentType),
    );
    final id = res.data?['id'];
    if (id is num) return id.toInt();
    return 0;
  }

  /// [GET /albums/public?q=] — публичные альбомы по названию (минимум 2 символа).
  Future<List<PublicAlbumItemRemote>> searchPublicAlbums({
    required String query,
    int limit = 40,
  }) async {
    final q = query.trim();
    if (q.length < 2) return [];
    final dio = await _dioWithOptionalAuth();
    final res = await dio.get<List<dynamic>>(
      '/albums/public',
      queryParameters: {'q': q, 'limit': limit},
    );
    final data = res.data;
    if (data == null) return [];
    return data
        .map((e) => PublicAlbumItemRemote.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// [GET /albums/{id}] — детали альбома (публичный или свой).
  Future<Dio> _dioWithOptionalAuth() async {
    try {
      return await createAuthenticatedDio();
    } catch (_) {
      return Dio(
        BaseOptions(
          baseUrl: ApiConfig.baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
    }
  }

  Future<AlbumDetailRemote> fetchAlbumDetail(int albumId) async {
    final dio = await _dioWithOptionalAuth();
    final res = await dio.get<Map<String, dynamic>>('/albums/$albumId');
    final data = res.data;
    if (data == null) {
      throw StateError('Empty album response');
    }
    return AlbumDetailRemote.fromJson(data);
  }
}
