import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../auth/auth_session_store.dart';
import '../network/profile_api.dart';
import '../network/tracks_api.dart';
import '../offline/offline_download_repository.dart';
import '../settings/settings_repository.dart';
import '../social/colisten_controller.dart';
import '../social/listening_room_session.dart';
import 'mimusic_audio_handler.dart';
import 'track.dart';

/// Фасад над [AudioHandler]: воспроизведение через audio_service (уведомление
/// в шторке Android и Control Center iOS) с сохранением API для UI и эквалайзера.
class AudioPlayerService extends ChangeNotifier {
  AudioPlayerService({
    required AudioHandler audioHandler,
    required SettingsRepository settingsRepository,
    required OfflineDownloadRepository offlineDownloads,
  }) : _handler = audioHandler as MiMusicAudioHandler,
       _settingsRepository = settingsRepository,
       _offlineDownloads = offlineDownloads {
    setMiMusicHandlerRemoteActions(
      onLike: toggleLike,
      onDislike: toggleDislikeCurrent,
    );
    _listenToHandler();
    unawaited(_bootstrapOfflineState());
    unawaited(syncTrackLikesFromServer());
    _offlineDownloads.addListener(_onOfflineDownloadsChanged);
  }

  final MiMusicAudioHandler _handler;
  final SettingsRepository _settingsRepository;
  final OfflineDownloadRepository _offlineDownloads;

  StreamSubscription<PlaybackState>? _playbackStateSub;
  StreamSubscription<MediaItem?>? _mediaItemSub;
  int? _lastSyncedNowPlayingTrackId;
  String? _lastLikeStatusSyncKey;

  Track? _currentTrack;
  Duration _position = Duration.zero;
  Duration? _duration;
  bool _isPlaying = false;
  bool _guestLocalPauseActive = false;
  int _playbackMirrorSuppressUntilMs = 0;
  List<Track> _activeQueue = const [];

  Future<void> _bootstrapOfflineState() async {
    await _offlineDownloads.ensureLoaded();
    notifyListeners();
  }

  void _onOfflineDownloadsChanged() {
    notifyListeners();
  }

  OfflineDownloadRepository get offlineDownloads => _offlineDownloads;

  Track? get currentTrack => _currentTrack;
  bool get isPlaying => _isPlaying;
  /// Фактическое состояние движка (не UI-кэш `_isPlaying`).
  bool get engineIsPlaying => _handler.playbackState.value.playing;
  /// Позиция из audio_service (актуальнее UI-кэша сразу после seek/skip).
  Duration get enginePosition => _handler.playbackState.value.updatePosition;
  bool get guestLocalPauseActive => _guestLocalPauseActive;
  Duration get position => _position;
  Duration? get duration => _duration;

  /// Пути (assetPath) треков, отмеченных как избранные.
  Set<String> get likedPaths => Set.from(_handler.likedPathsNotifier.value);

  /// Пути с дизлайком.
  Set<String> get dislikedPaths =>
      Set.from(_handler.dislikedPathsNotifier.value);

  bool get shuffleEnabled => _handler.shuffleModeNotifier.value;

  LoopMode get loopMode => _handler.loopModeNotifier.value;
  String get roomRepeatModeWire => switch (_handler.loopModeNotifier.value) {
    LoopMode.off => 'off',
    LoopMode.all => 'all',
    LoopMode.one => 'one',
  };

  /// Очередь из нескольких треков (для shuffle / repeat all).
  bool get hasMultiTrackQueue => _handler.hasMultiTrackQueue;
  List<Track> get activeQueue => List.unmodifiable(_activeQueue);
  Set<String> get downloadedPaths {
    return _offlineDownloads.downloadedTracks
        .map((t) => t.assetKey)
        .toSet();
  }

  Set<String> get downloadingPaths => _offlineDownloads.downloadingKeys;

  /// Путь текущего трека в очереди (как в плеере).
  String? get currentPlayablePath => _handler.currentPlayablePath;

