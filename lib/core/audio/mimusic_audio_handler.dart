import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../history/listening_history_repository.dart';
import '../platform/platform.dart';
import '../settings/settings_repository.dart';
import '../social/listening_room_session.dart';
import 'mimusic_ios_remote_commands.dart';

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

ListeningHistoryRepository? get listeningHistoryRepository =>
    _listeningHistoryRepository;

Future<void> Function()? _remoteOnLike;
Future<void> Function()? _remoteOnDislike;

/// Колбэки из [AudioPlayerService]: лайк/дизлайк из системного плеера с синхронизацией API.
void setMiMusicHandlerRemoteActions({
  Future<void> Function()? onLike,
  Future<void> Function()? onDislike,
}) {
  _remoteOnLike = onLike;
  _remoteOnDislike = onDislike;
}

/// Обработчик аудио для audio_service: воспроизведение через just_audio,
/// уведомление в шторке (Android) и Control Center (iOS) с управлением.
class MiMusicAudioHandler extends BaseAudioHandler with SeekHandler {
  MiMusicAudioHandler() : this._fromCreated(_createPlayer());

  MiMusicAudioHandler._fromCreated(
    ({AudioPlayer player, AndroidEqualizer? equalizer}) created,
  )   : _player = created.player,
        _androidEqualizer = created.equalizer {
    _listenToPlayer();
    ListeningRoomSession.instance.addListener(_onRoomSessionChanged);
    likedPathsNotifier.value = Set.from(_likedPaths);
    playbackState.add(
      playbackState.value.copyWith(
        controls: _currentControls(),
        systemActions: _systemActions,
        androidCompactActionIndices: _compactIndicesFor(_currentControls()),
        processingState: AudioProcessingState.idle,
        speed: 1.0,
      ),
    );
  }

  final AudioPlayer _player;
  final AndroidEqualizer? _androidEqualizer;
  bool _handlerDisposed = false;
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<SequenceState?>? _sequenceStateSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<bool>? _shuffleModeSub;
  StreamSubscription<LoopMode>? _loopModeSub;

  /// Не дублировать запись в историю при pause→play того же трека.
  String? _lastHistoryRecordedKey;

  /// Синхронизация с [AudioPlayerService.playTrack], чтобы не дублировать запись.
  void markListeningHistoryRecorded(String key) {
    if (key.isEmpty) return;
    _lastHistoryRecordedKey = key;
  }

  /// На web [positionStream] часто почти не эмитит во время воспроизведения — UI не получает прогресс.
  Timer? _webPositionPoll;

  /// Очередь треков для skip next/previous. Каждый элемент: {path, title, artist?, artPath?}.
  List<Map<String, dynamic>> _queue = [];
  int _queueIndex = 0;
  bool _concatenatingSourceUsed = false;
  final Set<String> _likedPaths = {};
  final Set<String> _dislikedPaths = {};

  /// Уведомляет UI об изменении списка избранных (path).
  final ValueNotifier<Set<String>> likedPathsNotifier =
      ValueNotifier<Set<String>>({});

  /// Пути с дизлайком (не показывать в реках / скрыть из избранного).
  final ValueNotifier<Set<String>> dislikedPathsNotifier =
      ValueNotifier<Set<String>>({});
  final ValueNotifier<bool> shuffleModeNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<LoopMode> loopModeNotifier = ValueNotifier<LoopMode>(
    LoopMode.off,
  );

  static ({AudioPlayer player, AndroidEqualizer? equalizer}) _createPlayer() {
    if (kIsWeb || !isAndroid) {
      return (player: AudioPlayer(), equalizer: null);
    }
    try {
      final eq = AndroidEqualizer();
      final player = AudioPlayer(
        audioPipeline: AudioPipeline(androidAudioEffects: [eq]),
      );
      // Включается после применения настроек; при плоской кривой остаётся выкл.
      eq.setEnabled(false);
      return (player: player, equalizer: eq);
    } catch (_) {
      return (player: AudioPlayer(), equalizer: null);
    }
  }

  bool get _canRoomSyncPlayer =>
      !_handlerDisposed && (_player.audioSource != null || _queue.isNotEmpty);

