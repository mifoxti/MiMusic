import 'package:dio/dio.dart';

import 'authenticated_dio.dart';

class ListeningHistoryItemDto {
  const ListeningHistoryItemDto({
    required this.trackId,
    required this.title,
    this.artist,
    this.playedAt,
  });

  final int trackId;
  final String title;
  final String? artist;
  final String? playedAt;

  factory ListeningHistoryItemDto.fromJson(Map<String, dynamic> j) {
    return ListeningHistoryItemDto(
      trackId: (j['trackId'] as num).toInt(),
      title: j['title'] as String? ?? '',
      artist: j['artist'] as String?,
      playedAt: j['playedAt'] as String?,
    );
  }
}

class ListeningHistoryApi {
  Future<Dio> _authDio() => createAuthenticatedDio();

  Future<void> recordListen(int trackId) async {
    final dio = await _authDio();
    await dio.post<void>('/me/listen-events', data: {'trackId': trackId});
  }

  Future<List<ListeningHistoryItemDto>> fetchHistory({int limit = 100}) async {
    final dio = await _authDio();
    final res = await dio.get<List<dynamic>>(
      '/me/listening-history',
      queryParameters: {'limit': limit},
    );
    final data = res.data;
    if (data == null) return [];
    return data
        .map((e) => ListeningHistoryItemDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}
