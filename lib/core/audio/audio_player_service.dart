import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../settings/settings_repository.dart';
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

  /// Путь текущего трека в очереди (как в плеере).
  String? get currentPlayablePath => _handler.currentPlayablePath;

  bool isPathLiked(String path) =>
      path.isNotEmpty && likedPaths.contains(path);

  bool isPathDisliked(String path) =>
      path.isNotEmpty && dislikedPaths.contains(path);

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
        _currentTrack = _mediaItemToTrack(item);
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

  /// Путь для воспроизведения: файл (если загружен в студии) или asset.
  static String playablePath(Track t) => t.audioFilePath ?? t.assetPath;

  /// Загружает и воспроизводит трек. Показывает медиа-уведомление на Android/iOS.
  /// [queue] — очередь для кнопок предыдущий/следующий в уведомлении.
  Future<void> playTrack(Track track, {List<Track>? queue}) async {
    _currentTrack = track;
    notifyListeners();
    String? artUri;
    if (track.coverBytes != null && track.coverBytes!.isNotEmpty) {
      artUri = await _coverBytesToFileUri(track.coverBytes!);
    }
    final path = playablePath(track);
    final queueMaps = queue?.map((t) => {
      'path': playablePath(t),
      'title': t.title,
      'artist': t.artist,
      'artPath': t.coverFallbackPath,
    }).toList();
    await _handler.customAction('playAsset', {
      'path': path,
      'title': track.title,
      'artist': track.artist,
      'artPath': track.coverFallbackPath,
      if (artUri != null) 'artUri': artUri,
      if (queueMaps != null && queueMaps.isNotEmpty) 'queue': queueMaps,
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
    _handler.likedPathsNotifier.removeListener(_onLikedPathsChanged);
    _handler.dislikedPathsNotifier.removeListener(_onLikedPathsChanged);
    _handler.shuffleModeNotifier.removeListener(_onLikedPathsChanged);
    _handler.loopModeNotifier.removeListener(_onLikedPathsChanged);
    _playbackStateSub?.cancel();
    _mediaItemSub?.cancel();
    super.dispose();
  }
}
