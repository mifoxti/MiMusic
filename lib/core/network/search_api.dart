import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../audio/track.dart';
import '../auth/auth_session_store.dart';
import 'api_config.dart';
import 'authenticated_dio.dart';

/// Результат [GET /search?q=] (треки на сервере).
class SearchTrackResult {
  const SearchTrackResult({
    required this.id,
    required this.title,
    this.artist,
    this.durationSec,
    this.coverBytes,
    this.isLiked = false,
  });

  final int id;
  final String title;
  final String? artist;
  final int? durationSec;
  final Uint8List? coverBytes;
  final bool isLiked;

  factory SearchTrackResult.fromJson(Map<String, dynamic> json) {
    Uint8List? coverBytes;
    final rawCover = json['coverArt'] ?? json['cover'];
    if (rawCover is String && rawCover.isNotEmpty) {
      try {
        coverBytes = Uint8List.fromList(base64Decode(rawCover));
      } catch (_) {
        coverBytes = null;
      }
    }
    return SearchTrackResult(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String? ?? '',
      artist: json['artist'] as String?,
      durationSec: (json['duration'] as num?)?.toInt(),
      coverBytes: coverBytes,
      isLiked: json['isLiked'] as bool? ?? false,
    );
  }

  String streamUrl() {
    final b = ApiConfig.baseUrl.replaceAll(RegExp(r'/+$'), '');
    return '$b/tracks/$id/stream';
  }

  String coverUrl() {
    final b = ApiConfig.baseUrl.replaceAll(RegExp(r'/+$'), '');
    return '$b/tracks/$id/cover';
  }

  Track toTrack() {
    return Track(
      assetPath: 'server_track_$id',
      title: title,
      artist: artist,
      audioFilePath: streamUrl(),
      coverBytes: coverBytes,
      coverAssetPath: coverUrl(),
    );
  }
}

class SearchApi {
  SearchApi({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: ApiConfig.baseUrl,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 30),
              ),
            );

  final Dio _dio;

  /// [GET /search] — поиск треков по названию и исполнителю (минимум 2 символа в `q`).
  Future<List<SearchTrackResult>> searchTracks({
    required String query,
    int limit = 40,
    int? userId,
  }) async {
    final q = query.trim();
    if (q.length < 2) return [];
    final dio = await _dioWithOptionalAuth();
    final params = <String, dynamic>{
      'q': q,
      'limit': limit,
    };
    if (userId != null) {
      params['userId'] = userId;
    }
    final res = await dio.get<List<dynamic>>(
      '/search',
      queryParameters: params,
    );
    final data = res.data;
    if (data == null) return [];
    return data
        .map((e) => SearchTrackResult.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Dio> _dioWithOptionalAuth() async {
    final acc = await AuthSessionStore.readAccount();
    if (acc != null && acc.sessionToken.trim().isNotEmpty) {
      try {
        return await createAuthenticatedDio();
      } catch (_) {}
    }
    return _dio;
  }
}