  bool isPathLiked(String path) => path.isNotEmpty && likedPaths.contains(path);

  bool isPathDisliked(String path) =>
      path.isNotEmpty && dislikedPaths.contains(path);

  bool isTrackDownloading(String path) =>
      path.isNotEmpty && _offlineDownloads.isDownloading(path);

  bool isTrackDownloaded(String path) =>
      path.isNotEmpty && _offlineDownloads.isDownloaded(path);

  void _listenToHandler() {
    _handler.likedPathsNotifier.addListener(_onLikedPathsChanged);
    _handler.dislikedPathsNotifier.addListener(_onLikedPathsChanged);
    _handler.shuffleModeNotifier.addListener(_onLikedPathsChanged);
    _handler.loopModeNotifier.addListener(_onLikedPathsChanged);
    _playbackStateSub = _handler.playbackState.listen((state) {
      final newPos = state.updatePosition;
      final posChanged = _position != newPos;
      _position = newPos;

      var changed = posChanged;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final room = ListeningRoomSession.instance;
      final hostOwnsPlayState =
          room.active && room.isHost && room.canControlPause;
      if (nowMs >= _playbackMirrorSuppressUntilMs &&
          !hostOwnsPlayState &&
          _isPlaying != state.playing) {
        _isPlaying = state.playing;
        changed = true;
      }
      if (changed) notifyListeners();
    });
    _mediaItemSub = _handler.mediaItem.listen((item) {
      if (item != null) {
        _currentTrack = _trackFromMediaItem(item);
        unawaited(_syncNowPlayingCurrentTrack());
        unawaited(_syncLikeStateForCurrentTrack());
      }
      _duration = item?.duration ?? _duration;
      notifyListeners();
    });
  }

  void _onLikedPathsChanged() {
    notifyListeners();
  }

  void _suppressPlayingMirror({int ms = 120}) {
    _playbackMirrorSuppressUntilMs =
        DateTime.now().millisecondsSinceEpoch + ms;
  }

  /// Сериализует play/pause в комнате (без блокировки повторных нажатий).
  Future<void> _colistenToggleChain = Future<void>.value();

  void _syncPlayingFromHandler({bool notify = true}) {
    final playing = _handler.playbackState.value.playing;
    final changed = _isPlaying != playing;
    _isPlaying = playing;
    if (notify && changed) notifyListeners();
  }

  Track _mediaItemToTrack(MediaItem item) {
    return Track(assetPath: item.id, title: item.title, artist: item.artist);
  }

  Track _trackFromMediaItem(MediaItem item) {
    final fromQueue = _activeQueue.where((t) {
      final play = playablePath(t);
      return play == item.id || t.assetPath == item.id;
    }).toList();
    if (fromQueue.isNotEmpty) {
      final base = fromQueue.first;
      return Track(
        assetPath: base.assetPath,
        title: item.title.isNotEmpty ? item.title : base.title,
        artist: (item.artist ?? '').isNotEmpty ? item.artist : base.artist,
        coverBytes: base.coverBytes,
        coverAssetPath: base.coverAssetPath,
        audioFilePath: base.audioFilePath,
      );
    }

    final current = _currentTrack;
    if (current != null && playablePath(current) == item.id) {
      return Track(
        assetPath: current.assetPath,
        title: item.title.isNotEmpty ? item.title : current.title,
        artist: (item.artist ?? '').isNotEmpty ? item.artist : current.artist,
        coverBytes: current.coverBytes,
        coverAssetPath: current.coverAssetPath,
        audioFilePath: current.audioFilePath,
      );
    }
    return _mediaItemToTrack(item);
  }

  /// Путь для воспроизведения: файл (если загружен в студии) или asset.
  static String playablePath(Track t) {
    final local = t.audioFilePath;
    if (local != null &&
        local.isNotEmpty &&
        !local.startsWith('http://') &&
        !local.startsWith('https://')) {
      return local;
    }
    return local ?? t.assetPath;
  }

