import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

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
  /// Сервер конвертирует в AAC; встроенная обложка — best-effort из исходного MP3.
  Future<UploadTrackResult> uploadTrack({
    required File audioFile,
    String? title,
    String? artist,
    File? coverFile,
    required List<String> genreSlugs,
    bool normalizeGenreWeights = false,
  }) async {
    final dio = await createAuthenticatedDio();
    final map = <String, dynamic>{
      'file': await MultipartFile.fromFile(
        audioFile.path,
        filename: audioFile.uri.pathSegments.isNotEmpty ? audioFile.uri.pathSegments.last : 'track.m4a',
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
      map['cover'] = await MultipartFile.fromFile(
        coverFile.path,
        filename: coverFile.uri.pathSegments.isNotEmpty ? coverFile.uri.pathSegments.last : 'cover.png',
      );
    }
    final form = FormData.fromMap(map);
    final res = await dio.post<Map<String, dynamic>>('/upload/track', data: form);
    final data = res.data;
    if (data == null) {
      throw StateError('Empty upload response');
    }
    return UploadTrackResult.fromJson(data);
  }

  Future<void> uploadTrackCover({
    required int trackId,
    required File imageFile,
  }) async {
    final dio = await createAuthenticatedDio();
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        imageFile.path,
        filename: imageFile.uri.pathSegments.isNotEmpty ? imageFile.uri.pathSegments.last : 'cover.png',
      ),
    });
    await dio.post<void>('/upload/tracks/$trackId/cover', data: form);
  }
}
