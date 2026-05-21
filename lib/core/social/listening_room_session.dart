import 'dart:async';

import 'package:flutter/foundation.dart';

import '../audio/track.dart';
import 'colisten_controller.dart';

class ListeningRoomSession extends ChangeNotifier {
  ListeningRoomSession._();

  static final ListeningRoomSession instance = ListeningRoomSession._();

  bool _active = false;
  String _roomTitle = '';
  String _hostUsername = '';
  String _currentUsername = 'mifoxti';
  List<String> _listeners = const [];
  List<int> _participantIds = const [];
  Map<int, String> _participantNames = const {};
  bool _privateRoom = true;
  bool _pauseHostOnly = true;
  bool _seekHostOnly = true;
  bool _shuffleHostOnly = true;
  bool _repeatHostOnly = true;
  bool _skipHostOnly = true;
  bool _playlistHostOnly = true;
  List<String> _selectedPlaylists = const [];
  List<Track> _queue = const [];
  bool _joining = false;

  bool get active => _active;
  String get roomTitle => _roomTitle;
  String get hostUsername => _hostUsername;
  String get currentUsername => _currentUsername;
  List<String> get listeners => List.unmodifiable(_listeners);
  List<int> get participantIds => List.unmodifiable(_participantIds);
  int get listenersCount => _listeners.length;
  bool get privateRoom => _privateRoom;
  bool get pauseHostOnly => _pauseHostOnly;
  bool get seekHostOnly => _seekHostOnly;
  bool get shuffleHostOnly => _shuffleHostOnly;
  bool get repeatHostOnly => _repeatHostOnly;
  bool get skipHostOnly => _skipHostOnly;
  bool get playlistHostOnly => _playlistHostOnly;
  List<String> get selectedPlaylists => List.unmodifiable(_selectedPlaylists);
  List<Track> get queue => List.unmodifiable(_queue);
  bool get joining => _joining;
  bool get isHost =>
      _hostUsername.isNotEmpty && _hostUsername == _currentUsername;
  bool get canControlPause => isHost || !_pauseHostOnly;
  bool get canControlSeek => isHost || !_seekHostOnly;
  bool get canControlShuffle => isHost || !_shuffleHostOnly;
  bool get canControlRepeat => isHost || !_repeatHostOnly;
  bool get canControlSkip => isHost || !_skipHostOnly;
  bool get canEditQueue => isHost || !_playlistHostOnly;

  void start({
    required String roomTitle,
    required List<String> listeners,
    required String hostUsername,
    required String currentUsername,
    required bool privateRoom,
    required bool pauseHostOnly,
    required bool seekHostOnly,
    required bool shuffleHostOnly,
    required bool repeatHostOnly,
    required bool skipHostOnly,
    required bool playlistHostOnly,
    required List<String> selectedPlaylists,
    required List<Track> queue,
  }) {
    _active = true;
    _roomTitle = roomTitle;
    _hostUsername = hostUsername;
    _currentUsername = currentUsername;
    _listeners = List<String>.from(listeners);
    _participantIds = const [];
    _participantNames = const {};
    _privateRoom = privateRoom;
    _pauseHostOnly = pauseHostOnly;
    _seekHostOnly = seekHostOnly;
    _shuffleHostOnly = shuffleHostOnly;
    _repeatHostOnly = repeatHostOnly;
    _skipHostOnly = skipHostOnly;
    _playlistHostOnly = playlistHostOnly;
    _selectedPlaylists = List<String>.from(selectedPlaylists);
    _queue = List<Track>.from(queue);
    notifyListeners();
  }

  void updateSettings({
    required bool privateRoom,
    required bool pauseHostOnly,
    required bool seekHostOnly,
    required bool shuffleHostOnly,
    required bool repeatHostOnly,
    required bool skipHostOnly,
    required bool playlistHostOnly,
  }) {
    _privateRoom = privateRoom;
    _pauseHostOnly = pauseHostOnly;
    _seekHostOnly = seekHostOnly;
    _shuffleHostOnly = shuffleHostOnly;
    _repeatHostOnly = repeatHostOnly;
    _skipHostOnly = skipHostOnly;
    _playlistHostOnly = playlistHostOnly;
    notifyListeners();
  }

