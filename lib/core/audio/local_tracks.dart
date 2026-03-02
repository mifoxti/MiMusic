import 'track.dart';
import 'track_metadata_loader.dart';

/// Список локальных треков в assets. Временное решение — при подключении сервера заменить на API.
const List<String> localTrackAssets = [
  'assets/music/Gotarux - Lost Control.mp3',
  'assets/music/Cartoon - Why We Lose - Cartoon.mp3',
  'assets/music/Urbandawn - Fly Away.mp3',
];

/// Загружает все локальные треки с метаданными.
Future<List<Track>> loadLocalTracks() async {
  final loader = TrackMetadataLoader.instance;
  final tracks = <Track>[];
  for (final assetPath in localTrackAssets) {
    try {
      final track = await loader.loadFromAsset(assetPath);
      tracks.add(track);
    } catch (_) {
      // Пропускаем треки с ошибками
    }
  }
  return tracks;
}
