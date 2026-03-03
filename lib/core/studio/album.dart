/// Модель альбома в студии.
class Album {
  const Album({
    required this.id,
    required this.title,
    this.artist,
    this.coverPath,
    this.trackAssetPaths = const [],
    this.genres = const [],
  });

  final String id;
  final String title;
  final String? artist;
  final String? coverPath;
  final List<String> trackAssetPaths;
  final List<String> genres;

  Album copyWith({
    String? id,
    String? title,
    String? artist,
    String? coverPath,
    List<String>? trackAssetPaths,
    List<String>? genres,
  }) {
    return Album(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      coverPath: coverPath ?? this.coverPath,
      trackAssetPaths: trackAssetPaths ?? List.from(this.trackAssetPaths),
      genres: genres ?? List.from(this.genres),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'coverPath': coverPath,
      'trackAssetPaths': trackAssetPaths,
      'genres': genres,
    };
  }

  static Album fromJson(Map<String, dynamic> json) {
    final paths = json['trackAssetPaths'];
    final genresList = json['genres'];
    return Album(
      id: json['id'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String?,
      coverPath: json['coverPath'] as String?,
      trackAssetPaths: paths is List ? List<String>.from(paths.map((e) => e.toString())) : [],
      genres: genresList is List ? List<String>.from(genresList.map((e) => e.toString())) : [],
    );
  }
}
