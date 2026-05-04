import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../history/listening_history_repository.dart';
import '../platform/platform.dart';
import '../settings/settings_repository.dart';
import '../social/listening_room_session.dart';
import 'local_tracks.dart';

/// Конфигурация для [MiMusicAudioHandler]. Задаётся до [AudioService.init].
SettingsRepository? _handlerSettingsRepository;

void setMiMusicHandlerSettingsRepository(SettingsRepository? repo) {
  _handlerSettingsRepository = repo;
}

ListeningHistoryRepository? _listeningHistoryRepository;

/// Задаётся после [AudioService.init]; запись истории при старте трека.
void setListeningHistoryRepository(ListeningHistoryRepository? repo) {
  _listeningHistoryRepository = repo;
}

/// Обработчик аудио для audio_service: воспроизведение через just_audio,
/// уведомление в шторке (Android) и Control Center (iOS) с управлением.
class MiMusicAudioHandler extends BaseAudioHandler with SeekHandler {
  MiMusicAudioHandler() {
    _initPlayer();
    _listenToPlayer();
    _likedPaths.addAll(localTrackAssets);
    likedPathsNotifier.value = Set.from(_likedPaths);
  }

  late final AudioPlayer _player;
  AndroidEqualizer? _androidEqualizer;
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<SequenceState?>? _sequenceStateSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<bool>? _shuffleModeSub;
  StreamSubscription<LoopMode>? _loopModeSub;
  /// На web [positionStream] часто почти не эмитит во время воспроизведения — UI не получает прогресс.
  Timer? _webPositionPoll;

  /// Очередь треков для skip next/previous. Каждый элемент: {path, title, artist?, artPath?}.
  List<Map<String, dynamic>> _queue = [];
  int _queueIndex = 0;
  bool _concatenatingSourceUsed = false;
  final Set<String> _likedPaths = {};
  final Set<String> _dislikedPaths = {};
  /// Уведомляет UI об изменении списка избранных (path).
  final ValueNotifier<Set<String>> likedPathsNotifier = ValueNotifier<Set<String>>({});
  /// Пути с дизлайком (не показывать в реках / скрыть из избранного).
  final ValueNotifier<Set<String>> dislikedPathsNotifier =
      ValueNotifier<Set<String>>({});
  final ValueNotifier<bool> shuffleModeNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<LoopMode> loopModeNotifier =
      ValueNotifier<LoopMode>(LoopMode.off);

  void _initPlayer() {
    if (kIsWeb || !isAndroid) {
      _player = AudioPlayer();
    } else {
      final eq = AndroidEqualizer();
      _player = AudioPlayer(
        audioPipeline: AudioPipeline(androidAudioEffects: [eq]),
      );
      _androidEqualizer = eq;
      // Включается после применения настроек; при плоской кривой остаётся выкл. (меньше окраски/артефактов).
      eq.setEnabled(false);
    }
  }

  void _listenToPlayer() {
    _playerStateSub = _player.playerStateStream.listen(_onPlayerStateChanged);
    _positionSub = _player.positionStream.listen(_onPositionChanged);
    _sequenceStateSub = _player.sequenceStateStream.listen(_onSequenceStateChanged);
    _durationSub = _player.durationStream.listen(_onDurationResolved);
    _shuffleModeSub = _player.shuffleModeEnabledStream.listen((enabled) {
      shuffleModeNotifier.value = enabled;
    });
    _loopModeSub = _player.loopModeStream.listen((mode) {
      loopModeNotifier.value = mode;
    });
  }

  void _onDurationResolved(Duration? d) {
    if (d == null) return;
    final item = mediaItem.value;
    if (item == null) return;
    if (item.duration == d) return;
    mediaItem.add(item.copyWith(duration: d));
  }

