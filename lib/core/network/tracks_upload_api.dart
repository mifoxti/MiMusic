import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import 'authenticated_dio.dart';

class TracksUploadApi {
  Future<void> uploadTrackMp3({
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
    await dio.post<void>('/upload/track', data: form);
  }
}
