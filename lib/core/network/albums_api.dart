import 'package:dio/dio.dart';

import 'authenticated_dio.dart';

class AlbumsApi {
  Future<int> createAlbum({
    required String title,
    required List<String> genreSlugs,
    bool isPublic = false,
    bool normalizeGenreWeights = false,
  }) async {
    final dio = await createAuthenticatedDio();
    final res = await dio.post<Map<String, dynamic>>(
      '/albums',
      data: {
        'title': title,
        'genreSlugs': genreSlugs,
        'isPublic': isPublic,
        'normalizeGenreWeights': normalizeGenreWeights,
      },
      options: Options(contentType: Headers.jsonContentType),
    );
    final id = res.data?['id'];
    if (id is num) return id.toInt();
    return 0;
  }
}