  void _listenToPlayer() {
    _playerStateSub = _player.playerStateStream.listen(_onPlayerStateChanged);
    _positionSub = _player.positionStream.listen(_onPositionChanged);
    _sequenceStateSub = _player.sequenceStateStream.listen(
      _onSequenceStateChanged,
    );
    _durationSub = _player.durationStream.listen(_onDurationResolved);
    _shuffleModeSub = _player.shuffleModeEnabledStream.listen((enabled) {
      shuffleModeNotifier.value = enabled;
    });
    _loopModeSub = _player.loopModeStream.listen((mode) {
      loopModeNotifier.value = mode;
    });
  }

  void _onRoomSessionChanged() {
    final current = playbackState.value;
    playbackState.add(
      current.copyWith(
        controls: _currentControls(),
        systemActions: _systemActions,
        androidCompactActionIndices: _compactIndicesFor(_currentControls()),
        speed: 1.0,
      ),
    );
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
    playbackState.add(
      playbackState.value.copyWith(
        controls: _currentControls(),
        systemActions: _systemActions,
        androidCompactActionIndices: _compactIndicesFor(_currentControls()),
        speed: 1.0,
        processingState: processingState,
        playing: state.playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
      ),
    );
    _syncWebPositionPoll();
    if (state.playing && state.processingState == ProcessingState.ready) {
      _recordListeningHistoryOnce();
      _refreshPlatformRemoteCommands();
    }
    if (state.processingState == ProcessingState.completed) {
      _stopWebPositionPoll();
      playbackState.add(
        playbackState.value.copyWith(
          processingState: AudioProcessingState.completed,
          playing: false,
          controls: _currentControls(),
          systemActions: _systemActions,
          androidCompactActionIndices: _compactIndicesFor(_currentControls()),
        speed: 1.0,
        ),
      );
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

  MediaControl _dislikeControlFor(String? likeKey) {
    final active =
        likeKey != null && likeKey.isNotEmpty && _dislikedPaths.contains(likeKey);
    return MediaControl.custom(
      androidIcon:
          active ? 'drawable/ic_dislike_filled' : 'drawable/ic_dislike',
      label: active ? 'Убрать дизлайк' : 'Дизлайк',
      name: active ? 'dislike_on' : 'dislike_off',
    );
  }

  MediaControl _likeControlFor(String? likeKey) {
    final active =
        likeKey != null && likeKey.isNotEmpty && _likedPaths.contains(likeKey);
    return MediaControl.custom(
      androidIcon:
          active ? 'drawable/ic_favorite' : 'drawable/ic_favorite_border',
      label: active ? 'Убрать лайк' : 'Лайк',
      name: active ? 'like_on' : 'like_off',
    );
  }

  static const _systemActions = {
    MediaAction.seek,
    MediaAction.seekForward,
    MediaAction.seekBackward,
    MediaAction.play,
    MediaAction.pause,
    MediaAction.skipToNext,
    MediaAction.skipToPrevious,
  };

  /// Лайк/дизлайк в notification (drawable) — только Android; iOS — [MiMusicIosRemoteCommands].
  static bool get _useAndroidLikeDislikeControls =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
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
      if (_canUseSkipControls) MediaControl.skipToPrevious,
      playPause,
      if (_canUseSkipControls) MediaControl.skipToNext,
    ];
    if (_useAndroidLikeDislikeControls) {
      final likeKey = _currentLikeKey;
      controls.addAll([_dislikeControlFor(likeKey), _likeControlFor(likeKey)]);
    }
    return controls.isEmpty ? [playPause] : controls;
  }

  void _syncHandlerQueue() {
    if (_queue.isEmpty) {
      queue.add(const []);
      return;
    }
    final items = _queue.map((t) {
      final path = t['path'] as String? ?? '';
      final itemId = (t['itemId'] as String?)?.trim();
      final mediaId = (itemId != null && itemId.isNotEmpty) ? itemId : path;
      return MediaItem(
        id: mediaId,
        title: t['title'] as String? ?? '',
        artist: t['artist'] as String?,
      );
    }).toList();
    queue.add(items);
  }

  void _refreshPlatformRemoteCommands() {
    unawaited(MiMusicIosRemoteCommands.refreshIfNeeded());
  }

  /// Компактный вид: prev / play-pause / next (не dislike+skipPrev+play).
  static List<int> _compactIndicesFor(List<MediaControl> controls) {
    if (controls.length <= 3) {
      return List.generate(controls.length, (i) => i);
    }
    final playIdx = controls.indexWhere((c) {
      final a = c.action;
      return a == MediaAction.play || a == MediaAction.pause;
    });
    if (playIdx < 0) {
      return [0, 1, 2].take(controls.length).toList();
    }
    final out = <int>[];
    if (playIdx > 0) out.add(playIdx - 1);
    out.add(playIdx);
    if (playIdx + 1 < controls.length) out.add(playIdx + 1);
    return out;
  }

