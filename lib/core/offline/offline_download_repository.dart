import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../audio/track.dart';
import '../cache/cache_size.dart';
import '../network/api_config.dart';
import '../network/authenticated_dio.dart';
import '../network/playlists_api.dart';
import '../network/tracks_api.dart';
import '../settings/app_settings.dart';
import '../settings/settings_repository.dart';

enum DownloadTrackResult {
  success,
  alreadyDownloaded,
  inProgress,
  cacheLimitExceeded,
  notServerTrack,
  failed,
}

enum DownloadPlaylistResult {
  success,
  partial,
  cacheLimitExceeded,
  failed,
}

class OfflineTrackRecord {
  const OfflineTrackRecord({
    required this.serverTrackId,
    required this.assetKey,
    required this.title,
    this.artist,
    required this.localFilePath,
    required this.fileSizeBytes,
    required this.downloadedAt,
  });

  final int serverTrackId;
  final String assetKey;
  final String title;
  final String? artist;
  final String localFilePath;
  final int fileSizeBytes;
  final DateTime downloadedAt;

  Map<String, dynamic> toJson() => {
        'serverTrackId': serverTrackId,
        'assetKey': assetKey,
        'title': title,
        'artist': artist,
        'localFilePath': localFilePath,
        'fileSizeBytes': fileSizeBytes,
        'downloadedAt': downloadedAt.toIso8601String(),
      };

