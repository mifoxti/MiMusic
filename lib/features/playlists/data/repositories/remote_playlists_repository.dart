import 'dart:io';

import '../../../../core/network/playlists_api.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/repositories/playlists_repository.dart';

/// Плейлисты с API Ktor. Идентификаторы в домене: `srv:<числовой id>`.
class RemotePlaylistsRepository implements PlaylistsRepository {
  RemotePlaylistsRepository({PlaylistsApi? api}) : _api = api ?? PlaylistsApi();

  final PlaylistsApi _api;

  static String idForServer(int id) => 'srv:$id';

  Playlist _fromListItem(MyPlaylistListItemRemote e, {required bool liked}) {
    final sid = e.id;
    final hasCover = e.coverStorageKey != null && e.coverStorageKey!.trim().isNotEmpty;
    return Playlist(
      id: idForServer(sid),
      title: (e.title ?? '').trim().isEmpty ? '—' : e.title!.trim(),
      isPrivate: !(e.isPublic ?? false),
      coverPath: hasCover ? playlistCoverUrl(sid) : null,
      trackAssetPaths: const [],
      isLiked: liked,
      remoteTrackCount: e.trackCount,
    );
  }

  Future<bool> _fetchLikedSafe(int playlistId) async {
    try {
      final s = await _api.getPlaylistLike(playlistId);
      return s.liked;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<Playlist>> getPlaylists() async {
    final rows = await _api.fetchMyPlaylists();
    final out = <Playlist>[];
    for (final e in rows) {
      final liked = e.isPublic == true ? await _fetchLikedSafe(e.id) : false;
      out.add(_fromListItem(e, liked: liked));
    }
    return out;
  }

  @override
  Future<Playlist?> getPlaylist(String id) async {
    final sid = parseServerPlaylistId(id);
    if (sid == null) return null;
    try {
      final d = await _api.fetchPlaylistDetail(sid);
      final liked = d.isPublic ? await _fetchLikedSafe(sid) : false;
      final paths = d.tracks.map((t) => 'server_track_${t.trackId}').toList();
      return Playlist(
        id: idForServer(sid),
        title: (d.title ?? '').trim().isEmpty ? '—' : d.title!.trim(),
        isPrivate: !d.isPublic,
        coverPath: playlistCoverUrl(sid),
        trackAssetPaths: paths,
        isLiked: liked,
        remoteTrackCount: paths.length,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Playlist> savePlaylist(Playlist playlist) async {
    final sid = parseServerPlaylistId(playlist.id);
    final localCover = playlist.coverPath != null &&
        playlist.coverPath!.isNotEmpty &&
        !playlist.coverPath!.startsWith('http://') &&
        !playlist.coverPath!.startsWith('https://') &&
        !playlist.coverPath!.startsWith('assets/');

    if (sid == null) {
      final createdId = await _api.createPlaylist(
        title: playlist.title,
        isPublic: !playlist.isPrivate,
      );
      if (localCover) {
        final f = File(playlist.coverPath!);
        if (await f.exists()) {
          await _api.uploadPlaylistCover(createdId, f);
        }
      }
      final trackIds = _parseServerTrackIds(playlist.trackAssetPaths);
      if (trackIds.isNotEmpty) {
        await _api.setPlaylistTracks(createdId, trackIds);
      }
      final liked = !playlist.isPrivate ? await _fetchLikedSafe(createdId) : false;
      return Playlist(
        id: idForServer(createdId),
        title: playlist.title,
        isPrivate: playlist.isPrivate,
        coverPath: playlistCoverUrl(createdId),
        trackAssetPaths: playlist.trackAssetPaths,
        isLiked: liked,
        remoteTrackCount: playlist.trackAssetPaths.length,
      );
    }

    await _api.updatePlaylist(
      sid,
      title: playlist.title,
      isPublic: !playlist.isPrivate,
    );
    if (localCover) {
      final f = File(playlist.coverPath!);
      if (await f.exists()) {
        await _api.uploadPlaylistCover(sid, f);
      }
    }
    final incomingTrackIds = _parseServerTrackIds(playlist.trackAssetPaths);
    if (incomingTrackIds.isNotEmpty) {
      await _api.setPlaylistTracks(sid, incomingTrackIds);
    }

    if (!playlist.isPrivate) {
      try {
        final cur = await _api.getPlaylistLike(sid);
        if (cur.liked != playlist.isLiked) {
          await _api.postPlaylistLike(sid);
        }
      } catch (_) {}
    }

    return playlist.copyWith(
      coverPath: playlistCoverUrl(sid),
    );
  }

  List<int> _parseServerTrackIds(List<String> paths) {
    final out = <int>[];
    for (final p in paths) {
      if (p.startsWith('server_track_')) {
        final id = int.tryParse(p.replaceFirst('server_track_', ''));
        if (id != null) out.add(id);
      }
    }
    return out;
  }

  @override
  Future<void> deletePlaylist(String id) async {
    final sid = parseServerPlaylistId(id);
    if (sid == null) return;
    await _api.deletePlaylist(sid);
  }
}
