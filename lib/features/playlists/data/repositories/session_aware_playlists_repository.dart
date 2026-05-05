import '../../../../core/auth/auth_session_store.dart';
import '../../../../core/network/playlists_api.dart' show parseServerPlaylistId;
import '../../domain/entities/playlist.dart';
import '../../domain/repositories/playlists_repository.dart';
import 'local_playlists_repository.dart';
import 'remote_playlists_repository.dart';

/// С серверной сессией — [RemotePlaylistsRepository], иначе локальный кэш.
class SessionAwarePlaylistsRepository implements PlaylistsRepository {
  SessionAwarePlaylistsRepository({
    RemotePlaylistsRepository? remote,
    LocalPlaylistsRepository? local,
  })  : _remote = remote ?? RemotePlaylistsRepository(),
        _local = local ?? LocalPlaylistsRepository();

  final RemotePlaylistsRepository _remote;
  final LocalPlaylistsRepository _local;

  Future<PlaylistsRepository> _active() async {
    final acc = await AuthSessionStore.readAccount();
    if (acc != null &&
        acc.sessionToken.trim().isNotEmpty &&
        acc.userId != null) {
      return _remote;
    }
    return _local;
  }

  Future<bool> get hasRemoteSession async {
    final acc = await AuthSessionStore.readAccount();
    return acc != null &&
        acc.sessionToken.trim().isNotEmpty &&
        acc.userId != null;
  }

  @override
  Future<List<Playlist>> getPlaylists() => _active().then((r) => r.getPlaylists());

  @override
  Future<Playlist?> getPlaylist(String id) async {
    if (parseServerPlaylistId(id) != null) {
      return _remote.getPlaylist(id);
    }
    return (await _active()).getPlaylist(id);
  }

  @override
  Future<Playlist> savePlaylist(Playlist playlist) async {
    if (parseServerPlaylistId(playlist.id) != null) {
      return _remote.savePlaylist(playlist);
    }
    return (await _active()).savePlaylist(playlist);
  }

  @override
  Future<void> deletePlaylist(String id) async {
    if (parseServerPlaylistId(id) != null) {
      await _remote.deletePlaylist(id);
      return;
    }
    return (await _active()).deletePlaylist(id);
  }
}
