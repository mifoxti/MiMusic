import 'track.dart';

/// Временное решение: извлечение метаданных из локальных треков по имени файла.
/// Формат: "Artist - Title.mp3" → artist и title; иначе весь baseName — title.
/// Когда будет сервер, метаданные (включая обложку) придут из API.
class TrackMetadataLoader {
  TrackMetadataLoader._();
  static final TrackMetadataLoader instance = TrackMetadataLoader._();

  /// Загружает трек из asset и извлекает метаданные по имени файла.
  /// [assetPath] — например assets/music/Gotarux - Lost Control.mp3
  Future<Track> loadFromAsset(String assetPath) async {
    final fileName = assetPath.split('/').last;
    final baseName = fileName.replaceAll(
      RegExp(r'\.(mp3|m4a|flac|ogg|wav)$', caseSensitive: false),
      '',
    );

    final dash = baseName.indexOf(' - ');
    final (artist, title) = dash >= 0
        ? (baseName.substring(0, dash).trim(), baseName.substring(dash + 3).trim())
        : (null, baseName);

    return Track(
      assetPath: assetPath,
      title: title,
      artist: artist,
      coverAssetPath: null,
    );
  }
}
