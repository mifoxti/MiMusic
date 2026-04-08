import '../audio/track.dart';

/// Запись истории прослушивания. Позже можно маппить с DTO сервера.
class ListeningHistoryEntry {
  const ListeningHistoryEntry({
    required this.playablePath,
    required this.title,
    this.artist,
    this.coverAssetPath,
    required this.playedAt,
  });

  /// Путь воспроизведения: `assets/...` или путь к файлу (студия).
  final String playablePath;
  final String title;
  final String? artist;
  final String? coverAssetPath;
  final DateTime playedAt;

  String get artistDisplay => artist ?? '';

  /// Собрать [Track] для [AudioPlayerService.playTrack].
  Track toTrack() {
    final p = playablePath;
    if (p.startsWith('assets/')) {
      return Track(
        assetPath: p,
        title: title,
        artist: artist,
        coverAssetPath: coverAssetPath,
      );
    }
    return Track(
      assetPath: '',
      title: title,
      artist: artist,
      coverAssetPath: coverAssetPath,
      audioFilePath: p,
    );
  }
}
