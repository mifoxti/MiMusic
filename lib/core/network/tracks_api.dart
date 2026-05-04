import 'package:dio/dio.dart';

import 'api_config.dart';

/// Элемент списка `GET /tracks` (сервер Ktor).
class ServerTrackListItem {
  const ServerTrackListItem({
    required this.id,
    required this.title,
    this.artist,
    this.durationSec,
    this.genres = const [],
  });

  final int id;
  final String title;
  final String? artist;
  final int? durationSec;
  final List<String> genres;

  factory ServerTrackListItem.fromJson(Map<String, dynamic> json) {
    final g = json['genres'];
    return ServerTrackListItem(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String? ?? '',
      artist: json['artist'] as String?,
      durationSec: (json['duration'] as num?)?.toInt(),
      genres: g is List ? g.map((e) => e.toString()).toList() : const [],
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
}
