import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../settings/settings_repository.dart';
import '../social/listening_room_session.dart';
import 'mimusic_audio_handler.dart';
import 'track.dart';

/// Фасад над [AudioHandler]: воспроизведение через audio_service (уведомление
/// в шторке Android и Control Center iOS) с сохранением API для UI и эквалайзера.
class AudioPlayerService extends ChangeNotifier {
  AudioPlayerService({
    required AudioHandler audioHandler,
    required SettingsRepository settingsRepository,
  })  : _handler = audioHandler as MiMusicAudioHandler,
        _settingsRepository = settingsRepository {
    _listenToHandler();
  }

  final MiMusicAudioHandler _handler;
  final SettingsRepository _settingsRepository;

  StreamSubscription<PlaybackState>? _playbackStateSub;
  StreamSubscription<MediaItem?>? _mediaItemSub;

  Track? _currentTrack;
  Duration _position = Duration.zero;
  Duration? _duration;
  bool _isPlaying = false;
  List<Track> _activeQueue = const [];
  final Set<String> _downloadingPaths = <String>{};
  final Set<String> _downloadedPaths = <String>{};
  final Map<String, Timer> _downloadTimers = <String, Timer>{};

  Track? get currentTrack => _currentTrack;
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration? get duration => _duration;

  /// Пути (assetPath) треков, отмеченных как избранные.
  Set<String> get likedPaths => Set.from(_handler.likedPathsNotifier.value);

  /// Пути с дизлайком.
  Set<String> get dislikedPaths => Set.from(_handler.dislikedPathsNotifier.value);

  bool get shuffleEnabled => _handler.shuffleModeNotifier.value;

  LoopMode get loopMode => _handler.loopModeNotifier.value;

  /// Очередь из нескольких треков (для shuffle / repeat all).
  bool get hasMultiTrackQueue => _handler.hasMultiTrackQueue;
  List<Track> get activeQueue => List.unmodifiable(_activeQueue);
  Set<String> get downloadedPaths => Set.unmodifiable(_downloadedPaths);
  Set<String> get downloadingPaths => Set.unmodifiable(_downloadingPaths);

  /// Путь текущего трека в очереди (как в плеере).
  String? get currentPlayablePath => _handler.currentPlayablePath;

  bool isPathLiked(String path) =>
      path.isNotEmpty && likedPaths.contains(path);

  bool isPathDisliked(String path) =>
      path.isNotEmpty && dislikedPaths.contains(path);

  bool isTrackDownloading(String path) =>
      path.isNotEmpty && _downloadingPaths.contains(path);

  bool isTrackDownloaded(String path) =>
      path.isNotEmpty && _downloadedPaths.contains(path);

  void _listenToHandler() {
    _handler.likedPathsNotifier.addListener(_onLikedPathsChanged);
    _handler.dislikedPathsNotifier.addListener(_onLikedPathsChanged);
    _handler.shuffleModeNotifier.addListener(_onLikedPathsChanged);
    _handler.loopModeNotifier.addListener(_onLikedPathsChanged);
    _playbackStateSub = _handler.playbackState.listen((state) {
      _position = state.updatePosition;
      _isPlaying = state.playing;
      notifyListeners();
    });
    _mediaItemSub = _handler.mediaItem.listen((item) {
      if (item != null) {
        _currentTrack = _trackFromMediaItem(item);
      }
      _duration = item?.duration ?? _duration;
      notifyListeners();
    });
  }

  void _onLikedPathsChanged() {
    notifyListeners();
  }