  void applyRealtimeState({
    required int listenersCount,
    required List<int> participantIds,
    Map<int, String> participantNames = const {},
    required bool privateRoom,
    required bool pauseHostOnly,
    required bool seekHostOnly,
    required bool shuffleHostOnly,
    required bool repeatHostOnly,
    required bool skipHostOnly,
    required bool playlistHostOnly,
  }) {
    final safeCount = listenersCount < 1 ? 1 : listenersCount;
    final ids = participantIds.toSet().toList();
    final names = Map<int, String>.from(participantNames);
    final nextListeners = <String>[_hostUsername];
    for (final id in ids) {
      final name = names[id]?.trim();
      if (name == null || name.isEmpty || name == _hostUsername) continue;
      if (!nextListeners.contains(name)) nextListeners.add(name);
    }
    while (nextListeners.length < safeCount) {
      nextListeners.add('listener_${nextListeners.length + 1}');
    }
    final unchanged =
        listEquals(_listeners, nextListeners) &&
        listEquals(_participantIds, ids) &&
        mapEquals(_participantNames, names) &&
        _privateRoom == privateRoom &&
        _pauseHostOnly == pauseHostOnly &&
        _seekHostOnly == seekHostOnly &&
        _shuffleHostOnly == shuffleHostOnly &&
        _repeatHostOnly == repeatHostOnly &&
        _skipHostOnly == skipHostOnly &&
        _playlistHostOnly == playlistHostOnly;
    if (unchanged) return;
    _listeners = nextListeners;
    _participantIds = ids;
    _participantNames = names;
    _privateRoom = privateRoom;
    _pauseHostOnly = pauseHostOnly;
    _seekHostOnly = seekHostOnly;
    _shuffleHostOnly = shuffleHostOnly;
    _repeatHostOnly = repeatHostOnly;
    _skipHostOnly = skipHostOnly;
    _playlistHostOnly = playlistHostOnly;
    notifyListeners();
  }

  String participantName(int userId) {
    final name = _participantNames[userId]?.trim();
    if (name != null && name.isNotEmpty) return name;
    return 'listener_$userId';
  }

  void replaceQueue(List<Track> nextQueue) {
    _queue = List<Track>.from(nextQueue);
    notifyListeners();
  }

  void setJoining(bool value) {
    if (_joining == value) return;
    _joining = value;
    notifyListeners();
  }

  void removeParticipant(String username) {
    if (!_listeners.contains(username)) return;
    _listeners = _listeners.where((e) => e != username).toList();
    notifyListeners();
  }

  void removeFromQueue(String assetPath) {
    final next = _queue.where((e) => e.assetPath != assetPath).toList();
    if (next.length == _queue.length) return;
    _queue = next;
    notifyListeners();
  }

  void moveToPlayNext({required String assetPath, String? currentAssetPath}) {
    final from = _queue.indexWhere((e) => e.assetPath == assetPath);
    if (from == -1) return;
    final item = _queue[from];
    final updated = List<Track>.from(_queue)..removeAt(from);
    final currentIndex = currentAssetPath == null
        ? -1
        : updated.indexWhere((e) => e.assetPath == currentAssetPath);
    final insertAt = currentIndex == -1
        ? 0
        : (currentIndex + 1).clamp(0, updated.length);
    updated.insert(insertAt, item);
    _queue = updated;
    notifyListeners();
  }

  void insertIntoQueue(int index, Track track) {
    final safeIndex = index.clamp(0, _queue.length);
    final updated = List<Track>.from(_queue);
    updated.insert(safeIndex, track);
    _queue = updated;
    notifyListeners();
  }

  void end() {
    unawaited(ColistenController.instance.disconnect());
    _active = false;
    _roomTitle = '';
    _hostUsername = '';
    _currentUsername = 'mifoxti';
    _listeners = const [];
    _participantIds = const [];
    _participantNames = const {};
    _privateRoom = true;
    _pauseHostOnly = true;
    _seekHostOnly = true;
    _shuffleHostOnly = true;
    _repeatHostOnly = true;
    _skipHostOnly = true;
    _playlistHostOnly = true;
    _selectedPlaylists = const [];
    _queue = const [];
    _joining = false;
    notifyListeners();
  }
}
