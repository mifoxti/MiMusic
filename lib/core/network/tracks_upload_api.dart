import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import 'authenticated_dio.dart';

class TracksUploadApi {
  /// Ответ [POST /upload/track]: id нового трека для загрузки обложки.
  Future<int> uploadTrackMp3({
    required File file,
    String? title,
    required List<String> genreSlugs,
    bool normalizeGenreWeights = false,
  }) async {
    final dio = await createAuthenticatedDio();
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path, filename: file.uri.pathSegments.isNotEmpty ? file.uri.pathSegments.last : 'track.mp3'),
      if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
      'genreSlugs': jsonEncode(genreSlugs),
      'genreNormalizeWeights': normalizeGenreWeights ? 'true' : 'false',
    });
    final res = await dio.post<Map<String, dynamic>>('/upload/track', data: form);
    final id = (res.data?['trackId'] as num?)?.toInt();
    if (id == null) {
      throw StateError('No trackId in upload response');
    }
    return id;
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