  factory OfflineTrackRecord.fromJson(Map<String, dynamic> j) {
    return OfflineTrackRecord(
      serverTrackId: (j['serverTrackId'] as num).toInt(),
      assetKey: j['assetKey'] as String? ?? '',
      title: j['title'] as String? ?? '',
      artist: j['artist'] as String?,
      localFilePath: j['localFilePath'] as String? ?? '',
      fileSizeBytes: (j['fileSizeBytes'] as num?)?.toInt() ?? 0,
      downloadedAt: DateTime.tryParse(j['downloadedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Track toTrack() {
    return Track(
      assetPath: assetKey,
      title: title,
      artist: artist,
      audioFilePath: localFilePath,
      coverAssetPath: ServerTrackListItem(
        id: serverTrackId,
        title: title,
        artist: artist,
      ).coverUrl(),
    );
  }
}

class OfflinePlaylistRecord {
  const OfflinePlaylistRecord({
    required this.playlistId,
    required this.title,
    required this.trackIds,
    required this.downloadedAt,
  });

  final int playlistId;
  final String title;
  final List<int> trackIds;
  final DateTime downloadedAt;

  Map<String, dynamic> toJson() => {
        'playlistId': playlistId,
        'title': title,
        'trackIds': trackIds,
        'downloadedAt': downloadedAt.toIso8601String(),
      };

  factory OfflinePlaylistRecord.fromJson(Map<String, dynamic> j) {
    final raw = j['trackIds'];
    return OfflinePlaylistRecord(
      playlistId: (j['playlistId'] as num).toInt(),
      title: j['title'] as String? ?? '',
      trackIds: raw is List
          ? raw.map((e) => (e as num).toInt()).toList()
          : const [],
      downloadedAt: DateTime.tryParse(j['downloadedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

/// Локальное хранилище скачанных треков и плейлистов.
class OfflineDownloadRepository extends ChangeNotifier {
  OfflineDownloadRepository({required SettingsRepository settingsRepository})
      : _settingsRepository = settingsRepository;

  static const _tracksKey = 'mimusic_offline_tracks_v1';
  static const _playlistsKey = 'mimusic_offline_playlists_v1';

  final SettingsRepository _settingsRepository;
  final Set<String> _downloadingKeys = <String>{};
  List<OfflineTrackRecord> _tracks = const [];
  List<OfflinePlaylistRecord> _playlists = const [];
  bool _loaded = false;

  List<OfflineTrackRecord> get downloadedTracks => List.unmodifiable(_tracks);
  List<OfflinePlaylistRecord> get savedPlaylists => List.unmodifiable(_playlists);
  Set<String> get downloadingKeys => Set.unmodifiable(_downloadingKeys);

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final rawTracks = prefs.getString(_tracksKey);
    if (rawTracks != null) {
      try {
        final list = jsonDecode(rawTracks) as List<dynamic>;
        _tracks = list
            .map((e) => OfflineTrackRecord.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ))
            .where((t) => File(t.localFilePath).existsSync())
            .toList();
      } catch (_) {
        _tracks = const [];
      }
    }
    final rawPlaylists = prefs.getString(_playlistsKey);
    if (rawPlaylists != null) {
      try {
        final list = jsonDecode(rawPlaylists) as List<dynamic>;
        _playlists = list
            .map((e) => OfflinePlaylistRecord.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ))
            .toList();
      } catch (_) {
        _playlists = const [];
      }
    }
    _loaded = true;
    notifyListeners();
  }

  bool isDownloading(String assetKey) =>
      assetKey.isNotEmpty && _downloadingKeys.contains(assetKey);

  bool isDownloaded(String assetKey) {
    if (assetKey.isEmpty) return false;
    return _tracks.any((t) => t.assetKey == assetKey);
  }

  String? localPathForAssetKey(String assetKey) {
    for (final t in _tracks) {
      if (t.assetKey == assetKey && File(t.localFilePath).existsSync()) {
        return t.localFilePath;
      }
    }
    return null;
  }

  int? parseServerTrackId(String assetKey) {
    const prefix = 'server_track_';
    if (!assetKey.startsWith(prefix)) return null;
    return int.tryParse(assetKey.substring(prefix.length));
  }

  Future<int> getOfflineDownloadsSizeBytes() async {
    await ensureLoaded();
    var total = 0;
    for (final t in _tracks) {
      try {
        total += File(t.localFilePath).lengthSync();
      } catch (_) {}
    }
    return total;
  }

  Future<int> getCombinedCacheUsageBytes() async {
    final appCache = await getAppCacheSizeBytes();
    final offline = await getOfflineDownloadsSizeBytes();
    return appCache + offline;
  }

  Future<bool> canStoreBytes(int additionalBytes) async {
    final settings = await _settingsRepository.getSettings();
    final limit = settings.cacheLimitBytes;
    if (limit == AppSettings.cacheLimitUnlimited) return true;
    if (limit <= 0) return false;
    final used = await getCombinedCacheUsageBytes();
    return used + additionalBytes <= limit;
  }

  Future<DownloadTrackResult> downloadTrack(Track track) async {
    await ensureLoaded();
    final assetKey = track.assetPath;
    final serverId = parseServerTrackId(assetKey);
    if (serverId == null) return DownloadTrackResult.notServerTrack;
    if (isDownloaded(assetKey)) return DownloadTrackResult.alreadyDownloaded;
    if (isDownloading(assetKey)) return DownloadTrackResult.inProgress;

    _downloadingKeys.add(assetKey);
    notifyListeners();

    try {
      final dio = await createAuthenticatedDio();
      final base = ApiConfig.baseUrl.replaceAll(RegExp(r'/+$'), '');
      final url = '$base/tracks/$serverId/stream';

      int? contentLength;
      try {
        final head = await dio.head(url);
        final cl = head.headers.value('content-length');
        if (cl != null) contentLength = int.tryParse(cl);
      } catch (_) {}

      if (contentLength != null) {
        final ok = await canStoreBytes(contentLength);
        if (!ok) return DownloadTrackResult.cacheLimitExceeded;
      } else {
        const estimate = 8 * 1024 * 1024;
        final ok = await canStoreBytes(estimate);
        if (!ok) return DownloadTrackResult.cacheLimitExceeded;
      }

      final dir = await _downloadsDirectory();
      final file = File('${dir.path}/track_$serverId.bin');
      await dio.download(url, file.path);

      final size = await file.length();
      final used = await getCombinedCacheUsageBytes();
      final settings = await _settingsRepository.getSettings();
      final limit = settings.cacheLimitBytes;
      if (limit != AppSettings.cacheLimitUnlimited &&
          limit > 0 &&
          used > limit) {
        await file.delete();
        return DownloadTrackResult.cacheLimitExceeded;
      }

      final record = OfflineTrackRecord(
        serverTrackId: serverId,
        assetKey: assetKey,
        title: track.title,
        artist: track.artist,
        localFilePath: file.path,
        fileSizeBytes: size,
        downloadedAt: DateTime.now(),
      );
      _tracks = [..._tracks.where((t) => t.assetKey != assetKey), record];
      await _persistTracks();
      notifyListeners();
      return DownloadTrackResult.success;
    } catch (_) {
      return DownloadTrackResult.failed;
    } finally {
      _downloadingKeys.remove(assetKey);
      notifyListeners();
    }
  }

  Future<DownloadPlaylistResult> downloadPlaylist(int playlistId) async {
    await ensureLoaded();
    try {
      final detail = await PlaylistsApi().fetchPlaylistDetail(playlistId);
      if (detail.tracks.isEmpty) return DownloadPlaylistResult.failed;

      var downloadedAny = false;
      var limitHit = false;
      for (final entry in detail.tracks) {
        final track = Track(
          assetPath: 'server_track_${entry.trackId}',
          title: entry.title ?? '—',
          artist: entry.artist,
          audioFilePath: ServerTrackListItem(
            id: entry.trackId,
            title: entry.title ?? '',
            artist: entry.artist,
          ).streamUrl(),
        );
        final result = await downloadTrack(track);
        if (result == DownloadTrackResult.cacheLimitExceeded) {
          limitHit = true;
          break;
        }
        if (result == DownloadTrackResult.success ||
            result == DownloadTrackResult.alreadyDownloaded) {
          downloadedAny = true;
        }
      }

      if (limitHit) {
        return downloadedAny
            ? DownloadPlaylistResult.partial
            : DownloadPlaylistResult.cacheLimitExceeded;
      }

      final allSaved = detail.tracks.every(
        (t) => isDownloaded('server_track_${t.trackId}'),
      );
      if (allSaved) {
        final record = OfflinePlaylistRecord(
          playlistId: playlistId,
          title: detail.title?.trim().isEmpty ?? true
              ? 'Плейлист #$playlistId'
              : detail.title!.trim(),
          trackIds: detail.tracks.map((t) => t.trackId).toList(),
          downloadedAt: DateTime.now(),
        );
        _playlists = [
          ..._playlists.where((p) => p.playlistId != playlistId),
          record,
        ];
        await _persistPlaylists();
        notifyListeners();
        return DownloadPlaylistResult.success;
      }
      return downloadedAny
          ? DownloadPlaylistResult.partial
          : DownloadPlaylistResult.failed;
    } catch (_) {
      return DownloadPlaylistResult.failed;
    }
  }

  Future<void> removeTrack(String assetKey) async {
    await ensureLoaded();
    final existing = _tracks.where((t) => t.assetKey == assetKey).toList();
    if (existing.isEmpty) return;
    for (final t in existing) {
      try {
        final f = File(t.localFilePath);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
    _tracks = _tracks.where((t) => t.assetKey != assetKey).toList();
    _playlists = _playlists
        .where((p) => p.trackIds.every(
              (id) => isDownloaded('server_track_$id'),
            ))
        .toList();
    await _persistTracks();
    await _persistPlaylists();
    notifyListeners();
  }

  Future<void> removePlaylist(int playlistId) async {
    await ensureLoaded();
    _playlists = _playlists.where((p) => p.playlistId != playlistId).toList();
    await _persistPlaylists();
    notifyListeners();
  }

  bool isPlaylistFullySaved(int playlistId) {
    return _playlists.any((p) => p.playlistId == playlistId);
  }

  Future<Directory> _downloadsDirectory() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/mimusic_downloads');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> _persistTracks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _tracksKey,
      jsonEncode(_tracks.map((t) => t.toJson()).toList()),
    );
  }

  Future<void> _persistPlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _playlistsKey,
      jsonEncode(_playlists.map((p) => p.toJson()).toList()),
    );
  }
}
