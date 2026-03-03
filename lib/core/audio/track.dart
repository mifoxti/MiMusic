import 'dart:typed_data';

/// Модель трека для воспроизведения. Поддерживает asset-путь, файл и метаданные.
class Track {
  const Track({
    required this.assetPath,
    required this.title,
    this.artist,
    this.coverBytes,
    this.coverAssetPath,
    this.audioFilePath,
  });

  /// Идентификатор / путь к аудио в assets (например assets/music/track.mp3).
  final String assetPath;

  /// Путь к аудиофайлу на диске (если трек загружен из студии). При воспроизведении приоритет над [assetPath].
  final String? audioFilePath;

  /// Название трека.
  final String title;

  /// Автор(ы). Может быть null, если не удалось извлечь.
  final String? artist;

  /// Обложка из ID3 (байты). Приоритет над [coverAssetPath].
  final Uint8List? coverBytes;

  /// Запасной путь к обложке в assets, если ID3 не содержит картинку.
  final String? coverAssetPath;

  /// Отображаемое имя автора (или пустая строка).
  String get artistDisplay => artist ?? '';

  /// Путь к обложке: либо из coverBytes (через MemoryImage), либо coverAssetPath.
  /// Для виджетов: coverBytes != null → MemoryImage, иначе coverAssetPath.
  String? get coverFallbackPath => coverAssetPath;
}
