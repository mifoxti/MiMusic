import 'track.dart';
import 'track_metadata_loader.dart';
import '../studio/local_studio_repository.dart';

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

  try {
    final studioRepo = LocalStudioRepository();
    final customPaths = await studioRepo.getCustomTrackPaths();
    final overrides = await studioRepo.getTrackMetadataOverrides();
    for (final customId in customPaths) {
      final override = overrides[customId];
      final audioPath = override?.audioFilePath;
      if (audioPath == null || audioPath.trim().isEmpty) continue;
      final baseName = audioPath.split(RegExp(r'[/\\]')).last;
      final cleanName = baseName.replaceAll(
        RegExp(r'\.(mp3|m4a|flac|ogg|wav)$', caseSensitive: false),
        '',
      );
      tracks.add(
        Track(
          assetPath: customId,
          title: (override?.title?.trim().isNotEmpty ?? false)
              ? override!.title!.trim()
              : cleanName,
          artist: (override?.displayArtist.trim().isNotEmpty ?? false)
              ? override!.displayArtist.trim()
              : override?.artist,
          coverAssetPath: override?.coverPath ?? 'assets/images/geoxor.png',
          audioFilePath: audioPath,
        ),
      );
    }
  } catch (_) {
    // ignore studio data errors and keep bundled tracks available
  }
  return tracks;
}