  String resolvedPlayablePath(Track t) {
    final offline = _offlineDownloads.localPathForAssetKey(t.assetPath);
    if (offline != null && offline.isNotEmpty) return offline;
    return playablePath(t);
  }

  void _recordListeningHistoryForTrack(Track track) {
    final repo = listeningHistoryRepository;
    if (repo == null) return;
    final key = track.assetPath.trim();
    if (key.isEmpty) return;
    repo.recordPlayback(
      playablePath: key,
      title: track.title,
      artist: track.artist,
      coverAssetPath: track.coverFallbackPath,
    );
    _handler.markListeningHistoryRecorded(key);
  }

  /// Загружает и воспроизводит трек. Показывает медиа-уведомление на Android/iOS.
  /// [queue] — очередь для кнопок предыдущий/следующий в уведомлении.
  ///
  /// Если [leaveListeningRoomSession] и активна комната совместного прослушивания,
  /// сессия сбрасывается — обычное воспроизведение из списков и карточек вне комнаты.
  /// Для входа в комнату и правок очереди передайте `false`.
  Future<void> playTrack(
    Track track, {
    List<Track>? queue,
    bool leaveListeningRoomSession = true,
    bool autoPlay = true,
  }) async {
    if (leaveListeningRoomSession && ListeningRoomSession.instance.active) {
      ListeningRoomSession.instance.end();
    }
    _currentTrack = track;
    _activeQueue = _normalizeQueue(track, queue);
    notifyListeners();
    if (autoPlay) {
      _recordListeningHistoryForTrack(track);
    }
    String? artUri;
    if (track.coverBytes != null && track.coverBytes!.isNotEmpty) {
      artUri = await _coverBytesToFileUri(track.coverBytes!);
    }
    final path = resolvedPlayablePath(track);
    final queueMaps = queue
        ?.map(
          (t) => {
            'path': resolvedPlayablePath(t),
            'itemId': t.assetPath,
            'title': t.title,
            'artist': t.artist,
            'artPath': t.coverFallbackPath,
          },
        )
        .toList();
    final pathBefore = currentPlayablePath;
    await _handler.customAction('playAsset', {
      'path': path,
      'itemId': track.assetPath,
      'title': track.title,
      'artist': track.artist,
      'artPath': track.coverFallbackPath,
      'artUri': artUri,
      'autoPlay': autoPlay,
      if (queueMaps?.isNotEmpty ?? false) 'queue': queueMaps,
    });
    final room = ListeningRoomSession.instance;
    if (room.active && room.isHost && !leaveListeningRoomSession) {
      unawaited(
        ColistenController.instance.pushHostTransportStateAfterSkip(
          this,
          previousPlayablePath: pathBefore,
        ),
      );
    }
    unawaited(_syncNowPlayingToServer(track));
    _lastLikeStatusSyncKey = null;
    unawaited(_syncLikeStateForCurrentTrack());
  }

  Future<void> _syncNowPlayingToServer(Track track) async {
    final id = TracksApi().resolveServerTrackId(
      assetPath: track.assetPath,
      audioFilePath: track.audioFilePath,
    );
    if (id == null) return;
    if (_lastSyncedNowPlayingTrackId == id) return;
    try {
      await ProfileApi().putNowPlaying(trackId: id);
      _lastSyncedNowPlayingTrackId = id;
    } catch (_) {}
  }

  Future<void> _syncNowPlayingCurrentTrack() async {
    final track = _currentTrack;
    if (track == null) return;
    await _syncNowPlayingToServer(track);
  }

  List<Track> _normalizeQueue(Track track, List<Track>? queue) {
    if (queue == null || queue.isEmpty) return [track];
    final hasTrack = queue.any((e) => e.assetPath == track.assetPath);
    if (hasTrack) return List<Track>.from(queue);
    return [track, ...queue];
  }

