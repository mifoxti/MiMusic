import 'package:dio/dio.dart';

import 'api_config.dart';

class GenreDto {
  const GenreDto({
    required this.id,
    required this.slug,
    required this.displayName,
  });

  final int id;
  final String slug;
  final String displayName;

  static GenreDto fromJson(Map<String, dynamic> json) {
    return GenreDto(
      id: (json['id'] as num).toInt(),
      slug: json['slug'] as String? ?? '',
      displayName: json['displayName'] as String? ?? json['display_name'] as String? ?? '',
    );
  }
}

class GenresApi {
  GenresApi({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: ApiConfig.baseUrl.replaceAll(RegExp(r'/+$'), ''),
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 20),
              ),
            );

  final Dio _dio;

  Future<List<GenreDto>> fetchGenres() async {
    final res = await _dio.get<List<dynamic>>('/genres');
    final data = res.data;
    if (data == null) return [];
    return data
        .map((e) => GenreDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}
