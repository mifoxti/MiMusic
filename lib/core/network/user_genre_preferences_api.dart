import 'package:dio/dio.dart';

import 'authenticated_dio.dart';

class GenrePreferenceDto {
  const GenrePreferenceDto({required this.slug, required this.weight});

  final String slug;
  final double weight;

  static GenrePreferenceDto fromJson(Map<String, dynamic> json) {
    return GenrePreferenceDto(
      slug: json['slug'] as String? ?? '',
      weight: (json['weight'] as num?)?.toDouble() ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {'slug': slug, 'weight': weight};
}

class UserGenrePreferencesApi {
  Future<List<GenrePreferenceDto>> fetchPreferences() async {
    final dio = await createAuthenticatedDio();
    final res = await dio.get<List<dynamic>>('/me/genre-preferences');
    final data = res.data;
    if (data == null) return [];
    return data
        .map((e) => GenrePreferenceDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> savePreferences(List<GenrePreferenceDto> preferences) async {
    final dio = await createAuthenticatedDio();
    await dio.put<void>(
      '/me/genre-preferences',
      data: {
        'preferences': preferences.map((e) => e.toJson()).toList(),
      },
      options: Options(contentType: Headers.jsonContentType),
    );
  }
}