  void _onSequenceStateChanged(SequenceState? state) {
    final idx = state?.currentIndex ?? 0;
    if (idx != _queueIndex && idx >= 0 && idx < _queue.length) {
      _queueIndex = idx;
      unawaited(_updateMediaItemFromQueue());
      if (_player.playing) {
        _recordListeningHistoryOnce();
      }
    }
  }

  void _onPositionChanged(Duration position) {
    if (kIsWeb) return;
    playbackState.add(
      playbackState.value.copyWith(
        updatePosition: position,
        playing: _player.playing,
        controls: _currentControls(),
        systemActions: _systemActions,
        androidCompactActionIndices: _compactIndicesFor(_currentControls()),
        speed: 1.0,
      ),
    );
  }

  void _syncWebPositionPoll() {
    if (!kIsWeb) return;
    if (_player.playing) {
      _webPositionPoll ??= Timer.periodic(const Duration(milliseconds: 200), (
        _,
      ) {
        if (!_player.playing) {
          _stopWebPositionPoll();
          return;
        }
        final v = playbackState.value;
        playbackState.add(
          v.copyWith(
            updatePosition: _player.position,
            bufferedPosition: _player.bufferedPosition,
            systemActions: _systemActions,
          ),
        );
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
    if (_roomGuest && !ListeningRoomSession.instance.canControlPause) return;
    await _player.play();
    playbackState.add(
      playbackState.value.copyWith(
        playing: true,
        controls: _currentControls(),
        systemActions: _systemActions,
        androidCompactActionIndices: _compactIndicesFor(_currentControls()),
        speed: 1.0,
        updatePosition: _player.position,
      ),
    );
  }

  @override
  Future<void> pause() async {
    if (_roomGuest && !ListeningRoomSession.instance.canControlPause) return;
    await _player.pause();
    playbackState.add(
      playbackState.value.copyWith(
        playing: false,
        controls: _currentControls(),
        systemActions: _systemActions,
        androidCompactActionIndices: _compactIndicesFor(_currentControls()),
        speed: 1.0,
        updatePosition: _player.position,
      ),
    );
  }

  @override
  Future<void> stop() async {
    _stopWebPositionPoll();
    await _player.stop();
    _concatenatingSourceUsed = false;
    _lastHistoryRecordedKey = null;
    mediaItem.add(null);
    playbackState.add(
      playbackState.value.copyWith(
        processingState: AudioProcessingState.idle,
        playing: false,
        controls: [],
        updatePosition: Duration.zero,
      ),
    );
  }

  @override
  Future<void> seek(Duration position) async {
    if (!_canUseSeekControl) return;
    await _player.seek(position);
    playbackState.add(
      playbackState.value.copyWith(
        updatePosition: position,
        systemActions: _systemActions,
        androidCompactActionIndices: _compactIndicesFor(_currentControls()),
        speed: 1.0,
      ),
    );
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
      if (_player.playing) _recordListeningHistoryOnce();
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
      playbackState.add(
        playbackState.value.copyWith(
          updatePosition: Duration.zero,
          systemActions: _systemActions,
        ),
      );
      return;
    }
    if (_useConcatenatingSource && _queueIndex > 0) {
      await _player.seekToPrevious();
      _queueIndex = _player.currentIndex ?? _queueIndex - 1;
      await _updateMediaItemFromQueue();
      if (_player.playing) _recordListeningHistoryOnce();
      return;
    }
    if (_queueIndex <= 0) {
      _queueIndex = 0;
      await _player.seek(Duration.zero);
      playbackState.add(
        playbackState.value.copyWith(
          updatePosition: Duration.zero,
          systemActions: _systemActions,
        ),
      );
      return;
    }
    _queueIndex--;
    await _playFromQueue();
  }

  bool get _useConcatenatingSource =>
      _queue.length > 1 && _concatenatingSourceUsed;

  void _recordListeningHistoryOnce() {
    final repo = _listeningHistoryRepository;
    if (repo == null) return;
    if (_queue.isEmpty || _queueIndex < 0 || _queueIndex >= _queue.length) {
      return;
    }
    final t = _queue[_queueIndex];
    final path = t['path'] as String? ?? '';
    if (path.isEmpty) return;
    final stableId = (t['itemId'] as String?)?.trim();
    final key = (stableId != null && stableId.isNotEmpty) ? stableId : path;
    if (key == _lastHistoryRecordedKey) return;
    _lastHistoryRecordedKey = key;
    repo.recordPlayback(
      playablePath: key,
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
    mediaItem.add(
      MediaItem(
        id: mediaId,
        title: t['title'] as String? ?? '',
        artist: t['artist'] as String? ?? '',
        duration: duration,
        artUri: coverUri,
      ),
    );
    playbackState.add(
      playbackState.value.copyWith(
        controls: _currentControls(),
        systemActions: _systemActions,
        androidCompactActionIndices: _compactIndicesFor(_currentControls()),
        speed: 1.0,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
      ),
    );
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

  /// Ключ лайка/дизлайка — стабильный id трека (`server_track_N` / assets), не URL потока.
  String? get _currentLikeKey {
    if (_queue.isEmpty || _queueIndex < 0 || _queueIndex >= _queue.length) {
      return null;
    }
    final row = _queue[_queueIndex];
    final itemId = (row['itemId'] as String?)?.trim();
    if (itemId != null && itemId.isNotEmpty) return itemId;
    final p = row['path'] as String? ?? '';
    if (p.isEmpty) return null;
    return p;
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
    final path = _currentLikeKey;
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
    playbackState.add(
      playbackState.value.copyWith(
        controls: _currentControls(),
        systemActions: _systemActions,
        androidCompactActionIndices: _compactIndicesFor(_currentControls()),
        speed: 1.0,
      ),
    );
  }

  void _setLikePath({required String path, required bool liked}) {
    if (path.isEmpty) return;
    if (liked) {
      _likedPaths.add(path);
      _dislikedPaths.remove(path);
    } else {
      _likedPaths.remove(path);
    }
    likedPathsNotifier.value = Set.from(_likedPaths);
    dislikedPathsNotifier.value = Set.from(_dislikedPaths);
    playbackState.add(
      playbackState.value.copyWith(
        controls: _currentControls(),
        systemActions: _systemActions,
        androidCompactActionIndices: _compactIndicesFor(_currentControls()),
        speed: 1.0,
      ),
    );
  }

  void _replaceLikedPaths(Set<String> next) {
    _likedPaths
      ..clear()
      ..addAll(next.where((e) => e.trim().isNotEmpty));
    _dislikedPaths.removeWhere(_likedPaths.contains);
    likedPathsNotifier.value = Set.from(_likedPaths);
    dislikedPathsNotifier.value = Set.from(_dislikedPaths);
    playbackState.add(
      playbackState.value.copyWith(
        controls: _currentControls(),
        systemActions: _systemActions,
        androidCompactActionIndices: _compactIndicesFor(_currentControls()),
        speed: 1.0,
      ),
    );
  }

  void _toggleDislikePath(String path) {
    if (path.isEmpty) return;
    if (_dislikedPaths.contains(path)) {
      _dislikedPaths.remove(path);
    } else {
      _dislikedPaths.add(path);
      _likedPaths.remove(path);
    }
    likedPathsNotifier.value = Set.from(_likedPaths);
    dislikedPathsNotifier.value = Set.from(_dislikedPaths);
    playbackState.add(
      playbackState.value.copyWith(
        controls: _currentControls(),
        systemActions: _systemActions,
        androidCompactActionIndices: _compactIndicesFor(_currentControls()),
        speed: 1.0,
      ),
    );
  }

  void _toggleDislikeCurrent() {
    final path = _currentLikeKey;
    if (path == null) return;
    _toggleDislikePath(path);
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

  Future<Uri?> _coverUriFromPath({String? artPath, String? artUri}) async {
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

  /// Обновить очередь без сброса позиции текущего трека (colisten / правки очереди).
  Future<void> _updateQueuePreserve(Map<String, dynamic>? extras) async {
    final path = extras?['path'] as String? ?? '';
    if (path.isEmpty) return;
    final queueList = extras?['queue'];
    if (queueList is! List || queueList.isEmpty) return;
    final queue = queueList
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final index = queue.indexWhere((t) => (t['path'] as String?) == path);
    if (index < 0) return;
    final positionSeconds = (extras?['positionSeconds'] as num?)?.toDouble();
    final resumeAt = positionSeconds == null
        ? _player.position
        : Duration(milliseconds: (positionSeconds * 1000).round());
    final autoPlay = extras?['autoPlay'] as bool? ?? _player.playing;
    _queue = queue;
    _queueIndex = index;
    final current = queue[index];
    final title = current['title'] as String? ?? '';
    final artist = current['artist'] as String?;
    final artPath = current['artPath'] as String?;
    final artUri = current['artUri'] as String?;
    Uri? coverUri = await _coverUriFromPath(artPath: artPath, artUri: artUri);
    final mediaItemId = (current['itemId'] as String?)?.trim();
    final resolvedMediaId = mediaItemId != null && mediaItemId.isNotEmpty
        ? mediaItemId
        : path;
    final item = MediaItem(
      id: resolvedMediaId,
      title: title,
      artist: artist ?? '',
      artUri: coverUri,
    );
    mediaItem.add(item);
    try {
      if (queue.length > 1) {
        final sources = queue
            .map((t) => createAudioSource(t['path'] as String? ?? ''))
            .toList();
        await _player.setAudioSource(
          ConcatenatingAudioSource(children: sources),
          initialIndex: index,
          initialPosition: resumeAt,
        );
        _concatenatingSourceUsed = true;
      } else {
        await _player.setAudioSource(
          createAudioSource(path),
          initialPosition: resumeAt,
        );
        _concatenatingSourceUsed = false;
      }
      await _applyEqualizerFromSettings();
      final duration = _player.duration ?? Duration.zero;
      mediaItem.add(
        MediaItem(
          id: item.id,
          title: item.title,
          artist: item.artist,
          duration: duration,
          artUri: coverUri,
        ),
      );
      if (autoPlay) {
        await _player.play();
      } else {
        await _player.pause();
      }
      _syncHandlerQueue();
      playbackState.add(
        playbackState.value.copyWith(
          controls: _currentControls(),
          systemActions: _systemActions,
          androidCompactActionIndices: _compactIndicesFor(_currentControls()),
          speed: 1.0,
          processingState: AudioProcessingState.ready,
          playing: autoPlay,
          updatePosition: _player.position,
          bufferedPosition: _player.bufferedPosition,
        ),
      );
      _refreshPlatformRemoteCommands();
    } catch (_) {}
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
    bool autoPlay = true,
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
    playbackState.add(
      playbackState.value.copyWith(
        controls: _currentControls(),
        systemActions: _systemActions,
        androidCompactActionIndices: _compactIndicesFor(_currentControls()),
        speed: 1.0,
        processingState: AudioProcessingState.loading,
        playing: false,
        updatePosition: Duration.zero,
      ),
    );

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
      mediaItem.add(
        MediaItem(
          id: item.id,
          title: item.title,
          artist: item.artist,
          duration: duration,
          artUri: coverUri,
        ),
      );
      if (autoPlay) {
        await _player.play();
      }
      _syncHandlerQueue();
      playbackState.add(
        playbackState.value.copyWith(
          controls: _currentControls(),
          systemActions: _systemActions,
          androidCompactActionIndices: _compactIndicesFor(_currentControls()),
          speed: 1.0,
          processingState: AudioProcessingState.ready,
          playing: autoPlay,
          updatePosition: _player.position,
          bufferedPosition: _player.bufferedPosition,
        ),
      );
      _refreshPlatformRemoteCommands();
    } catch (e) {
      playbackState.add(
        playbackState.value.copyWith(
          processingState: AudioProcessingState.error,
          playing: false,
          systemActions: _systemActions,
          androidCompactActionIndices: _compactIndicesFor(_currentControls()),
        speed: 1.0,
        ),
      );
      rethrow;
    }
  }

  Future<void> setLoopMode(LoopMode mode) async {
    try {
      await _player.setLoopMode(mode);
    } catch (_) {}
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
        await bands[i].setGain(
          gain.clamp(params.minDecibels, params.maxDecibels),
        );
      }
    } catch (_) {}
  }

  Future<void> _applyEqualizerFromSettings() async {
    final repo = _handlerSettingsRepository;
    if (repo == null) return;
    try {
      final settings = await repo.getSettings();
      await _syncAndroidEqualizer(
        settings.equalizerGains,
        settings.equalizerPreamp,
      );
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
  Future<dynamic> customAction(
    String name, [
    Map<String, dynamic>? extras,
  ]) async {
    switch (name) {
      case 'playAsset':
        final path = extras?['path'] as String? ?? '';
        final title = extras?['title'] as String? ?? '';
        final artist = extras?['artist'] as String?;
        final artPath = extras?['artPath'] as String?;
        final queueList = extras?['queue'];
        List<Map<String, dynamic>>? queue;
        if (queueList is List) {
          queue = queueList
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
        await _playAsset(
          path: path,
          title: title,
          artist: artist,
          artPath: artPath,
          artUri: extras?['artUri'] as String?,
          mediaItemId: extras?['itemId'] as String?,
          queue: queue,
          autoPlay: extras?['autoPlay'] as bool? ?? true,
        );
        break;
      case 'like':
      case 'like_on':
      case 'like_off':
        if (_remoteOnLike != null) {
          await _remoteOnLike!();
        } else {
          _toggleLike();
        }
        break;
      case 'toggleLikePath':
        _toggleLikePath(extras?['path'] as String? ?? '');
        break;
      case 'setLikePath':
        _setLikePath(
          path: extras?['path'] as String? ?? '',
          liked: extras?['liked'] as bool? ?? false,
        );
        break;
      case 'replaceLikedPaths':
        final raw = extras?['paths'];
        final next = raw is List
            ? raw.map((e) => e.toString()).toSet()
            : <String>{};
        _replaceLikedPaths(next);
        break;
      case 'toggleDislikeCurrent':
        _toggleDislikeCurrent();
        break;
      case 'dislike':
      case 'dislike_on':
      case 'dislike_off':
        final dislikePath = extras?['path'] as String?;
        if (dislikePath != null && dislikePath.isNotEmpty) {
          _toggleDislikePath(dislikePath);
        } else if (_remoteOnDislike != null) {
          await _remoteOnDislike!();
        } else {
          _toggleDislikeCurrent();
        }
        break;
      case 'applyEqualizer':
        final gainsList = extras?['gains'];
        if (gainsList is List) {
          final gains = gainsList.map((e) => (e as num).toDouble()).toList();
          await _applyEqualizerGains(gains);
        }
        break;
      case 'roomSyncSeek':
        await _roomSyncSeek(extras);
        break;
      case 'roomSyncPlay':
        await _roomSyncPlay();
        break;
      case 'roomSyncPause':
        await _roomSyncPause();
        break;
      case 'updateQueuePreserve':
        await _updateQueuePreserve(extras);
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

  Future<void> _roomSyncSeek(Map<String, dynamic>? extras) async {
    if (!_canRoomSyncPlayer) return;
    try {
      final seconds = (extras?['positionSeconds'] as num?)?.toDouble();
      if (seconds == null) return;
      final position = Duration(milliseconds: (seconds * 1000).round());
      await _player.seek(position);
      playbackState.add(
        playbackState.value.copyWith(
          updatePosition: position,
          systemActions: _systemActions,
          androidCompactActionIndices: _compactIndicesFor(_currentControls()),
        speed: 1.0,
        ),
      );
    } catch (e, st) {
      debugPrint('[colisten] roomSyncSeek skipped: $e\n$st');
    }
  }

  Future<void> _roomSyncPlay() async {
    if (!_canRoomSyncPlayer) return;
    try {
      await _player.play();
      playbackState.add(
        playbackState.value.copyWith(
          playing: true,
          controls: _currentControls(),
          systemActions: _systemActions,
          androidCompactActionIndices: _compactIndicesFor(_currentControls()),
        speed: 1.0,
          updatePosition: _player.position,
        ),
      );
    } catch (e, st) {
      debugPrint('[colisten] roomSyncPlay skipped: $e\n$st');
    }
  }

  Future<void> _roomSyncPause() async {
    if (!_handlerDisposed) {
      try {
        await _player.pause();
        playbackState.add(
          playbackState.value.copyWith(
            playing: false,
            controls: _currentControls(),
            systemActions: _systemActions,
            androidCompactActionIndices: _compactIndicesFor(_currentControls()),
        speed: 1.0,
            updatePosition: _player.position,
          ),
        );
      } catch (e, st) {
        debugPrint('[colisten] roomSyncPause skipped: $e\n$st');
      }
    }
  }

  Future<void> disposeHandler() async {
    _handlerDisposed = true;
    ListeningRoomSession.instance.removeListener(_onRoomSessionChanged);
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
