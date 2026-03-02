import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
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

  void _listenToHandler() {
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

  Track _mediaItemToTrack(MediaItem item) {
    return Track(
      assetPath: item.id,
      title: item.title,
      artist: item.artist,
    );
  }

  /// Загружает и воспроизводит трек. Показывает медиа-уведомление на Android/iOS.
  /// [queue] — очередь для кнопок предыдущий/следующий в уведомлении.
  Future<void> playTrack(Track track, {List<Track>? queue}) async {
    _currentTrack = track;
    notifyListeners();
    String? artUri;
    if (track.coverBytes != null && track.coverBytes!.isNotEmpty) {
      artUri = await _coverBytesToFileUri(track.coverBytes!);
    }
    final queueMaps = queue?.map((t) => {
      'path': t.assetPath,
      'title': t.title,
      'artist': t.artist,
      'artPath': t.coverFallbackPath,
    }).toList();
    await _handler.customAction('playAsset', {
      'path': track.assetPath,
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
    _playbackStateSub?.cancel();
    _mediaItemSub?.cancel();
    super.dispose();
  }
}
