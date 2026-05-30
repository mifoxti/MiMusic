import 'package:dio/dio.dart';

import 'authenticated_dio.dart';

class PlaysByDayDto {
  const PlaysByDayDto({required this.date, required this.count});

  final String date;
  final int count;

  factory PlaysByDayDto.fromJson(Map<String, dynamic> j) {
    return PlaysByDayDto(
      date: j['date'] as String? ?? '',
      count: (j['count'] as num?)?.toInt() ?? 0,
    );
  }
}

class StudioTopTrackDto {
  const StudioTopTrackDto({
    required this.trackId,
    required this.title,
    required this.playCount,
  });

  final int trackId;
  final String title;
  final int playCount;

  factory StudioTopTrackDto.fromJson(Map<String, dynamic> j) {
    return StudioTopTrackDto(
      trackId: (j['trackId'] as num).toInt(),
      title: j['title'] as String? ?? '',
      playCount: (j['playCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class MeStudioStatsDto {
  const MeStudioStatsDto({
    required this.totalPlays,
    required this.totalTracks,
    required this.uniqueListeners,
    required this.playsByDay,
    required this.topTracks,
  });

  final int totalPlays;
  final int totalTracks;
  final int uniqueListeners;
  final List<PlaysByDayDto> playsByDay;
  final List<StudioTopTrackDto> topTracks;

  factory MeStudioStatsDto.fromJson(Map<String, dynamic> j) {
    List<T> parseList<T>(String key, T Function(Map<String, dynamic>) fromJson) {
      final raw = j[key];
      if (raw is! List) return [];
      return raw
          .map((e) => fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }

    return MeStudioStatsDto(
      totalPlays: (j['totalPlays'] as num?)?.toInt() ?? 0,
      totalTracks: (j['totalTracks'] as num?)?.toInt() ?? 0,
      uniqueListeners: (j['uniqueListeners'] as num?)?.toInt() ?? 0,
      playsByDay: parseList('playsByDay', PlaysByDayDto.fromJson),
      topTracks: parseList('topTracks', StudioTopTrackDto.fromJson),
    );
  }
}

class TrackStudioStatsDto {
  const TrackStudioStatsDto({
    required this.trackId,
    required this.title,
    this.artist,
    required this.totalPlays,
    required this.uniqueListeners,
    required this.playsByDay,
  });

  final int trackId;
  final String title;
  final String? artist;
  final int totalPlays;
  final int uniqueListeners;
  final List<PlaysByDayDto> playsByDay;

  factory TrackStudioStatsDto.fromJson(Map<String, dynamic> j) {
    final raw = j['playsByDay'];
    return TrackStudioStatsDto(
      trackId: (j['trackId'] as num).toInt(),
      title: j['title'] as String? ?? '',
      artist: j['artist'] as String?,
      totalPlays: (j['totalPlays'] as num?)?.toInt() ?? 0,
      uniqueListeners: (j['uniqueListeners'] as num?)?.toInt() ?? 0,
      playsByDay: raw is List
          ? raw
              .map((e) => PlaysByDayDto.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList()
          : const [],
    );
  }
}

class StudioStatsApi {
  Future<MeStudioStatsDto> fetchArtistStats({int days = 14}) async {
    final dio = await createAuthenticatedDio();
    final res = await dio.get<Map<String, dynamic>>(
      '/me/studio/stats',
      queryParameters: {'days': days},
    );
    final data = res.data;
    if (data == null) throw StateError('Empty studio stats');
    return MeStudioStatsDto.fromJson(data);
  }

  Future<TrackStudioStatsDto> fetchTrackStats(int trackId, {int days = 14}) async {
    final dio = await createAuthenticatedDio();
    final res = await dio.get<Map<String, dynamic>>(
      '/tracks/$trackId/studio-stats',
      queryParameters: {'days': days},
    );
    final data = res.data;
    if (data == null) throw StateError('Empty track stats');
    return TrackStudioStatsDto.fromJson(data);
  }
}
