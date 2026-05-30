import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'authenticated_dio.dart';

/// Ответ [POST /upload/track]: вход mp3/wav/m4a, сервер конвертирует в AAC `.m4a`; опционально обложка.
class UploadTrackResult {
  const UploadTrackResult({
    required this.trackId,
    required this.title,
    this.artist,
    this.coverStorageKey,
    this.embeddedCoverApplied = false,
    this.customCoverApplied = false,
  });

  final int trackId;
  final String title;
  final String? artist;
  final String? coverStorageKey;
  final bool embeddedCoverApplied;
  final bool customCoverApplied;

  factory UploadTrackResult.fromJson(Map<String, dynamic> json) {
    final id = json['trackId'];
    return UploadTrackResult(
      trackId: id is int ? id : (id as num).toInt(),
      title: json['title'] as String? ?? '',
      artist: json['artist'] as String?,
      coverStorageKey: json['coverStorageKey'] as String?,
      embeddedCoverApplied: json['embeddedCoverApplied'] as bool? ?? false,
      customCoverApplied: json['customCoverApplied'] as bool? ?? false,
    );
  }
}

/// Человекочитаемая причина ошибки загрузки (тело ответа Ktor или сеть).
String tracksUploadErrorDetail(Object error) {
  if (error is DioException) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return 'Таймаут при отправке файла — проверьте сеть или попробуйте позже';
    }
    if (error.type == DioExceptionType.receiveTimeout) {
      return 'Сервер долго обрабатывает файл (конвертация) — попробуйте ещё раз';
    }
    if (error.type == DioExceptionType.connectionError) {
      return 'Нет связи с сервером';
    }
    final data = error.response?.data;
    if (data is String && data.trim().isNotEmpty) {
      final t = data.trim();
      return t.length > 220 ? '${t.substring(0, 217)}…' : t;
    }
    if (data is Map) {
      final msg = data['message'] ?? data['error'];
      if (msg is String && msg.trim().isNotEmpty) return msg.trim();
    }
    final code = error.response?.statusCode;
    if (code == 401) return 'Сессия истекла — войдите снова';
    if (code == 503) return 'На сервере недоступна конвертация (ffmpeg)';
    if (code != null) return 'HTTP $code';
  }
  return error.toString();
}

Map<String, dynamic> _parseUploadResponseData(dynamic data) {
  if (data is Map<String, dynamic>) return data;
  if (data is Map) return Map<String, dynamic>.from(data);
  if (data is String && data.trim().isNotEmpty) {
    return jsonDecode(data) as Map<String, dynamic>;
  }
  throw StateError('Empty or invalid upload response');
}

Future<Dio> _dioForTrackUpload() async {
  final dio = await createAuthenticatedDio();
  dio.options.connectTimeout = const Duration(seconds: 30);
  dio.options.sendTimeout = const Duration(minutes: 10);
  dio.options.receiveTimeout = const Duration(minutes: 10);
  return dio;
}

class TracksUploadApi {
  /// [GET /tracks/{id}/cover] с авторизацией — для предпросмотра после загрузки MP3.
  static Future<Uint8List?> fetchTrackCoverBytes(int trackId) async {
    final dio = await createAuthenticatedDio();
    try {
      final res = await dio.get<dynamic>(
        '/tracks/$trackId/cover',
        options: Options(responseType: ResponseType.bytes),
      );
      final data = res.data;
      if (data == null) return null;
      if (data is Uint8List) return data.isEmpty ? null : data;
      if (data is List<int>) return data.isEmpty ? null : Uint8List.fromList(data);
      return null;
    } catch (_) {
      return null;
    }
  }

  /// [PUT /tracks/{id}/genres] — после выбора жанров на последнем шаге мастера.
  Future<void> putTrackGenres({
    required int trackId,
    required List<String> genreSlugs,
    bool normalizeWeights = false,
  }) async {
    final dio = await createAuthenticatedDio();
    await dio.put<void>(
      '/tracks/$trackId/genres',
      data: <String, dynamic>{
        'genreSlugs': genreSlugs,
        'normalizeWeights': normalizeWeights,
      },
    );
  }

  /// Одна загрузка: аудио (mp3/wav/m4a), поля `title`/`artist`, жанры; опционально обложка `cover`.
  Future<UploadTrackResult> uploadTrack({
    required File audioFile,
    String? title,
    String? artist,
    File? coverFile,
    required List<String> genreSlugs,
    bool normalizeGenreWeights = false,
  }) async {
    final dio = await _dioForTrackUpload();
    final audioPath = audioFile.path;
    final map = <String, dynamic>{
      'file': await MultipartFile.fromFile(
        audioPath,
        filename: audioFile.uri.pathSegments.isNotEmpty
            ? audioFile.uri.pathSegments.last
            : 'track.m4a',
      ),
      'genreSlugs': jsonEncode(genreSlugs),
      'genreNormalizeWeights': normalizeGenreWeights ? 'true' : 'false',
    };
    if (title != null && title.trim().isNotEmpty) {
      map['title'] = title.trim();
    }
    if (artist != null && artist.trim().isNotEmpty) {
      map['artist'] = artist.trim();
    }
    if (coverFile != null) {
      final coverPath = coverFile.path;
      map['cover'] = await MultipartFile.fromFile(
        coverPath,
        filename: coverFile.uri.pathSegments.isNotEmpty
            ? coverFile.uri.pathSegments.last
            : 'cover.jpg',
      );
    }
    final form = FormData.fromMap(map);
    if (kDebugMode) {
      debugPrint('TracksUploadApi: POST /upload/track file=$audioPath');
    }
    final res = await dio.post<dynamic>('/upload/track', data: form);
    return UploadTrackResult.fromJson(_parseUploadResponseData(res.data));
  }

  Future<void> uploadTrackCover({
    required int trackId,
    required File imageFile,
  }) async {
    final dio = await _dioForTrackUpload();
    final coverPath = imageFile.path;
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        coverPath,
        filename: imageFile.uri.pathSegments.isNotEmpty
            ? imageFile.uri.pathSegments.last
            : 'cover.jpg',
      ),
    });
    await dio.post<void>('/upload/tracks/$trackId/cover', data: form);
  }
}
