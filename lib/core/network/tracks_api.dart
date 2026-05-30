import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../audio/track.dart';
import 'api_config.dart';
import 'authenticated_dio.dart';

/// Элемент списка `GET /tracks` (сервер Ktor).
class ServerTrackListItem {
  const ServerTrackListItem({
    required this.id,
    required this.title,
    this.artist,
    this.durationSec,
    this.genres = const [],
    this.coverBytes,
    this.playCount = 0,
  });

  final int id;
  final String title;
  final String? artist;
  final int? durationSec;
  final List<String> genres;
  final int playCount;

  /// Растровые байты обложки из поля JSON `cover` (base64), если сервер их отдал.
  final Uint8List? coverBytes;

  factory ServerTrackListItem.fromJson(Map<String, dynamic> json) {
    final g = json['genres'];
    Uint8List? coverBytes;
    final rawCover = json['cover'];
    if (rawCover is String && rawCover.isNotEmpty) {
      try {
        coverBytes = Uint8List.fromList(base64Decode(rawCover));
      } catch (_) {
        coverBytes = null;
      }
    }
    return ServerTrackListItem(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String? ?? '',
      artist: json['artist'] as String?,
      durationSec: (json['duration'] as num?)?.toInt(),
      genres: g is List ? g.map((e) => e.toString()).toList() : const [],
      coverBytes: coverBytes,
      playCount: (json['playCount'] as num?)?.toInt() ?? 0,
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

class TracksApi {
  TracksApi({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: ApiConfig.baseUrl,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 30),
              ),
            );

  final Dio _dio;

  /// Последние по `id` (новые загрузки сверху). Параметр `limit` — query на сервере.
  Future<List<ServerTrackListItem>> fetchTracks({int limit = 30}) async {
    final res = await _dio.get<List<dynamic>>(
      '/tracks',
      queryParameters: {'limit': limit},
    );
    final data = res.data;
    if (data == null) return [];
    return data
        .map((e) => ServerTrackListItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Треки, выгруженные текущим пользователем ([GET /me/tracks]).
  Future<List<ServerTrackListItem>> fetchMyUploadedTracks({int limit = 100}) async {
    final dio = await createAuthenticatedDio();
    final res = await dio.get<List<dynamic>>(
      '/me/tracks',
      queryParameters: {'limit': limit},
    );
    final data = res.data;
    if (data == null) return [];
    return data
        .map((e) => ServerTrackListItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<ServerTrackListItem> fetchTrackById(int trackId) async {
    final res = await _dio.get<Map<String, dynamic>>('/tracks/$trackId');
    final data = res.data;
    if (data == null) {
      throw StateError('Empty track response');
    }
    return ServerTrackListItem.fromJson(data);
  }

  int? parseServerTrackId(String path) {
    const p = 'server_track_';
    if (!path.startsWith(p)) return null;
    return int.tryParse(path.substring(p.length));
  }

  /// Id трека на сервере: явный [metadataServerTrackId], [assetPath] вида `server_track_N` или URL `.../tracks/N/stream`.
  int? resolveServerTrackId({
    required String assetPath,
    String? audioFilePath,
    int? metadataServerTrackId,
  }) {
    if (metadataServerTrackId != null) return metadataServerTrackId;
    final fromAsset = parseServerTrackId(assetPath);
    if (fromAsset != null) return fromAsset;
    final p = audioFilePath;
    if (p == null || !p.contains('/tracks/')) return null;
    final m = RegExp(r'/tracks/(\d+)/stream').firstMatch(p);
    if (m == null) return null;
    return int.tryParse(m.group(1)!);
  }

  String trackKeyForPaths({
    required String assetPath,
    String? audioFilePath,
  }) {
    final sid = resolveServerTrackId(assetPath: assetPath, audioFilePath: audioFilePath);
    if (sid != null) return 'srv:$sid';
    return 'asset:$assetPath';
  }

  /// [PATCH /tracks/{id}] — title/artist без перезаливки аудио.
  Future<void> updateTrackMetadata({
    required int trackId,
    String? title,
    String? artist,
  }) async {
    final dio = await createAuthenticatedDio();
    await dio.patch<void>(
      '/tracks/$trackId',
      data: {
        if (title != null) 'title': title,
        if (artist != null) 'artist': artist,
      },
      options: Options(contentType: Headers.jsonContentType),
    );
  }

  /// [DELETE /tracks/{id}] — только для владельца трека; файлы удаляются на сервере.
  Future<void> deleteServerTrack(int trackId) async {
    final dio = await createAuthenticatedDio();
    await dio.delete<void>('/tracks/$trackId');
  }

  Future<bool> getTrackLikeStatus({
    required int trackId,
    required int userId,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/tracks/$trackId/like',
      queryParameters: {'userId': userId},
    );
    return res.data?['status'] as bool? ?? false;
  }

  Future<bool> toggleTrackLike({
    required int trackId,
    required int userId,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/tracks/$trackId/like',
      data: {'userId': userId},
    );
    return res.data?['status'] as bool? ?? false;
  }
}