  void _onPlayerStateChanged(PlayerState state) {
    final processingState = _mapProcessingState(state.processingState);
    playbackState.add(playbackState.value.copyWith(
      controls: _currentControls(),
      systemActions: _systemActions,
      androidCompactActionIndices: _compactIndices,
      processingState: processingState,
      playing: state.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
    ));
    _syncWebPositionPoll();
    if (state.processingState == ProcessingState.completed) {
      _stopWebPositionPoll();
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.completed,
        playing: false,
        controls: _currentControls(),
        systemActions: _systemActions,
        androidCompactActionIndices: _compactIndices,
      ));
    }
  }

  AudioProcessingState _mapProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  static final MediaControl _dislikeControl = MediaControl.custom(
    androidIcon: 'drawable/ic_dislike',
    label: 'Дизлайк',
    name: 'dislike',
  );

  static final MediaControl _likeControl = MediaControl.custom(
    androidIcon: 'drawable/ic_favorite',
    label: 'Лайк',
    name: 'like',
  );

  static const _systemActions = {MediaAction.seek};
  bool get _roomGuest =>
      ListeningRoomSession.instance.active &&
      !ListeningRoomSession.instance.isHost;
  bool get _canUseSkipControls =>
      !_roomGuest || ListeningRoomSession.instance.canControlSkip;
  bool get _canUseSeekControl =>
      !_roomGuest || ListeningRoomSession.instance.canControlSeek;

  List<MediaControl> _currentControls() {
    final playing = _player.playing;
    final playPause = playing ? MediaControl.pause : MediaControl.play;
    final controls = <MediaControl>[
      _dislikeControl,
      playPause,
      _likeControl,
    ];
    if (_canUseSkipControls) {
      controls.insert(1, MediaControl.skipToPrevious);
      controls.insert(3, MediaControl.skipToNext);
    }
    return controls;
  }

  /// Компактный вид: первые три доступные кнопки.
  static const _compactIndices = [0, 1, 2];

  void _onSequenceStateChanged(SequenceState? state) {
    final idx = state?.currentIndex ?? 0;
    if (idx != _queueIndex && idx >= 0 && idx < _queue.length) {
      _queueIndex = idx;
      _updateMediaItemFromQueue();
    }
  }

  void _onPositionChanged(Duration position) {
    if (!_player.playing) return;
    if (kIsWeb) return;
    playbackState.add(playbackState.value.copyWith(
      updatePosition: position,
      systemActions: _systemActions,
    ));
  }

  void _syncWebPositionPoll() {
    if (!kIsWeb) return;
    if (_player.playing) {
      _webPositionPoll ??= Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (!_player.playing) {
          _stopWebPositionPoll();
          return;
        }
        final v = playbackState.value;
        playbackState.add(v.copyWith(
          updatePosition: _player.position,
          bufferedPosition: _player.bufferedPosition,
          systemActions: _systemActions,
        ));
      });
    } else {
      _stopWebPositionPoll();
    }
  }

  void _stopWebPositionPoll() {
    _webPositionPoll?.cancel();
    _webPositionPoll = null;
  }

  @override
  Future<void> play() async {
    await _player.play();
    playbackState.add(playbackState.value.copyWith(
      playing: true,
      controls: _currentControls(),
      systemActions: _systemActions,
      androidCompactActionIndices: _compactIndices,
      updatePosition: _player.position,
    ));
  }

  @override
  Future<void> pause() async {
    await _player.pause();
    playbackState.add(playbackState.value.copyWith(
      playing: false,
      controls: _currentControls(),
      systemActions: _systemActions,
      androidCompactActionIndices: _compactIndices,
      updatePosition: _player.position,
    ));
  }

  @override
  Future<void> stop() async {
    _stopWebPositionPoll();
    await _player.stop();
    _concatenatingSourceUsed = false;
    mediaItem.add(null);
    playbackState.add(playbackState.value.copyWith(
      processingState: AudioProcessingState.idle,
      playing: false,
      controls: [],
      updatePosition: Duration.zero,
    ));
  }

  @override
  Future<void> seek(Duration position) async {
    if (!_canUseSeekControl) return;
    await _player.seek(position);
    playbackState.add(playbackState.value.copyWith(
      updatePosition: position,
      systemActions: _systemActions,
      androidCompactActionIndices: _compactIndices,
    ));
  }

  @override
  Future<void> skipToNext() async {
    if (!_canUseSkipControls) return;
    if (_queue.isEmpty) return;
    if (_useConcatenatingSource) {
      if (_queueIndex < _queue.length - 1) {
        await _player.seekToNext();
        _queueIndex = _player.currentIndex ?? _queueIndex + 1;
      } else {
        await _player.seek(Duration.zero, index: 0);
        _queueIndex = 0;
      }
      await _updateMediaItemFromQueue();
      return;
    }
    if (_queueIndex >= _queue.length - 1) {
      _queueIndex = 0;
    } else {
      _queueIndex++;
    }
    await _playFromQueue();
  }

  @override
  Future<void> skipToPrevious() async {
    if (!_canUseSkipControls) return;
    if (_queue.isEmpty) return;
    if (_player.position.inSeconds > 3) {
      await _player.seek(Duration.zero);
      playbackState.add(playbackState.value.copyWith(
        updatePosition: Duration.zero,
        systemActions: _systemActions,
      ));
      return;
    }
    if (_useConcatenatingSource && _queueIndex > 0) {
      await _player.seekToPrevious();
      _queueIndex = _player.currentIndex ?? _queueIndex - 1;
      await _updateMediaItemFromQueue();
      return;
    }
    if (_queueIndex <= 0) {
      _queueIndex = 0;
      await _player.seek(Duration.zero);
      playbackState.add(playbackState.value.copyWith(
        updatePosition: Duration.zero,
        systemActions: _systemActions,
      ));
      return;
    }
    _queueIndex--;
    await _playFromQueue();
  }

  bool get _useConcatenatingSource =>
      _queue.length > 1 && _concatenatingSourceUsed;

  void _recordListeningHistoryFromQueue() {
    final repo = _listeningHistoryRepository;
    if (repo == null) return;
    if (_queue.isEmpty || _queueIndex < 0 || _queueIndex >= _queue.length) {
      return;
    }
    final t = _queue[_queueIndex];
    final path = t['path'] as String? ?? '';
    if (path.isEmpty) return;
    final stableId = (t['itemId'] as String?)?.trim();
    repo.recordPlayback(
      playablePath: (stableId != null && stableId.isNotEmpty) ? stableId : path,
      title: t['title'] as String? ?? '',
      artist: t['artist'] as String?,
      coverAssetPath: t['artPath'] as String?,
    );
  }

  Future<void> _updateMediaItemFromQueue() async {
    if (_queueIndex < 0 || _queueIndex >= _queue.length) return;
    final t = _queue[_queueIndex];
    final path = t['path'] as String? ?? '';
    final itemId = (t['itemId'] as String?)?.trim();
    final mediaId = (itemId != null && itemId.isNotEmpty) ? itemId : path;
    final artPath = t['artPath'] as String?;
    Uri? coverUri = await _coverUriFromPath(
      artPath: artPath,
      artUri: t['artUri'] as String?,
    );
    final duration = _player.duration ?? Duration.zero;
    mediaItem.add(MediaItem(
      id: mediaId,
      title: t['title'] as String? ?? '',
      artist: t['artist'] as String? ?? '',
      duration: duration,
      artUri: coverUri,
    ));
    playbackState.add(playbackState.value.copyWith(
      controls: _currentControls(),
      systemActions: _systemActions,
      androidCompactActionIndices: _compactIndices,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
    ));
    _recordListeningHistoryFromQueue();
  }

  Future<void> _playFromQueue() async {
    if (_queueIndex < 0 || _queueIndex >= _queue.length) return;
    final t = _queue[_queueIndex];
    await _playAsset(
      path: t['path'] as String? ?? '',
      title: t['title'] as String? ?? '',
      artist: t['artist'] as String?,
      artPath: t['artPath'] as String?,
      artUri: t['artUri'] as String?,
      mediaItemId: t['itemId'] as String?,
      queue: _queue,
    );
  }

  String? get currentPlayablePath {
    if (_queue.isEmpty || _queueIndex < 0 || _queueIndex >= _queue.length) {
      return null;
    }
    final row = _queue[_queueIndex];
    final id = (row['itemId'] as String?)?.trim();
    if (id != null && id.isNotEmpty) return id;
    final p = row['path'] as String?;
    if (p == null || p.isEmpty) return null;
    return p;
  }

  bool get hasMultiTrackQueue => _queue.length > 1;

  void _toggleLike() {
    final path = currentPlayablePath;
    if (path == null) return;
    _toggleLikePath(path);
  }

  void _toggleLikePath(String path) {
    if (path.isEmpty) return;
    if (_likedPaths.contains(path)) {
      _likedPaths.remove(path);
    } else {
      _likedPaths.add(path);
      _dislikedPaths.remove(path);
    }
    likedPathsNotifier.value = Set.from(_likedPaths);
    dislikedPathsNotifier.value = Set.from(_dislikedPaths);
    playbackState.add(playbackState.value.copyWith(
      controls: _currentControls(),
      systemActions: _systemActions,
      androidCompactActionIndices: _compactIndices,
    ));
  }

  void _toggleDislikeCurrent() {
    final path = currentPlayablePath;
    if (path == null) return;
    if (_dislikedPaths.contains(path)) {
      _dislikedPaths.remove(path);
    } else {
      _dislikedPaths.add(path);
      _likedPaths.remove(path);
    }
    likedPathsNotifier.value = Set.from(_likedPaths);
    dislikedPathsNotifier.value = Set.from(_dislikedPaths);
    playbackState.add(playbackState.value.copyWith(
      controls: _currentControls(),
      systemActions: _systemActions,
      androidCompactActionIndices: _compactIndices,
    ));
  }

  void _removeLike([String? path]) {
    final p = path ?? currentPlayablePath;
    if (p != null && p.isNotEmpty) {
      _likedPaths.remove(p);
      likedPathsNotifier.value = Set.from(_likedPaths);
    }
    playbackState.add(playbackState.value.copyWith(
      controls: _currentControls(),
      systemActions: _systemActions,
      androidCompactActionIndices: _compactIndices,
    ));
  }

  /// Перемешивание очереди (только при очереди из нескольких треков).
  Future<void> setShuffleEnabled(bool enabled) async {
    if (_queue.length < 2) return;
    try {
      await _player.setShuffleModeEnabled(enabled);
    } catch (_) {}
  }

  /// Цикл: без повтора → весь плейлист → один трек → выкл.
  Future<void> cycleLoopMode() async {
    try {
      final next = switch (_player.loopMode) {
        LoopMode.off => LoopMode.all,
        LoopMode.all => LoopMode.one,
        LoopMode.one => LoopMode.off,
      };
      await _player.setLoopMode(next);
    } catch (_) {}
  }

  static Future<Uri?> _assetToFileUri(String assetPath) =>
      assetToFileUri(assetPath);

  static bool _isLocalFilePath(String path) {
    if (path.startsWith('/')) return true;
    if (path.length >= 2 && path[1] == ':') return true;
    return false;
  }

  Future<Uri?> _coverUriFromPath({
    String? artPath,
    String? artUri,
  }) async {
    if (artUri != null && artUri.isNotEmpty) {
      return Uri.tryParse(artUri);
    }
    if (artPath == null || artPath.isEmpty) return null;
    if (artPath.startsWith('http://') || artPath.startsWith('https://')) {
      return Uri.tryParse(artPath);
    }
    if (_isLocalFilePath(artPath)) {
      return Uri.file(artPath);
    }
    if (artPath.startsWith('assets/')) {
      return _assetToFileUri(artPath);
    }
    return null;
  }

  /// Воспроизвести трек из assets. Вызывается из UI через customAction.
  /// artPath — путь к обложке в assets; копируется в temp для artUri в уведомлении.
  /// artUri — готовый file URI (если передан из UI).
  /// queue — опциональная очередь для skip next/previous.
  Future<void> _playAsset({
    required String path,
    required String title,
    String? artist,
    String? artPath,
    String? artUri,
    String? mediaItemId,
    List<Map<String, dynamic>>? queue,
  }) async {
    if (queue != null && queue.isNotEmpty) {
      _queue = queue;
      _queueIndex = _queue.indexWhere((t) => (t['path'] as String?) == path);
      if (_queueIndex < 0) _queueIndex = 0;
    } else {
      _queue = [
        {
          'path': path,
          'title': title,
          'artist': artist,
          'artPath': artPath,
          'artUri': artUri,
          if (mediaItemId != null && mediaItemId.trim().isNotEmpty)
            'itemId': mediaItemId.trim(),
        },
      ];
      _queueIndex = 0;
    }
    Uri? coverUri = await _coverUriFromPath(artPath: artPath, artUri: artUri);
    final resolvedMediaId = () {
      final trimmed = mediaItemId?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
      if (_queueIndex >= 0 && _queueIndex < _queue.length) {
        final id = (_queue[_queueIndex]['itemId'] as String?)?.trim();
        if (id != null && id.isNotEmpty) return id;
      }
      return path;
    }();
    final item = MediaItem(
      id: resolvedMediaId,
      title: title,
      artist: artist ?? '',
      artUri: coverUri,
    );
    mediaItem.add(item);
    playbackState.add(playbackState.value.copyWith(
      controls: _currentControls(),
      systemActions: _systemActions,
      androidCompactActionIndices: _compactIndices,
      processingState: AudioProcessingState.loading,
      playing: false,
      updatePosition: Duration.zero,
    ));

    try {
      if (queue != null && queue.length > 1) {
        final sources = queue
            .map((t) => createAudioSource(t['path'] as String? ?? ''))
            .toList();
        await _player.setAudioSource(
          ConcatenatingAudioSource(children: sources),
          initialIndex: _queueIndex,
          initialPosition: Duration.zero,
        );
        _concatenatingSourceUsed = true;
      } else {
        await _player.setAudioSource(createAudioSource(path));
        _concatenatingSourceUsed = false;
        try {
          await _player.setShuffleModeEnabled(false);
        } catch (_) {}
      }
      await _applyEqualizerFromSettings();
      final duration = _player.duration ?? Duration.zero;
      mediaItem.add(MediaItem(
        id: item.id,
        title: item.title,
        artist: item.artist,
        duration: duration,
        artUri: coverUri,
      ));
      await _player.play();
      playbackState.add(playbackState.value.copyWith(
        controls: _currentControls(),
        systemActions: _systemActions,
        androidCompactActionIndices: _compactIndices,
        processingState: AudioProcessingState.ready,
        playing: true,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
      ));
      _recordListeningHistoryFromQueue();
    } catch (e) {
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.error,
        playing: false,
        systemActions: _systemActions,
        androidCompactActionIndices: _compactIndices,
      ));
      rethrow;
    }
  }

  /// «Басс-буст» распределяем по двум нижним полосам, чтобы один пиковый фильтр не перегружал сигнал.
  /// При нулевых полосах и преампе DSP отключается (меньше шумов/искажений на части устройств).
  Future<void> _syncAndroidEqualizer(List<double> gains, double preamp) async {
    final eq = _androidEqualizer;
    if (eq == null) return;
    try {
      final params = await eq.parameters;
      final bands = params.bands;
      final n = bands.length;
      var flat = preamp.abs() < 0.05;
      for (var i = 0; i < n && flat; i++) {
        final g = i < gains.length ? gains[i] : 0.0;
        if (g.abs() >= 0.05) flat = false;
      }
      await eq.setEnabled(!flat);
      if (flat) return;

      for (var i = 0; i < n; i++) {
        var gain = i < gains.length ? gains[i] : 0.0;
        if (n >= 2) {
          if (i == 0) gain += preamp * 0.55;
          if (i == 1) gain += preamp * 0.45;
        } else if (i == 0) {
          gain += preamp;
        }
        await bands[i].setGain(gain.clamp(params.minDecibels, params.maxDecibels));
      }
    } catch (_) {}
  }

  Future<void> _applyEqualizerFromSettings() async {
    final repo = _handlerSettingsRepository;
    if (repo == null) return;
    try {
      final settings = await repo.getSettings();
      await _syncAndroidEqualizer(settings.equalizerGains, settings.equalizerPreamp);
    } catch (_) {}
  }

  Future<void> _applyEqualizerGains(List<double> gains) async {
    final repo = _handlerSettingsRepository;
    if (repo == null) return;
    try {
      final settings = await repo.getSettings();
      await _syncAndroidEqualizer(gains, settings.equalizerPreamp);
    } catch (_) {}
  }

  @override
  Future<dynamic> customAction(String name, [Map<String, dynamic>? extras]) async {
    switch (name) {
      case 'playAsset':
        final path = extras?['path'] as String? ?? '';
        final title = extras?['title'] as String? ?? '';
        final artist = extras?['artist'] as String?;
        final artPath = extras?['artPath'] as String?;
        final queueList = extras?['queue'];
        List<Map<String, dynamic>>? queue;
        if (queueList is List) {
          queue = queueList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
        await _playAsset(
          path: path,
          title: title,
          artist: artist,
          artPath: artPath,
          artUri: extras?['artUri'] as String?,
          mediaItemId: extras?['itemId'] as String?,
          queue: queue,
        );
        break;
      case 'like':
        _toggleLike();
        break;
      case 'toggleLikePath':
        _toggleLikePath(extras?['path'] as String? ?? '');
        break;
      case 'toggleDislikeCurrent':
        _toggleDislikeCurrent();
        break;
      case 'dislike':
        _removeLike(extras?['path'] as String?);
        break;
      case 'applyEqualizer':
        final gainsList = extras?['gains'];
        if (gainsList is List) {
          final gains = gainsList.map((e) => (e as num).toDouble()).toList();
          await _applyEqualizerGains(gains);
        }
        break;
      default:
        return super.customAction(name, extras);
    }
  }

  @override
  Future<void> onTaskRemoved() async {
    await stop();
    await super.onTaskRemoved();
  }

  Future<void> disposeHandler() async {
    _stopWebPositionPoll();
    await _playerStateSub?.cancel();
    await _positionSub?.cancel();
    await _sequenceStateSub?.cancel();
    await _durationSub?.cancel();
    await _shuffleModeSub?.cancel();
    await _loopModeSub?.cancel();
    await _player.dispose();
  }
}
