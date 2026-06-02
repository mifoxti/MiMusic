import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../audio/track.dart';
import 'api_config.dart';
import 'authenticated_dio.dart';

class ChartTrackDto {
  const ChartTrackDto({
    required this.rank,
    required this.trackId,
    required this.title,
    this.artist,
    required this.playCount,
    this.playCountToday = 0,
    this.coverBytes,
    this.isNew = false,
  });

  final int rank;
  final int trackId;
  final String title;
  final String? artist;
  final int playCount;
  final int playCountToday;
  final Uint8List? coverBytes;
  final bool isNew;

  factory ChartTrackDto.fromJson(Map<String, dynamic> j) {
    Uint8List? coverBytes;
    final rawCover = j['cover'];
    if (rawCover is String && rawCover.isNotEmpty) {
      try {
        coverBytes = Uint8List.fromList(base64Decode(rawCover));
      } catch (_) {
        coverBytes = null;
      }
    }
    return ChartTrackDto(
      rank: (j['rank'] as num).toInt(),
      trackId: (j['trackId'] as num).toInt(),
      title: j['title'] as String? ?? '',
      artist: j['artist'] as String?,
      playCount: (j['playCount'] as num?)?.toInt() ?? 0,
      playCountToday: (j['playCountToday'] as num?)?.toInt() ?? 0,
      coverBytes: coverBytes,
      isNew: j['isNew'] as bool? ?? false,
    );
  }

  Track toTrack() {
    return Track(
      assetPath: 'server_track_$trackId',
      title: title,
      artist: artist,
      audioFilePath: streamUrl(),
      coverBytes: coverBytes,
      coverAssetPath: coverUrl(),
    );
  }

  String coverUrl() {
    final b = ApiConfig.baseUrl.replaceAll(RegExp(r'/+$'), '');
    return '$b/tracks/$trackId/cover';
  }

  String streamUrl() {
    final b = ApiConfig.baseUrl.replaceAll(RegExp(r'/+$'), '');
    return '$b/tracks/$trackId/stream';
  }
}

class ChartsApi {
  ChartsApi({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: ApiConfig.baseUrl,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 30),
              ),
            );

  final Dio _dio;

  Future<Dio> _chartsDio() async {
    try {
      return await createAuthenticatedDio();
    } catch (_) {
      return _dio;
    }
  }

  /// [sort]: `today` (по прослушиваниям за сегодня) или `total` (за всё время).
  Future<List<ChartTrackDto>> fetchTopTracks({
    int limit = 20,
    String sort = 'today',
  }) async {
    final Dio dio = await _chartsDio();
    final res = await dio.get<List<dynamic>>(
      '/charts/tracks',
      queryParameters: {'limit': limit, 'sort': sort},
    );
    final data = res.data;
    if (data == null) return [];
    return data
        .map((e) => ChartTrackDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}
