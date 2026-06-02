import 'track.dart';
import 'track_metadata_loader.dart';
import '../studio/local_studio_repository.dart';

/// Встроенные MP3 в APK отключены — только пользовательские файлы из студии.
const List<String> localTrackAssets = <String>[];

/// Загружает локальные треки (студия / пользовательские файлы на устройстве).
Future<List<Track>> loadLocalTracks() async {
  final tracks = <Track>[];
  final loader = TrackMetadataLoader.instance;
  for (final assetPath in localTrackAssets) {
    try {
      final track = await loader.loadFromAsset(assetPath);
      tracks.add(track);
    } catch (_) {}
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
  } catch (_) {}

  return tracks;
}
