import 'dart:async';

import 'package:flutter/foundation.dart';

import '../auth/auth_session_store.dart';
import '../network/api_config.dart';
import '../network/listening_history_api.dart';
import '../network/tracks_api.dart';
import 'listening_history_entry.dart';
import 'listening_history_repository.dart';

/// История прослушиваний с сервера ([GET /me/listening-history], [POST /me/listen-events]).
class ApiListeningHistoryRepository extends ListeningHistoryRepository {
  ApiListeningHistoryRepository({ListeningHistoryApi? api})
      : _api = api ?? ListeningHistoryApi();

  final ListeningHistoryApi _api;
  static const int _maxEntries = 200;

  final List<ListeningHistoryEntry> _entries = [];
  bool _loaded = false;

  @override
  List<ListeningHistoryEntry> get entries => List.unmodifiable(_entries);

  Future<void> refresh() async {
    final acc = await AuthSessionStore.readAccount();
    if (acc?.userId == null || !acc!.isLoggedIn) {
      _entries.clear();
      _loaded = true;
      notifyListeners();
      return;
    }
    try {
      final list = await _api.fetchHistory(limit: _maxEntries);
      _entries
        ..clear()
        ..addAll(list.map(_entryFromDto));
      _loaded = true;
      notifyListeners();
    } catch (e, st) {
      debugPrint('Listening history refresh failed: $e\n$st');
    }
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await refresh();
  }

  @override
  void recordPlayback({
    required String playablePath,
    required String title,
    String? artist,
    String? coverAssetPath,
    DateTime? playedAt,
  }) {
    final trackId = TracksApi().parseServerTrackId(playablePath);
    if (trackId == null) return;

    final cover = coverAssetPath ??
        '${ApiConfig.baseUrl.replaceAll(RegExp(r'/+$'), '')}/tracks/$trackId/cover';

    _entries.removeWhere((e) => e.playablePath == playablePath);
    _entries.insert(
      0,
      ListeningHistoryEntry(
        playablePath: playablePath,
        title: title,
        artist: artist,
        coverAssetPath: cover,
        playedAt: playedAt ?? DateTime.now(),
      ),
    );
    while (_entries.length > _maxEntries) {
      _entries.removeLast();
    }
    notifyListeners();

    unawaited(_postListenEvent(trackId));
  }

  Future<void> _postListenEvent(int trackId) async {
    final acc = await AuthSessionStore.readAccount();
    if (acc?.userId == null || !acc!.isLoggedIn) return;
    try {
      await _api.recordListen(trackId);
    } catch (e, st) {
      debugPrint('Listen event POST failed: $e\n$st');
    }
  }

  @override
  void clear() {
    // События в БД не удаляем — нужны для чартов; только сброс локального кэша.
    _entries.clear();
    notifyListeners();
  }

  ListeningHistoryEntry _entryFromDto(ListeningHistoryItemDto dto) {
    final base = ApiConfig.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final path = 'server_track_${dto.trackId}';
    return ListeningHistoryEntry(
      playablePath: path,
      title: dto.title,
      artist: dto.artist,
      coverAssetPath: '$base/tracks/${dto.trackId}/cover',
      playedAt: _parsePlayedAt(dto.playedAt),
    );
  }

  DateTime _parsePlayedAt(String? raw) {
    if (raw == null || raw.isEmpty) return DateTime.now();
    return DateTime.tryParse(raw) ?? DateTime.now();
  }
}

