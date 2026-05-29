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
    this.likesCount = 0,
    this.likedByMe = false,
    this.commentsCount = 0,
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
  final int likesCount;
  final bool likedByMe;
  final int commentsCount;

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
      likesCount: (j['likesCount'] as num?)?.toInt() ?? 0,
      likedByMe: j['likedByMe'] as bool? ?? false,
      commentsCount: (j['commentsCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class ThoughtCommentDto {
  const ThoughtCommentDto({
    required this.id,
    required this.authorUserId,
    required this.authorNickname,
    this.bodyText,
    this.createdAt,
  });

  final int id;
  final int authorUserId;
  final String authorNickname;
  final String? bodyText;
  final String? createdAt;

  factory ThoughtCommentDto.fromJson(Map<String, dynamic> j) {
    return ThoughtCommentDto(
      id: (j['id'] as num).toInt(),
      authorUserId: (j['authorUserId'] as num).toInt(),
      authorNickname: j['authorNickname'] as String? ?? '',
      bodyText: j['bodyText'] as String?,
      createdAt: j['createdAt'] as String?,
    );
  }
}

class ThoughtLikeResult {
  const ThoughtLikeResult({required this.liked, required this.likesCount});

  final bool liked;
  final int likesCount;

  factory ThoughtLikeResult.fromJson(Map<String, dynamic> j) {
    return ThoughtLikeResult(
      liked: j['status'] as bool? ?? false,
      likesCount: (j['likesCount'] as num?)?.toInt() ?? 0,
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

  Future<Dio> _authDio() => createAuthenticatedDio();

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
    final dio = await _authDio();
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
    final dio = await _authDio();
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
    final dio = await _authDio();
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

  Future<ThoughtLikeResult> toggleThoughtLike(int thoughtId) async {
    final dio = await _authDio();
    final res = await dio.post<Map<String, dynamic>>('/thoughts/$thoughtId/like');
    final data = res.data;
    if (data == null) {
      throw StateError('Empty like response');
    }
    return ThoughtLikeResult.fromJson(data);
  }

  Future<List<ThoughtCommentDto>> fetchThoughtComments(int thoughtId) async {
    final dio = await _authDio();
    final res = await dio.get<List<dynamic>>('/thoughts/$thoughtId/comments');
    final data = res.data;
    if (data == null) return [];
    return data
        .map((e) => ThoughtCommentDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<ThoughtFeedItemDto> updateThought({
    required int thoughtId,
    required String bodyText,
    required int attachmentType,
    int? attachmentTrackId,
    int? attachmentPlaylistId,
  }) async {
    final dio = await _authDio();
    final body = <String, dynamic>{
      'bodyText': bodyText,
      'attachmentType': attachmentType,
      if (attachmentTrackId != null) 'attachmentTrackId': attachmentTrackId,
      if (attachmentPlaylistId != null) 'attachmentPlaylistId': attachmentPlaylistId,
    };
    final res = await dio.put<Map<String, dynamic>>(
      '/thoughts/$thoughtId',
      data: body,
    );
    final data = res.data;
    if (data == null) {
      throw StateError('Empty update thought response');
    }
    return ThoughtFeedItemDto.fromJson(data);
  }

  Future<void> deleteThought(int thoughtId) async {
    final dio = await _authDio();
    await dio.delete<void>('/thoughts/$thoughtId');
  }

  Future<ThoughtCommentDto> postThoughtComment({
    required int thoughtId,
    required String bodyText,
  }) async {
    final dio = await _authDio();
    final res = await dio.post<Map<String, dynamic>>(
      '/thoughts/$thoughtId/comments',
      data: {'bodyText': bodyText},
    );
    final data = res.data;
    if (data == null) {
      throw StateError('Empty comment response');
    }
    return ThoughtCommentDto.fromJson(data);
  }

  Future<ThoughtCommentDto> updateThoughtComment({
    required int thoughtId,
    required int commentId,
    required String bodyText,
  }) async {
    final dio = await _authDio();
    final res = await dio.put<Map<String, dynamic>>(
      '/thoughts/$thoughtId/comments/$commentId',
      data: {'bodyText': bodyText},
    );
    final data = res.data;
    if (data == null) {
      throw StateError('Empty comment update response');
    }
    return ThoughtCommentDto.fromJson(data);
  }

  Future<void> deleteThoughtComment({
    required int thoughtId,
    required int commentId,
  }) async {
    final dio = await _authDio();
    await dio.delete<void>('/thoughts/$thoughtId/comments/$commentId');
  }
}
