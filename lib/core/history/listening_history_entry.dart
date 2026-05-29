import '../audio/track.dart';
import '../network/api_config.dart';
import '../network/tracks_api.dart';

/// Запись истории прослушивания (локально или с [GET /me/listening-history]).
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
    final serverId = TracksApi().parseServerTrackId(p);
    if (serverId != null) {
      final base = ApiConfig.baseUrl.replaceAll(RegExp(r'/+$'), '');
      return Track(
        assetPath: p,
        title: title,
        artist: artist,
        audioFilePath: '$base/tracks/$serverId/stream',
        coverAssetPath: coverAssetPath ?? '$base/tracks/$serverId/cover',
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
