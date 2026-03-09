/// Модель плейлиста. Позже может синхронизироваться с сервером.
class Playlist {
  const Playlist({
    required this.id,
    required this.title,
    this.isPrivate = false,
    this.coverPath,
    this.trackAssetPaths = const [],
  });

  /// Уникальный идентификатор (локальный или серверный).
  final String id;

  /// Название плейлиста.
  final String title;

  /// Приватный (виден только пользователю) или общедоступный.
  final bool isPrivate;

  /// Путь к обложке (asset или локальный файл).
  final String? coverPath;

  /// Идентификаторы треков (assetPath).
  final List<String> trackAssetPaths;

  Playlist copyWith({
    String? id,
    String? title,
    bool? isPrivate,
    String? coverPath,
    List<String>? trackAssetPaths,
  }) {
    return Playlist(
      id: id ?? this.id,
      title: title ?? this.title,
      isPrivate: isPrivate ?? this.isPrivate,
      coverPath: coverPath ?? this.coverPath,
      trackAssetPaths: trackAssetPaths ?? List<String>.from(this.trackAssetPaths),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'isPrivate': isPrivate,
      'coverPath': coverPath,
      'trackAssetPaths': trackAssetPaths,
    };
  }

  static Playlist fromJson(Map<String, dynamic> json) {
    final paths = json['trackAssetPaths'];
    return Playlist(
      id: json['id'] as String,
      title: json['title'] as String,
      isPrivate: (json['isPrivate'] as bool?) ?? false,
      coverPath: json['coverPath'] as String?,
      trackAssetPaths: paths is List ? List<String>.from(paths.map((e) => e.toString())) : const [],
    );
  }
}