  List<Map<String, dynamic>> _queueMapsFromTracks(List<Track> tracks) {
    return tracks
        .map(
          (t) => {
            'path': resolvedPlayablePath(t),
            'itemId': t.assetPath,
            'title': t.title,
            'artist': t.artist,
            'artPath': t.coverFallbackPath,
          },
        )
        .toList();
  }

  /// Меняет очередь, сохраняя текущий трек и позицию (без полного reload с 0:00).
  Future<void> syncQueuePreservingPlayback(List<Track> nextQueue) async {
    if (nextQueue.isEmpty) return;
    final current = _currentTrack;
    if (current == null) {
      await playTrack(
        nextQueue.first,
        queue: nextQueue,
        leaveListeningRoomSession: false,
        autoPlay: false,
      );
      return;
    }
    final resumeAt = position;
    final wasPlaying = isPlaying;
    final path = resolvedPlayablePath(current);
    final inQueue = nextQueue.any((t) => resolvedPlayablePath(t) == path);
    if (!inQueue) {
      await playTrack(
        nextQueue.first,
        queue: nextQueue,
        leaveListeningRoomSession: false,
        autoPlay: wasPlaying,
      );
      return;
    }
    await _handler.customAction('updateQueuePreserve', {
      'path': path,
      'queue': _queueMapsFromTracks(nextQueue),
      'positionSeconds': resumeAt.inMilliseconds / 1000.0,
      'autoPlay': wasPlaying,
    });
    _activeQueue = List<Track>.from(nextQueue);
    notifyListeners();
  }

  Future<void> _applyQueueKeepingCurrent(List<Track> nextQueue) async {
    await syncQueuePreservingPlayback(nextQueue);
  }

  /// Синхронизирует очередь из комнаты: сохраняет текущий трек, если он есть в очереди.
  Future<void> replaceQueueFromRoomSync(List<Track> nextQueue) async {
    if (nextQueue.isEmpty) return;
    await syncQueuePreservingPlayback(nextQueue);
    final room = ListeningRoomSession.instance;
    if (room.active && room.isHost) {
      ColistenController.instance.pushHostState(this);
    }
  }

  Future<void> removeFromQueue(String assetPath) async {
    if (_activeQueue.isEmpty) return;
    final nextQueue = _activeQueue
        .where((e) => e.assetPath != assetPath)
        .toList();
    if (nextQueue.length == _activeQueue.length) return;
    if (nextQueue.isEmpty) {
      await stop();
      _activeQueue = const [];
      notifyListeners();
      return;
    }

    final current = _currentTrack;
    if (current != null && current.assetPath == assetPath) {
      await playTrack(
        nextQueue.first,
        queue: nextQueue,
        leaveListeningRoomSession: false,
      );
      final room = ListeningRoomSession.instance;
      if (room.active && room.canEditQueue) {
        ColistenController.instance.pushHostState(
          this,
          includeQueueForGuest: true,
        );
      }
      return;
    }
    await _applyQueueKeepingCurrent(nextQueue);
    final room = ListeningRoomSession.instance;
    if (room.active && room.canEditQueue) {
      ColistenController.instance.pushHostState(
        this,
        includeQueueForGuest: true,
      );
    }
  }

  Future<void> moveToPlayNext(String assetPath) async {
    if (_activeQueue.length < 2) return;
    final from = _activeQueue.indexWhere((e) => e.assetPath == assetPath);
    if (from == -1) return;
    final item = _activeQueue[from];
    final updated = List<Track>.from(_activeQueue)..removeAt(from);
    final currentPath = _currentTrack?.assetPath;
    final currentIndex = currentPath == null
        ? -1
        : updated.indexWhere((e) => e.assetPath == currentPath);
    final insertAt = currentIndex == -1
        ? 0
        : (currentIndex + 1).clamp(0, updated.length);
    updated.insert(insertAt, item);
    await _applyQueueKeepingCurrent(updated);
    final room = ListeningRoomSession.instance;
    if (room.active && room.canEditQueue) {
      ColistenController.instance.pushHostState(
        this,
        includeQueueForGuest: true,
      );
    }
  }

