/// Модель плейлиста. Позже может синхронизироваться с сервером.
class Playlist {
  const Playlist({
    required this.id,
    required this.title,
    this.isPrivate = false,
    this.coverPath,
    this.trackAssetPaths = const [],
    this.isLiked = false,
    /// С [GET /me/playlists] приходит `trackCount`, а `trackAssetPaths` пустой — для подписи в списке.
    this.remoteTrackCount,
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

  /// Пользователь отметил плейлист «лайком» (избранные чужие / свои в отдельном списке).
  final bool isLiked;

  final int? remoteTrackCount;

  int get displayTrackCount =>
      trackAssetPaths.isNotEmpty ? trackAssetPaths.length : (remoteTrackCount ?? 0);

  Playlist copyWith({
    String? id,
    String? title,
    bool? isPrivate,
    String? coverPath,
    List<String>? trackAssetPaths,
    bool? isLiked,
    int? remoteTrackCount,
  }) {
    return Playlist(
      id: id ?? this.id,
      title: title ?? this.title,
      isPrivate: isPrivate ?? this.isPrivate,
      coverPath: coverPath ?? this.coverPath,
      trackAssetPaths: trackAssetPaths ?? List<String>.from(this.trackAssetPaths),
      isLiked: isLiked ?? this.isLiked,
      remoteTrackCount: remoteTrackCount ?? this.remoteTrackCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'isPrivate': isPrivate,
      'coverPath': coverPath,
      'trackAssetPaths': trackAssetPaths,
      'isLiked': isLiked,
      if (remoteTrackCount != null) 'remoteTrackCount': remoteTrackCount,
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
      isLiked: (json['isLiked'] as bool?) ?? false,
      remoteTrackCount: (json['remoteTrackCount'] as num?)?.toInt(),
    );
  }
}

