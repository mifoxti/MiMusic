import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/playlist.dart';
import '../../domain/repositories/playlists_repository.dart';

const String _keyPlaylists = 'mimusic_playlists';

/// Локальный репозиторий плейлистов на основе SharedPreferences.
///
/// Структура хранения:
///   key: [_keyPlaylists]
///   value: JSON-список плейлистов (см. [Playlist.toJson]).
class LocalPlaylistsRepository implements PlaylistsRepository {
  LocalPlaylistsRepository([SharedPreferences? prefs]) : _prefs = prefs;

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _instance async =>
      _prefs ??= await SharedPreferences.getInstance();

  @override
  Future<List<Playlist>> getPlaylists() async {
    final prefs = await _instance;
    final jsonStr = prefs.getString(_keyPlaylists);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list
          .map((e) => Playlist.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<Playlist?> getPlaylist(String id) async {
    final all = await getPlaylists();
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  Future<Playlist> savePlaylist(Playlist playlist) async {
    final prefs = await _instance;
    final all = await getPlaylists();
    final updated = <Playlist>[];
    var found = false;
    for (final p in all) {
      if (p.id == playlist.id) {
        updated.add(playlist);
        found = true;
      } else {
        updated.add(p);
      }
    }
    if (!found) {
      updated.add(playlist);
    }
    final list = updated.map((p) => p.toJson()).toList();
    await prefs.setString(_keyPlaylists, jsonEncode(list));
    return playlist;
  }

  @override
  Future<void> deletePlaylist(String id) async {
    final prefs = await _instance;
    final all = await getPlaylists();
    final filtered = all.where((p) => p.id != id).toList();
    final list = filtered.map((p) => p.toJson()).toList();
    await prefs.setString(_keyPlaylists, jsonEncode(list));
  }
}