  Track _mediaItemToTrack(MediaItem item) {
    return Track(
      assetPath: item.id,
      title: item.title,
      artist: item.artist,
    );
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
  static String playablePath(Track t) => t.audioFilePath ?? t.assetPath;

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
  }) async {
    if (leaveListeningRoomSession && ListeningRoomSession.instance.active) {
      ListeningRoomSession.instance.end();
    }
    _currentTrack = track;
    _activeQueue = _normalizeQueue(track, queue);
    notifyListeners();
    String? artUri;
    if (track.coverBytes != null && track.coverBytes!.isNotEmpty) {
      artUri = await _coverBytesToFileUri(track.coverBytes!);
    }
    final path = playablePath(track);
    final queueMaps = queue?.map((t) => {
      'path': playablePath(t),
      'itemId': t.assetPath,
      'title': t.title,
      'artist': t.artist,
      'artPath': t.coverFallbackPath,
    }).toList();
    await _handler.customAction('playAsset', {
      'path': path,
      'itemId': track.assetPath,
      'title': track.title,
      'artist': track.artist,
      'artPath': track.coverFallbackPath,
      'artUri': artUri,
      if (queueMaps?.isNotEmpty ?? false) 'queue': queueMaps,
    });
  }

  List<Track> _normalizeQueue(Track track, List<Track>? queue) {
    if (queue == null || queue.isEmpty) return [track];
    final hasTrack = queue.any((e) => playablePath(e) == playablePath(track));
    if (hasTrack) return List<Track>.from(queue);
    return [track, ...queue];
  }

  Future<void> _applyQueueKeepingCurrent(List<Track> nextQueue) async {
    final current = _currentTrack;
    if (current == null || nextQueue.isEmpty) {
      _activeQueue = nextQueue;
      notifyListeners();
      return;
    }
    final resumeAt = position;
    final wasPlaying = isPlaying;
    await playTrack(current, queue: nextQueue, leaveListeningRoomSession: false);
    if (resumeAt > Duration.zero) {
      await seek(resumeAt);
    }
    if (!wasPlaying) {
      await pause();
    }
  }

  Future<void> removeFromQueue(String assetPath) async {
    if (_activeQueue.isEmpty) return;
    final nextQueue = _activeQueue.where((e) => e.assetPath != assetPath).toList();
    if (nextQueue.length == _activeQueue.length) return;
    if (nextQueue.isEmpty) {
      await stop();
      _activeQueue = const [];
      notifyListeners();
      return;
    }

    final current = _currentTrack;
    if (current != null && current.assetPath == assetPath) {
      await playTrack(nextQueue.first, queue: nextQueue, leaveListeningRoomSession: false);
      return;
    }
    await _applyQueueKeepingCurrent(nextQueue);
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
    final insertAt = currentIndex == -1 ? 0 : (currentIndex + 1).clamp(0, updated.length);
    updated.insert(insertAt, item);
    await _applyQueueKeepingCurrent(updated);
  }

  Future<void> addToQueue(Track track) async {
    final updated = List<Track>.from(_activeQueue);
    if (updated.any((e) => playablePath(e) == playablePath(track))) return;
    updated.add(track);
    if (_currentTrack == null) {
      await playTrack(track, queue: updated, leaveListeningRoomSession: false);
      return;
    }
    await _applyQueueKeepingCurrent(updated);
  }

  /// UX-заглушка скачивания: имитирует загрузку и помечает трек как закешированный.
  Future<void> cacheTrackMock(Track track) async {
    final path = playablePath(track);
    if (path.isEmpty || _downloadedPaths.contains(path) || _downloadingPaths.contains(path)) {
      return;
    }
    _downloadingPaths.add(path);
    notifyListeners();
    _downloadTimers[path]?.cancel();
    _downloadTimers[path] = Timer(const Duration(seconds: 2), () {
      _downloadingPaths.remove(path);
      _downloadedPaths.add(path);
      _downloadTimers.remove(path);
      notifyListeners();
    });
  }

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
    if (_handler.playbackState.value.playing) {
      await _handler.pause();
    } else {
      await _handler.play();
    }
    notifyListeners();
  }

  Future<void> play() async {
    await _handler.play();
    notifyListeners();
  }

  Future<void> pause() async {
    await _handler.pause();
    notifyListeners();
  }

  Future<void> seek(Duration position) async {
    await _handler.seek(position);
    notifyListeners();
  }

  Future<void> stop() async {
    await _handler.stop();
    _currentTrack = null;
    _position = Duration.zero;
    _duration = null;
    _isPlaying = false;
    notifyListeners();
  }

  Future<void> skipToNext() async {
    await _handler.skipToNext();
  }

  Future<void> skipToPrevious() async {
    await _handler.skipToPrevious();
  }

  Future<void> toggleLike() async {
    await _handler.customAction('like');
  }

  /// Лайк/снятие лайка по пути воспроизведения (для строк списков, не только текущий трек).
  Future<void> toggleLikePath(String path) async {
    if (path.isEmpty) return;
    await _handler.customAction('toggleLikePath', {'path': path});
  }

  Future<void> toggleDislikeCurrent() async {
    await _handler.customAction('toggleDislikeCurrent');
  }

  Future<void> setShuffleEnabled(bool enabled) async {
    await _handler.setShuffleEnabled(enabled);
    notifyListeners();
  }

  Future<void> toggleShuffle() async {
    await setShuffleEnabled(!shuffleEnabled);
  }

  Future<void> cycleLoopMode() async {
    await _handler.cycleLoopMode();
    notifyListeners();
  }

  /// Удаляет трек из избранного по assetPath (для страницы «Любимые»).
  Future<void> removeFromFavorites(String assetPath) async {
    await _handler.customAction('dislike', {'path': assetPath});
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
    for (final timer in _downloadTimers.values) {
      timer.cancel();
    }
    _downloadTimers.clear();
    _handler.likedPathsNotifier.removeListener(_onLikedPathsChanged);
    _handler.dislikedPathsNotifier.removeListener(_onLikedPathsChanged);
    _handler.shuffleModeNotifier.removeListener(_onLikedPathsChanged);
    _handler.loopModeNotifier.removeListener(_onLikedPathsChanged);
    _playbackStateSub?.cancel();
    _mediaItemSub?.cancel();
    super.dispose();
  }
}