  Future<void> addToQueue(Track track) async {
    final updated = List<Track>.from(_activeQueue);
    if (updated.any((e) => e.assetPath == track.assetPath)) return;
    updated.add(track);
    if (_currentTrack == null) {
      await playTrack(track, queue: updated, leaveListeningRoomSession: false);
      final room = ListeningRoomSession.instance;
      if (room.active && room.canEditQueue) {
        ColistenController.instance.pushHostState(
          this,
          includeQueueForGuest: true,
        );
      }
      return;
    }
    await _applyQueueKeepingCurrent(updated);
    final room = ListeningRoomSession.instance;
    if (room.active && room.canEditQueue) {
      ColistenController.instance.pushHostState(
        this,
        includeQueueForGuest: true,
      );
    }
  }

  /// Скачивает серверный трек в локальное хранилище с учётом лимита кэша.
  Future<DownloadTrackResult> downloadTrack(Track track) {
    return _offlineDownloads.downloadTrack(track);
  }

  /// @deprecated Используйте [downloadTrack].
  Future<DownloadTrackResult> cacheTrackMock(Track track) => downloadTrack(track);

  static Future<String?> _coverBytesToFileUri(List<int> bytes) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/mimusic_cover.jpg');
      await file.writeAsBytes(bytes);
      return Uri.file(file.path).toString();
    } catch (_) {
      return null;
    }
  }

  Future<void> togglePlayPause() async {
    if (!ListeningRoomSession.instance.active &&
        ColistenController.instance.isConnected) {
      await ColistenController.instance.disconnect();
    }
    final room = ListeningRoomSession.instance;
    if (room.active && !room.canControlPause) return;
    if (room.active && room.canControlPause) {
      _colistenToggleChain = _colistenToggleChain.then(
        (_) => _runColistenTogglePlayPause(room),
      );
      return _colistenToggleChain;
    }
    await _runLocalTogglePlayPause(room);
  }

  Future<void> _runColistenTogglePlayPause(ListeningRoomSession room) async {
    if (!room.active || !room.canControlPause) return;
    ColistenController.instance.onGuestManualPlayPauseToggle(this);
    // UI-намерение (_isPlaying), не engineIsPlaying: после pause движок часто
    // ещё «playing», и повторный tap инвертирует команду на сервер.
    final willPlay = !_isPlaying;
    _suppressPlayingMirror(ms: 450);
    _isPlaying = willPlay;
    notifyListeners();
    if (room.isHost) {
      ColistenController.instance.pushHostPlayPauseState(
        this,
        playing: willPlay,
      );
    } else {
      ColistenController.instance.sendGuestPlayPauseCommand(
        this,
        playing: willPlay,
      );
    }
    // ExoPlayer play/pause на части Android зависает — не блокируем UI-очередь.
    unawaited(_syncColistenEnginePlayPause(willPlay));
  }

  Future<void> _syncColistenEnginePlayPause(bool willPlay) async {
    try {
      if (!willPlay) {
        await _handler.pause().timeout(const Duration(seconds: 3));
      } else {
        await _handler.play().timeout(const Duration(seconds: 3));
      }
    } on TimeoutException {
      debugPrint(
        '[colisten] togglePlayPause engine timeout willPlay=$willPlay',
      );
    } catch (e, st) {
      debugPrint('[colisten] togglePlayPause engine error willPlay=$willPlay: $e\n$st');
    }
  }

  Future<void> _runLocalTogglePlayPause(ListeningRoomSession room) async {
    final willPlay = !_isPlaying;
    _suppressPlayingMirror(ms: room.active ? 450 : 120);
    _isPlaying = willPlay;
    notifyListeners();
    if (!willPlay) {
      await _handler.pause();
    } else {
      await _handler.play();
    }
  }

  Future<void> toggleGuestLocalPause() async {
    final room = ListeningRoomSession.instance;
    if (!room.active || room.isHost) {
      await togglePlayPause();
      return;
    }
    return;
  }

  Future<void> play() async {
    final room = ListeningRoomSession.instance;
    if (room.active && !room.canControlPause) return;
    _suppressPlayingMirror();
    _isPlaying = true;
    notifyListeners();
    await _handler.play();
    _syncPlayingFromHandler();
  }

  Future<void> pause() async {
    final room = ListeningRoomSession.instance;
    if (room.active && !room.canControlPause) return;
    _suppressPlayingMirror();
    _isPlaying = false;
    notifyListeners();
    await _handler.pause();
    _syncPlayingFromHandler();
  }

  Future<void> seek(Duration position) async {
    final room = ListeningRoomSession.instance;
    if (room.active && !room.canControlSeek) return;
    final positionSeconds = position.inMilliseconds / 1000.0;
    if (room.active && room.canControlSeek) {
      ColistenController.instance.pushHostTransportState(
        this,
        positionSeconds: positionSeconds,
        playing: _isPlaying,
      );
    }
    _position = position;
    notifyListeners();
    unawaited(_syncColistenEngineSeek(position));
  }

  Future<void> _syncColistenEngineSeek(Duration position) async {
    try {
      await _handler.seek(position).timeout(const Duration(seconds: 3));
      _syncPlayingFromHandler(notify: false);
      notifyListeners();
    } on TimeoutException {
      debugPrint('[colisten] seek engine timeout pos=${position.inMilliseconds}ms');
    } catch (e, st) {
      debugPrint('[colisten] seek engine error: $e\n$st');
    }
  }

  /// Принудительный seek для синхронизации комнаты (без проверки прав гостя).
  Future<void> seekFromRoomSync(Duration position) async {
    if (!ListeningRoomSession.instance.active) return;
    try {
      await _handler.customAction('roomSyncSeek', {
        'positionSeconds': position.inMilliseconds / 1000.0,
      });
      _position = position;
      notifyListeners();
    } catch (e, st) {
      debugPrint('[colisten] seekFromRoomSync error: $e\n$st');
    }
  }

  Future<void> playFromRoomSync() async {
    if (!ListeningRoomSession.instance.active) return;
    if (_guestLocalPauseActive) return;
    try {
      _suppressPlayingMirror(ms: 500);
      await _handler.customAction('roomSyncPlay');
      _syncPlayingFromHandler(notify: true);
    } catch (e, st) {
      debugPrint('[colisten] playFromRoomSync error: $e\n$st');
    }
  }

  Future<void> pauseFromRoomSync() async {
    if (!ListeningRoomSession.instance.active) return;
    try {
      _suppressPlayingMirror(ms: 500);
      await _handler.customAction('roomSyncPause');
      _syncPlayingFromHandler(notify: true);
    } catch (e, st) {
      debugPrint('[colisten] pauseFromRoomSync error: $e\n$st');
    }
  }

  Future<void> stop() async {
    await _handler.stop();
    _guestLocalPauseActive = false;
    _currentTrack = null;
    _position = Duration.zero;
    _duration = null;
    _isPlaying = false;
    notifyListeners();
    unawaited(_clearNowPlayingOnServer());
  }

  Future<void> _clearNowPlayingOnServer() async {
    try {
      await ProfileApi().putNowPlaying(trackId: null);
      _lastSyncedNowPlayingTrackId = null;
    } catch (_) {}
  }

  /// Сбрасывает «сейчас слушает» на сервере при уходе приложения в фон.
  Future<void> notifyAppBackgrounded() => _clearNowPlayingOnServer();

  Future<void> skipToNext() async {
    final room = ListeningRoomSession.instance;
    if (room.active && !room.canControlSkip) return;
    final pathBefore = currentPlayablePath;
    await _handler.skipToNext();
    if (room.active && room.canControlSkip) {
      unawaited(
        ColistenController.instance.pushHostTransportStateAfterSkip(
          this,
          previousPlayablePath: pathBefore,
        ),
      );
    }
  }

  Future<void> skipToPrevious() async {
    final room = ListeningRoomSession.instance;
    if (room.active && !room.canControlSkip) return;
    final pathBefore = currentPlayablePath;
    await _handler.skipToPrevious();
    if (room.active && room.canControlSkip) {
      unawaited(
        ColistenController.instance.pushHostTransportStateAfterSkip(
          this,
          previousPlayablePath: pathBefore,
        ),
      );
    }
  }

  /// Стабильный ключ лайка (`server_track_N` / assets), не URL потока.
  String? get _currentLikeKey {
    final track = _currentTrack;
    if (track != null && track.assetPath.trim().isNotEmpty) {
      return track.assetPath.trim();
    }
    return currentPlayablePath;
  }

  Future<void> _syncLikeStateForCurrentTrack() async {
    final path = _currentLikeKey;
    if (path == null || path.isEmpty) {
      _lastLikeStatusSyncKey = null;
      return;
    }
    if (path == _lastLikeStatusSyncKey) return;
    _lastLikeStatusSyncKey = path;

    final trackId = TracksApi().parseServerTrackId(path);
    final acc = await AuthSessionStore.readAccount();
    final userId = acc?.userId;
    if (trackId == null || userId == null) return;

    try {
      final liked = await TracksApi().getTrackLikeStatus(
        trackId: trackId,
        userId: userId,
      );
      await _handler.customAction('setLikePath', {
        'path': path,
        'liked': liked,
      });
    } catch (_) {
      // офлайн / ошибка — оставляем локальное состояние
    }
  }

  Future<void> toggleLike() async {
    final path = _currentLikeKey;
    if (path == null || path.isEmpty) return;
    await toggleLikePath(path);
  }

  /// Лайк/снятие лайка по пути воспроизведения (для строк списков, не только текущий трек).
  Future<void> toggleLikePath(String path) async {
    if (path.isEmpty) return;
    final trackId = TracksApi().parseServerTrackId(path);
    final acc = await AuthSessionStore.readAccount();
    final userId = acc?.userId;
    if (trackId != null && userId != null) {
      try {
        final liked = await TracksApi().toggleTrackLike(
          trackId: trackId,
          userId: userId,
        );
        await _handler.customAction('setLikePath', {
          'path': path,
          'liked': liked,
        });
        _lastLikeStatusSyncKey = path;
        return;
      } catch (_) {
        // fallback локального переключения
      }
    }
    await _handler.customAction('toggleLikePath', {'path': path});
  }

  /// Дизлайк: локально помечает трек; при постановке снимает лайк на сервере (если был).
  Future<void> toggleDislikeCurrent() async {
    final path = _currentLikeKey;
    if (path == null || path.isEmpty) return;
    await toggleDislikePath(path);
  }

  Future<void> toggleDislikePath(String path) async {
    if (path.isEmpty) return;

    if (isPathDisliked(path)) {
      await _handler.customAction('dislike', {'path': path});
      return;
    }

    final trackId = TracksApi().parseServerTrackId(path);
    final userId = (await AuthSessionStore.readAccount())?.userId;
    if (trackId != null && userId != null) {
      try {
        final likedOnServer = isPathLiked(path) ||
            await TracksApi().getTrackLikeStatus(
              trackId: trackId,
              userId: userId,
            );
        if (likedOnServer) {
          await TracksApi().toggleTrackLike(trackId: trackId, userId: userId);
          _lastLikeStatusSyncKey = path;
        }
        await _handler.customAction('setLikePath', {
          'path': path,
          'liked': false,
        });
      } catch (_) {
        // офлайн — только локальный дизлайк ниже
      }
    }

    if (!isPathDisliked(path)) {
      await _handler.customAction('dislike', {'path': path});
    }
  }

  Future<void> setShuffleEnabled(bool enabled) async {
    final room = ListeningRoomSession.instance;
    if (room.active && !room.canControlShuffle) return;
    await _handler.setShuffleEnabled(enabled);
    if (room.active && room.canControlShuffle) {
      ColistenController.instance.pushHostState(this);
    }
    notifyListeners();
  }

  Future<void> toggleShuffle() async {
    await setShuffleEnabled(!shuffleEnabled);
  }

  Future<void> cycleLoopMode() async {
    final room = ListeningRoomSession.instance;
    if (room.active && !room.canControlRepeat) return;
    await _handler.cycleLoopMode();
    if (room.active && room.canControlRepeat) {
      ColistenController.instance.pushHostState(this);
    }
    notifyListeners();
  }

  Future<void> applyRoomPlaybackModes({
    bool? shuffleEnabled,
    String? repeatMode,
  }) async {
    if (!ListeningRoomSession.instance.active) return;
    var changed = false;
    if (shuffleEnabled != null && shuffleEnabled != this.shuffleEnabled) {
      await _handler.setShuffleEnabled(shuffleEnabled);
      changed = true;
    }
    if (repeatMode != null && repeatMode.isNotEmpty) {
      final nextLoop = switch (repeatMode.trim().toLowerCase()) {
        'all' => LoopMode.all,
        'one' => LoopMode.one,
        _ => LoopMode.off,
      };
      if (nextLoop != loopMode) {
        await _handler.setLoopMode(nextLoop);
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  /// Удаляет трек из избранного по assetPath (для страницы «Любимые»).
  Future<void> removeFromFavorites(String assetPath) async {
    final trackId = TracksApi().parseServerTrackId(assetPath);
    final acc = await AuthSessionStore.readAccount();
    final userId = acc?.userId;
    if (trackId != null && userId != null) {
      try {
        final liked = await TracksApi().getTrackLikeStatus(
          trackId: trackId,
          userId: userId,
        );
        if (liked) {
          await TracksApi().toggleTrackLike(trackId: trackId, userId: userId);
        }
        await _handler.customAction('setLikePath', {
          'path': assetPath,
          'liked': false,
        });
        return;
      } catch (_) {
        // fallback ниже
      }
    }
    await _handler.customAction('dislike', {'path': assetPath});
  }

  Future<void> syncTrackLikesFromServer() async {
    final acc = await AuthSessionStore.readAccount();
    final userId = acc?.userId;
    if (userId == null) return;
    try {
      final loved = await TracksApi().fetchLovedTracks(userId: userId);
      await _handler.customAction('replaceLikedPaths', {
        'paths': loved.map((t) => 'server_track_${t.id}').toList(),
      });
    } catch (_) {
      // сеть недоступна — оставляем локальное состояние
    }
  }

  /// Применяет настройки эквалайзера из настроек приложения.
  Future<void> applyEqualizerFromSettings() async {
    final settings = await _settingsRepository.getSettings();
    await _handler.customAction('applyEqualizer', {
      'gains': settings.equalizerGains,
    });
    notifyListeners();
  }

  /// Применяет переданные gains эквалайзера (для экрана эквалайзера).
  Future<void> applyEqualizerGains(List<double> gains) async {
    await _handler.customAction('applyEqualizer', {'gains': gains});
    notifyListeners();
  }

  @override
  void dispose() {
    setMiMusicHandlerRemoteActions(onLike: null, onDislike: null);
    _offlineDownloads.removeListener(_onOfflineDownloadsChanged);
    if (ColistenController.instance.isConnected ||
        ListeningRoomSession.instance.active) {
      unawaited(ColistenController.instance.disconnect());
    }
    _handler.likedPathsNotifier.removeListener(_onLikedPathsChanged);
    _handler.dislikedPathsNotifier.removeListener(_onLikedPathsChanged);
    _handler.shuffleModeNotifier.removeListener(_onLikedPathsChanged);
    _handler.loopModeNotifier.removeListener(_onLikedPathsChanged);
    _playbackStateSub?.cancel();
    _mediaItemSub?.cancel();
    super.dispose();
  }
}
