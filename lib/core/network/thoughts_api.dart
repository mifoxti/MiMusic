import 'package:dio/dio.dart';

import 'api_config.dart';
import 'authenticated_dio.dart';

/// Элемент ленты мыслей ([GET /thoughts/feed], [GET /users/{id}/thoughts], [POST /thoughts]).
class ThoughtFeedItemDto {
  const ThoughtFeedItemDto({
    required this.id,
    required this.authorUserId,
    required this.authorNickname,
    this.bodyText,
    this.createdAt,
    this.attachmentType,
    this.attachmentTrackId,
    this.attachmentPlaylistId,
    this.attachmentTrackTitle,
    this.attachmentTrackArtist,
    this.attachmentPlaylistTitle,
    this.isFriend = false,
  });

  final int id;
  final int authorUserId;
  final String authorNickname;
  final String? bodyText;
  final String? createdAt;
  final int? attachmentType;
  final int? attachmentTrackId;
  final int? attachmentPlaylistId;
  final String? attachmentTrackTitle;
  final String? attachmentTrackArtist;
  final String? attachmentPlaylistTitle;
  final bool isFriend;

  factory ThoughtFeedItemDto.fromJson(Map<String, dynamic> j) {
    return ThoughtFeedItemDto(
      id: (j['id'] as num).toInt(),
      authorUserId: (j['authorUserId'] as num).toInt(),
      authorNickname: j['authorNickname'] as String? ?? '',
      bodyText: j['bodyText'] as String?,
      createdAt: j['createdAt'] as String?,
      attachmentType: (j['attachmentType'] as num?)?.toInt(),
      attachmentTrackId: (j['attachmentTrackId'] as num?)?.toInt(),
      attachmentPlaylistId: (j['attachmentPlaylistId'] as num?)?.toInt(),
      attachmentTrackTitle: j['attachmentTrackTitle'] as String?,
      attachmentTrackArtist: j['attachmentTrackArtist'] as String?,
      attachmentPlaylistTitle: j['attachmentPlaylistTitle'] as String?,
      isFriend: j['isFriend'] as bool? ?? false,
    );
  }
}

class ThoughtsApi {
  ThoughtsApi({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: ApiConfig.baseUrl,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 30),
              ),
            );

  final Dio _dio;

  /// Текст последней мысли или `null`, если нет или 404.
  Future<String?> fetchLatestThoughtText(int userId) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/users/$userId/thought');
      final thought = res.data?['thought'] as String?;
      return thought?.trim().isEmpty ?? true ? null : thought;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<List<ThoughtFeedItemDto>> fetchThoughtFeed({
    required String scope,
    int limit = 40,
  }) async {
    final dio = await createAuthenticatedDio();
    final res = await dio.get<List<dynamic>>(
      '/thoughts/feed',
      queryParameters: {'scope': scope, 'limit': limit},
    );
    final data = res.data;
    if (data == null) return [];
    return data
        .map((e) => ThoughtFeedItemDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<ThoughtFeedItemDto>> fetchUserThoughts(int userId, {int limit = 50}) async {
    final dio = await createAuthenticatedDio();
    final res = await dio.get<List<dynamic>>(
      '/users/$userId/thoughts',
      queryParameters: {'limit': limit},
    );
    final data = res.data;
    if (data == null) return [];
    return data
        .map((e) => ThoughtFeedItemDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<ThoughtFeedItemDto> createThought({
    required String bodyText,
    int? attachmentType,
    int? attachmentTrackId,
    int? attachmentPlaylistId,
  }) async {
    final dio = await createAuthenticatedDio();
    final body = <String, dynamic>{
      'bodyText': bodyText,
      if (attachmentType != null) 'attachmentType': attachmentType,
      if (attachmentTrackId != null) 'attachmentTrackId': attachmentTrackId,
      if (attachmentPlaylistId != null) 'attachmentPlaylistId': attachmentPlaylistId,
    };
    final res = await dio.post<Map<String, dynamic>>('/thoughts', data: body);
    final data = res.data;
    if (data == null) {
      throw StateError('Empty create thought response');
    }
    return ThoughtFeedItemDto.fromJson(data);
  }
}
