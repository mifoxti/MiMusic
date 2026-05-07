import 'album.dart';

/// Метаданные трека для переопределения (редактирование в студии).
class TrackMetadataOverride {
  const TrackMetadataOverride({
    this.title,
    this.artist,
    this.coverPath,
    this.genres = const [],
    this.audioFilePath,
    this.coAuthors = const [],
    this.serverTrackId,
  });

  final String? title;
  final String? artist;
  final String? coverPath;
  final List<String> genres;

  /// Путь к загруженному аудиофайлу на диске (копия из выбора в студии).
  final String? audioFilePath;

  /// Id трека на сервере после [POST /upload/track], для удаления с сервера из студии.
  final int? serverTrackId;

  /// Соавторы трека (дополнительные имена к основному [artist]).
  final List<String> coAuthors;

  /// Строка для отображения: исполнитель и соавторы через запятую.
  String get displayArtist {
    final parts = <String>[];
    if (artist != null && artist!.isNotEmpty) parts.add(artist!);
    parts.addAll(coAuthors.where((a) => a.isNotEmpty));
    return parts.join(', ');
  }

  Map<String, dynamic> toJson() => {
        if (title != null) 'title': title,
        if (artist != null) 'artist': artist,
        if (coverPath != null) 'coverPath': coverPath,
        if (genres.isNotEmpty) 'genres': genres,
        if (audioFilePath != null) 'audioFilePath': audioFilePath,
        if (coAuthors.isNotEmpty) 'coAuthors': coAuthors,
        if (serverTrackId != null) 'serverTrackId': serverTrackId,
      };

  static TrackMetadataOverride fromJson(Map<String, dynamic> json) {
    final g = json['genres'];
    final co = json['coAuthors'];
    final sid = json['serverTrackId'];
    return TrackMetadataOverride(
      title: json['title'] as String?,
      artist: json['artist'] as String?,
      coverPath: json['coverPath'] as String?,
      genres: g is List ? List<String>.from(g.map((e) => e.toString())) : [],
      audioFilePath: json['audioFilePath'] as String?,
      coAuthors: co is List ? List<String>.from(co.map((e) => e.toString())) : [],
      serverTrackId: sid is int ? sid : (sid is num ? sid.toInt() : null),
    );
  }
}

/// Репозиторий данных студии: альбомы и переопределения метаданных треков.
abstract class StudioRepository {
  Future<List<Album>> getAlbums();
  Future<void> saveAlbums(List<Album> albums);

  Future<Map<String, TrackMetadataOverride>> getTrackMetadataOverrides();
  Future<void> saveTrackMetadataOverride(String assetPath, TrackMetadataOverride? override);

  /// Пути треков, добавленных вручную (не из localTrackAssets).
  Future<List<String>> getCustomTrackPaths();
  Future<void> saveCustomTrackPaths(List<String> paths);
}
