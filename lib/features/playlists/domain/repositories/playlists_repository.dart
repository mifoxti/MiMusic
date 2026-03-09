import '../entities/playlist.dart';

/// Контракт репозитория плейлистов.
///
/// Сейчас реализован локально через SharedPreferences, позже можно
/// добавить реализацию поверх REST / gRPC и подменять её через DI.
abstract interface class PlaylistsRepository {
  Future<List<Playlist>> getPlaylists();

  Future<Playlist?> getPlaylist(String id);

  /// Создаёт или обновляет плейлист.
  Future<Playlist> savePlaylist(Playlist playlist);

  Future<void> deletePlaylist(String id);
}

