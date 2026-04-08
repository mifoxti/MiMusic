import '../audio/local_tracks.dart';
import 'listening_history_entry.dart';
import 'listening_history_repository.dart';

/// Хранение истории в оперативной памяти процесса (мок до сервера).
/// При старте можно заполнить демо-записями из локальных asset-треков.
class InMemoryListeningHistoryRepository extends ListeningHistoryRepository {
  InMemoryListeningHistoryRepository({this.seedWithLocalAssetDemo = true}) {
    if (seedWithLocalAssetDemo) {
      _seedFromLocalAssets();
    }
  }

  /// Добавить несколько записей по именам файлов из [localTrackAssets].
  final bool seedWithLocalAssetDemo;

  static const int _maxEntries = 200;

  final List<ListeningHistoryEntry> _entries = [];

  @override
  List<ListeningHistoryEntry> get entries => List.unmodifiable(_entries);

  @override
  void recordPlayback({
    required String playablePath,
    required String title,
    String? artist,
    String? coverAssetPath,
    DateTime? playedAt,
  }) {
    if (playablePath.isEmpty) return;
    _entries.removeWhere((e) => e.playablePath == playablePath);
    _entries.insert(
      0,
      ListeningHistoryEntry(
        playablePath: playablePath,
        title: title,
        artist: artist,
        coverAssetPath: coverAssetPath,
        playedAt: playedAt ?? DateTime.now(),
      ),
    );
    while (_entries.length > _maxEntries) {
      _entries.removeLast();
    }
    notifyListeners();
  }

  @override
  void clear() {
    _entries.clear();
    notifyListeners();
  }

  void _seedFromLocalAssets() {
    for (var i = 0; i < localTrackAssets.length; i++) {
      final assetPath = localTrackAssets[i];
      final parsed = _parseAssetFileName(assetPath);
      _entries.add(
        ListeningHistoryEntry(
          playablePath: assetPath,
          title: parsed.$2,
          artist: parsed.$1,
          coverAssetPath: 'assets/images/geoxor.png',
          playedAt: DateTime.now().subtract(Duration(hours: i * 3 + 1)),
        ),
      );
    }
  }

  /// Как [TrackMetadataLoader]: `Artist - Title.mp3`.
  (String?, String) _parseAssetFileName(String assetPath) {
    final fileName = assetPath.split('/').last;
    final baseName = fileName.replaceAll(
      RegExp(r'\.(mp3|m4a|flac|ogg|wav)$', caseSensitive: false),
      '',
    );
    final dash = baseName.indexOf(' - ');
    if (dash >= 0) {
      return (
        baseName.substring(0, dash).trim(),
        baseName.substring(dash + 3).trim(),
      );
    }
    return (null, baseName);
  }
}
