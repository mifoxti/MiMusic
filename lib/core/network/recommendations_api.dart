import 'package:dio/dio.dart';

import '../audio/track.dart';
import 'api_config.dart';
import 'authenticated_dio.dart';

class RecommendedTrackDto {
  const RecommendedTrackDto({
    required this.id,
    required this.title,
    this.artist,
    this.durationSec,
    this.genres = const [],
    this.score = 0,
  });

  final int id;
  final String title;
  final String? artist;
  final int? durationSec;
  final List<String> genres;
  final double score;

  factory RecommendedTrackDto.fromJson(Map<String, dynamic> json) {
    final g = json['genres'];
    return RecommendedTrackDto(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String? ?? '',
      artist: json['artist'] as String?,
      durationSec: (json['duration'] as num?)?.toInt(),
      genres: g is List ? g.map((e) => e.toString()).toList() : const [],
      score: (json['score'] as num?)?.toDouble() ?? 0,
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
      coverAssetPath: coverUrl(),
    );
  }
}

class RecommendationsApi {
  Future<List<RecommendedTrackDto>> fetchRecommendedTracks({int limit = 30}) async {
    final dio = await createAuthenticatedDio();
    final res = await dio.get<List<dynamic>>(
      '/recommendations/tracks',
      queryParameters: {'limit': limit},
    );
    final data = res.data;
    if (data == null) return [];
    return data
        .map((e) => RecommendedTrackDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> postEvents(List<Map<String, dynamic>> events) async {
    if (events.isEmpty) return;
    final dio = await createAuthenticatedDio();
    await dio.post<void>(
      '/recommendations/events',
      data: {'events': events},
      options: Options(contentType: Headers.jsonContentType),
    );
  }
}
