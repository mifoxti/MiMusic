import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../audio/audio_player_service.dart';
import '../audio/track.dart';
import '../auth/auth_session_store.dart';
import '../network/api_config.dart';
import '../network/colisten_api.dart';
import '../network/tracks_api.dart';
import '../audio/local_tracks.dart';
import 'listening_room_session.dart';

/// WebSocket Colisten: гость подстраивает плеер под состояние комнаты, хост пушит seek/track/play.
class ColistenController {
  ColistenController._();

  static final ColistenController instance = ColistenController._();
  static const bool _debugLogs = bool.fromEnvironment(
    'COLISTEN_DEBUG',
    defaultValue: false,
  );

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _hostTimer;
  Timer? _guestTimer;
  void Function()? _hostListener;
  AudioPlayerService? _hostAudio;

  bool _isHost = false;
  int _guestLastVersion = 0;
  int _guestAppliedVersion = 0;
  Future<void> _guestApplyChain = Future<void>.value();
  int? _hostLastTrackId;
  bool _hostLastPlaying = false;
  List<int> _hostLastQueueTrackIds = const [];
  double _guestTargetPositionSeconds = 0;
  bool _guestTargetPlaying = false;
  int _guestTargetAnchorLocalMs = 0;
  int _guestLastTightSeekAtMs = 0;
  bool _guestNeedsInitialHardSync = false;
  bool _guestNeedsFirstRealtimeHardSync = false;
  Completer<void>? _guestFirstRealtimeStateCompleter;
  String? _roomId;
  List<int> _guestLastQueueTrackIds = const [];
  final Map<int, Track> _trackCache = <int, Track>{};
  Map<String, Track>? _localTrackCacheByAssetPath;

  static String wsUrl(String roomId, String token) {
    final b = ApiConfig.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final wsBase = b.replaceFirst(RegExp(r'^http'), 'ws');
    final t = Uri.encodeQueryComponent(token);
    final r = Uri.encodeComponent(roomId);
    return '$wsBase/ws/room/$r?token=$t';
  }

  void _log(String message) {
    if (!_debugLogs) return;
    debugPrint('[colisten] $message');
  }

  bool get isConnected => _channel != null;

  Future<void> disconnect() async {
    _hostTimer?.cancel();
    _hostTimer = null;
    _guestTimer?.cancel();
    _guestTimer = null;
    if (_hostListener != null && _hostAudio != null) {
      _hostAudio!.removeListener(_hostListener!);
    }
    _hostListener = null;
    _hostAudio = null;
    await _sub?.cancel();
    _sub = null;
    await _channel?.sink.close();
    _channel = null;
    _isHost = false;
    _guestLastVersion = 0;
    _guestAppliedVersion = 0;
    _guestApplyChain = Future<void>.value();
    _hostLastTrackId = null;
    _hostLastQueueTrackIds = const [];
    _guestTargetPositionSeconds = 0;
    _guestTargetPlaying = false;
    _guestTargetAnchorLocalMs = 0;
    _guestLastTightSeekAtMs = 0;
    _guestNeedsInitialHardSync = false;
    _guestNeedsFirstRealtimeHardSync = false;
    _guestFirstRealtimeStateCompleter = null;
    _roomId = null;
    _guestLastQueueTrackIds = const [];
    _trackCache.clear();
    _localTrackCacheByAssetPath = null;
    ListeningRoomSession.instance.setJoining(false);
  }

  Future<void> connectGuest({
    required String roomId,
    required AudioPlayerService audio,
  }) async {
    await disconnect();
    final acc = await AuthSessionStore.readAccount();
    final token = acc?.sessionToken.trim() ?? '';
    if (token.isEmpty) throw StateError('Not logged in');
    _isHost = false;
    _roomId = roomId;
    _guestLastVersion = 0;
    _guestNeedsInitialHardSync = true;
    _guestNeedsFirstRealtimeHardSync = true;
    _guestFirstRealtimeStateCompleter = Completer<void>();
    ListeningRoomSession.instance.setJoining(true);
    _log('guest connect start room=$roomId');
    var initialBootstrapOk = false;
    try {
      try {
        final initial = await ColistenApi().getRoomState(roomId);
        _log(
          'guest initial state room=$roomId v=${initial.stateVersion} trackId=${initial.trackId} key=${initial.trackKey} pos=${initial.positionSeconds.toStringAsFixed(3)} playing=${initial.playing} queue=${initial.queueTrackKeys.length}/${initial.queueTrackIds.length}',
        );
        await _applyGuestState(
          <String, dynamic>{
            'isOpen': initial.isOpen,
            'trackId': initial.trackId,
            'trackKey': initial.trackKey,
            'queueTrackIds': initial.queueTrackIds,
            'queueTrackKeys': initial.queueTrackKeys,
            'positionSeconds': initial.positionSeconds,
            'playing': initial.playing,
            'controlPauseHostOnly': initial.controlPauseHostOnly,
            'controlSeekHostOnly': initial.controlSeekHostOnly,
            'controlShuffleHostOnly': initial.controlShuffleHostOnly,
            'controlRepeatHostOnly': initial.controlRepeatHostOnly,
            'controlSkipHostOnly': initial.controlSkipHostOnly,
            'controlPlaylistHostOnly': initial.controlPlaylistHostOnly,
            'participantIds': initial.participantIds,
            'wallClockMs': initial.wallClockMs,
          },
          audio,
          forceTrackReload: true,
          forcePositionSync: true,
        );
        _guestLastVersion = initial.stateVersion;
        _guestAppliedVersion = initial.stateVersion;
        initialBootstrapOk = true;
      } catch (_) {}
      final uri = Uri.parse(wsUrl(roomId, token));
      _channel = WebSocketChannel.connect(uri);
      _sub = _channel!.stream.listen((raw) {
        if (raw is! String) return;
        _onGuestMessage(raw, audio);
      });
      _guestTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
        unawaited(_guestTightSync(audio));
      });
      // Безусловный hard-sync после открытия WS:
      // первый state в канале может быть переходным, поэтому сразу
      // подтверждаем состояние через REST и применяем позицию принудительно.
      await forceGuestSnapshotSync(
        audio,
        forceTrackReload: true,
        forcePositionSync: true,
      );
      await _refreshGuestSnapshot(
        roomId,
        audio,
        delayMs: 700,
        forceTrackReload: false,
        forcePositionSync: true,
      );
      if (!initialBootstrapOk) {
        await _refreshGuestSnapshot(
          roomId,
          audio,
          delayMs: 150,
          forceTrackReload: true,
          forcePositionSync: true,
        );
        _scheduleGuestPostConnectSnapshots(roomId, audio);
      } else {
        _scheduleGuestPostConnectSnapshots(roomId, audio);
      }
      final firstRealtime = _guestFirstRealtimeStateCompleter;
      if (firstRealtime != null && !firstRealtime.isCompleted) {
        try {
          await firstRealtime.future.timeout(const Duration(milliseconds: 1200));
        } catch (_) {}
      }
    } finally {
      ListeningRoomSession.instance.setJoining(false);
    }
  }

  void _scheduleGuestPostConnectSnapshots(
    String roomId,
    AudioPlayerService audio,
  ) {
    // На слабой сети / девайсах первый join/state может быть устаревшим.
    // Берём несколько контрольных снимков, чтобы гарантированно дойти
    // до актуального тайминга хоста в первый заход.
    const delaysMs = <int>[450, 1200, 2300];
    for (final delay in delaysMs) {
      unawaited(
        _refreshGuestSnapshot(
          roomId,
          audio,
          delayMs: delay,
          forceTrackReload: false,
          forcePositionSync: true,
        ),
      );
    }
  }

  Future<void> _refreshGuestSnapshot(
    String roomId,
    AudioPlayerService audio, {
    int delayMs = 700,
    bool forceTrackReload = false,
    bool forcePositionSync = false,
  }) async {
    await Future<void>.delayed(Duration(milliseconds: delayMs));
    if (_isHost || _roomId != roomId || !ListeningRoomSession.instance.active) return;
    try {
      final state = await ColistenApi().getRoomState(roomId);
      _log(
        'guest snapshot room=$roomId v=${state.stateVersion} trackId=${state.trackId} key=${state.trackKey} pos=${state.positionSeconds.toStringAsFixed(3)} playing=${state.playing}',
      );
      await _applyGuestState(
        <String, dynamic>{
          'isOpen': state.isOpen,
          'trackId': state.trackId,
          'trackKey': state.trackKey,
          'queueTrackIds': state.queueTrackIds,
          'queueTrackKeys': state.queueTrackKeys,
          'positionSeconds': state.positionSeconds,
          'playing': state.playing,
          'controlPauseHostOnly': state.controlPauseHostOnly,
          'controlSeekHostOnly': state.controlSeekHostOnly,
          'controlShuffleHostOnly': state.controlShuffleHostOnly,
          'controlRepeatHostOnly': state.controlRepeatHostOnly,
          'controlSkipHostOnly': state.controlSkipHostOnly,
          'controlPlaylistHostOnly': state.controlPlaylistHostOnly,
          'participantIds': state.participantIds,
          'wallClockMs': state.wallClockMs,
        },
        audio,
        forceTrackReload: forceTrackReload,
        forcePositionSync: forcePositionSync,
      );
    } catch (_) {}
  }

  Future<void> forceGuestSnapshotSync(
    AudioPlayerService audio, {
    bool forceTrackReload = true,
    bool forcePositionSync = false,
  }) async {
    final roomId = _roomId;
    if (_isHost || roomId == null || roomId.isEmpty || !ListeningRoomSession.instance.active) {
      return;
    }
    try {
      final state = await ColistenApi().getRoomState(roomId);
      _log(
        'guest force snapshot room=$roomId v=${state.stateVersion} trackId=${state.trackId} key=${state.trackKey} pos=${state.positionSeconds.toStringAsFixed(3)} playing=${state.playing} forceReload=$forceTrackReload',
      );
      await _applyGuestState(
        <String, dynamic>{
          'isOpen': state.isOpen,
          'trackId': state.trackId,
          'trackKey': state.trackKey,
          'queueTrackIds': state.queueTrackIds,
          'queueTrackKeys': state.queueTrackKeys,
          'positionSeconds': state.positionSeconds,
          'playing': state.playing,
          'controlPauseHostOnly': state.controlPauseHostOnly,
          'controlSeekHostOnly': state.controlSeekHostOnly,
          'controlShuffleHostOnly': state.controlShuffleHostOnly,
          'controlRepeatHostOnly': state.controlRepeatHostOnly,
          'controlSkipHostOnly': state.controlSkipHostOnly,
          'controlPlaylistHostOnly': state.controlPlaylistHostOnly,
          'participantIds': state.participantIds,
          'wallClockMs': state.wallClockMs,
        },
        audio,
        forceTrackReload: forceTrackReload,
        forcePositionSync: forcePositionSync,
      );
    } catch (_) {}
  }

  Future<void> connectHost({
    required String roomId,
    required AudioPlayerService audio,
  }) async {
    await disconnect();
    final acc = await AuthSessionStore.readAccount();
    final token = acc?.sessionToken.trim() ?? '';
    if (token.isEmpty) throw StateError('Not logged in');
    _isHost = true;
    _roomId = roomId;
    _hostAudio = audio;
    final current = audio.currentTrack;
    _hostLastTrackId = current == null
        ? null
        : TracksApi().resolveServerTrackId(
            assetPath: current.assetPath,
            audioFilePath: current.audioFilePath,
          );
    _hostLastPlaying = audio.isPlaying;
    _hostLastQueueTrackIds = _queueTrackIdsFromAudio(audio);
    final uri = Uri.parse(wsUrl(roomId, token));
    _channel = WebSocketChannel.connect(uri);
    _sub = _channel!.stream.listen((raw) {
      if (raw is! String) return;
      _onHostStateMessage(raw);
    });

    void listener() {
      if (!_isHost || _channel == null) return;
      final current = audio.currentTrack;
      final tid = current == null
          ? null
          : TracksApi().resolveServerTrackId(
              assetPath: current.assetPath,
              audioFilePath: current.audioFilePath,
            );
      final queueIds = _queueTrackIdsFromAudio(audio);
      final queueKeys = _queueTrackKeysFromAudio(audio);
      final trackKey = current == null
          ? null
          : TracksApi().trackKeyForPaths(
              assetPath: current.assetPath,
              audioFilePath: current.audioFilePath,
            );
      final p = audio.isPlaying;
      _hostLastTrackId = tid;
      _hostLastQueueTrackIds = queueIds;
      _hostLastPlaying = p;
      if (tid != null) {
        _sink(jsonEncode(<String, dynamic>{
          'type': 'host_state',
          'trackId': tid,
          if (trackKey case final value?) 'trackKey': value,
          'queueTrackIds': queueIds,
          'queueTrackKeys': queueKeys,
          'position': audio.position.inMilliseconds / 1000.0,
          'playing': p,
        }));
      } else if (queueIds.isNotEmpty || queueKeys.isNotEmpty) {
        _sink(jsonEncode(<String, dynamic>{
          'type': 'host_state',
          'queueTrackIds': queueIds,
          'queueTrackKeys': queueKeys,
          if (trackKey case final value?) 'trackKey': value,
          'position': audio.position.inMilliseconds / 1000.0,
          'playing': p,
        }));
      }
    }

    _hostListener = listener;
    audio.addListener(listener);
    listener();

    _hostTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!_isHost || _channel == null) return;
      listener();
    });
  }

  void _onHostStateMessage(String raw) {
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      if (j['type'] != 'state') return;
      _applySessionState(j);
    } catch (_) {}
  }

  void _sink(String msg) {
    try {
      _channel?.sink.add(msg);
    } catch (_) {}
  }

  void _onGuestMessage(String raw, AudioPlayerService audio) {
    if (!ListeningRoomSession.instance.active) {
      unawaited(disconnect());
      return;
    }
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      if (j['type'] != 'state') return;
      final ver = (j['stateVersion'] as num?)?.toInt() ?? 0;
      if (ver <= _guestLastVersion) return;
      _guestLastVersion = ver;
      _log(
        'guest ws state room=$_roomId v=$ver trackId=${j['trackId']} key=${j['trackKey']} pos=${j['positionSeconds'] ?? j['position']} playing=${j['playing']}',
      );
      _guestApplyChain = _guestApplyChain.then((_) async {
        if (ver <= _guestAppliedVersion) return;
        final forceRealtimePositionSync = _guestNeedsFirstRealtimeHardSync;
        await _applyGuestState(
          j,
          audio,
          forcePositionSync: forceRealtimePositionSync,
        );
        _guestNeedsFirstRealtimeHardSync = false;
        final firstRealtime = _guestFirstRealtimeStateCompleter;
        if (firstRealtime != null && !firstRealtime.isCompleted) {
          firstRealtime.complete();
        }
        _guestAppliedVersion = ver;
      });
    } catch (_) {}
  }

  Future<void> _applyGuestState(
    Map<String, dynamic> j,
    AudioPlayerService audio, {
    bool forceTrackReload = false,
    bool forcePositionSync = false,
  }) async {
    if (!ListeningRoomSession.instance.active) return;
    _applySessionState(j);
    // Как только получили и применили состояние комнаты, убираем "Connecting...":
    // дальнейшие доп.снапшоты могут идти в фоне, но пользователь уже синхронизируется.
    ListeningRoomSession.instance.setJoining(false);
    final tid = (j['trackId'] as num?)?.toInt();
    final trackKey = (j['trackKey'] as String?)?.trim();
    final queueIds = ((j['queueTrackIds'] as List?) ?? const [])
        .map((e) => (e as num?)?.toInt())
        .whereType<int>()
        .where((e) => e > 0)
        .toList();
    final queueKeys = ((j['queueTrackKeys'] as List?) ?? const [])
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final pos = ((j['positionSeconds'] as num?) ?? (j['position'] as num?))
            ?.toDouble() ??
        0;
    final playing = j['playing'] as bool? ?? false;
    _log(
      'guest apply room=$_roomId trackId=$tid key=$trackKey pos=${pos.toStringAsFixed(3)} playing=$playing forceReload=$forceTrackReload',
    );
    _guestTargetPositionSeconds = pos;
    _guestTargetPlaying = playing;
    // Не используем wallClockMs удалённого устройства для расчёта target:
    // часы на разных телефонах могут расходиться на секунды.
    // Якоримся на локальном времени получения state.
    _guestTargetAnchorLocalMs = DateTime.now().millisecondsSinceEpoch;
    final effectiveQueueKeys = queueKeys.isNotEmpty
        ? queueKeys
        : queueIds.map((id) => 'srv:$id').toList();
    List<Track> roomQueue = const [];
    if (effectiveQueueKeys.isNotEmpty) {
      final keysAsIds = effectiveQueueKeys
          .where((e) => e.startsWith('srv:'))
          .map((e) => int.tryParse(e.substring(4)))
          .whereType<int>()
          .toList();
      _guestLastQueueTrackIds = keysAsIds;
      roomQueue = await _buildQueueFromTrackKeys(effectiveQueueKeys);
      if (roomQueue.isNotEmpty) {
        ListeningRoomSession.instance.replaceQueue(roomQueue);
      }
    }
    final effectiveTrackKey = () {
      if (trackKey != null && trackKey.isNotEmpty) return trackKey;
      if (tid != null) return 'srv:$tid';
      return null;
    }();
    var trackWasReloaded = false;
    if (effectiveTrackKey != null) {
      final currentQueue = audio.activeQueue;
      final currentQueueKeys = currentQueue
          .map((t) => TracksApi().trackKeyForPaths(
                assetPath: t.assetPath,
                audioFilePath: t.audioFilePath,
              ))
          .toList();
      final tr = await _trackFromTrackKey(effectiveTrackKey);
      final roomQueueKeys = effectiveQueueKeys;
      final queueMismatch = roomQueueKeys.isNotEmpty &&
          !_sameStringList(currentQueueKeys, roomQueueKeys);
      final needTrackReload = forceTrackReload ||
          TracksApi().trackKeyForPaths(
                assetPath: audio.currentTrack?.assetPath ?? '',
                audioFilePath: audio.currentTrack?.audioFilePath,
              ) !=
              effectiveTrackKey ||
          queueMismatch;
      _log(
        'guest track decision key=$effectiveTrackKey reload=$needTrackReload queueMismatch=$queueMismatch currentKey=${TracksApi().trackKeyForPaths(assetPath: audio.currentTrack?.assetPath ?? '', audioFilePath: audio.currentTrack?.audioFilePath)}',
      );
      if (needTrackReload) {
        final queue = roomQueueKeys.isEmpty ? [tr] : roomQueue;
        await audio.playTrack(
          tr,
          queue: queue.isEmpty ? [tr] : queue,
          leaveListeningRoomSession: false,
          autoPlay: false,
        );
        trackWasReloaded = true;
      } else if (queueMismatch && roomQueue.isNotEmpty) {
        await audio.replaceQueueFromRoomSync(roomQueue);
      }
    }
    final seekTargetSeconds = () {
      if (!playing || _guestTargetAnchorLocalMs <= 0) return pos;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final elapsedMs = (nowMs - _guestTargetAnchorLocalMs).clamp(0, 15000);
      return pos + (elapsedMs / 1000.0);
    }();
    final seekPos = Duration(milliseconds: (seekTargetSeconds * 1000).round());
    final currentMs = audio.position.inMilliseconds;
    final targetMs = seekPos.inMilliseconds;
    final diffMs = (targetMs - currentMs).abs();
    final signedDiffMs = targetMs - currentMs;
    final hardSyncNow = _guestNeedsInitialHardSync;
    final needForwardHardSeek = signedDiffMs >= 1400;
    // Назад корректируем только при действительно большом уходе,
    // чтобы не загонять плеер в "пилу" с постоянными микро-откатами.
    final needBackwardHardSeek = signedDiffMs <= -3000;
    final shouldSeek = forcePositionSync ||
        hardSyncNow ||
        trackWasReloaded ||
        (!playing && diffMs >= 250) ||
        (playing && (needForwardHardSeek || needBackwardHardSeek));
    _log(
      'guest seek decision targetMs=$targetMs currentMs=$currentMs signedDiffMs=$signedDiffMs shouldSeek=$shouldSeek reloaded=$trackWasReloaded',
    );
    if (shouldSeek) {
      await _seekGuestToTarget(
        audio: audio,
        target: seekPos,
        trackWasReloaded: trackWasReloaded,
      );
      _guestNeedsInitialHardSync = false;
    }
    if (playing) {
      await audio.playFromRoomSync();
      await _guestTightSync(audio);
    } else {
      await audio.pauseFromRoomSync();
    }
    final needsPostSettleSeek =
        forcePositionSync || hardSyncNow || trackWasReloaded;
    if (needsPostSettleSeek) {
      await _postSettleGuestSeek(
        audio: audio,
        target: seekPos,
      );
    }
  }

  Future<void> _seekGuestToTarget({
    required AudioPlayerService audio,
    required Duration target,
    required bool trackWasReloaded,
  }) async {
    if (trackWasReloaded) {
      // После замены источника некоторые устройства принимают seek только со второй попытки.
      await Future<void>.delayed(const Duration(milliseconds: 220));
    }
    await audio.seekFromRoomSync(target);
    final targetMs = target.inMilliseconds;
    if (targetMs < 1200) return;
    final attempts = trackWasReloaded ? 8 : 4;
    for (var i = 0; i < attempts; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 320));
      final actualMs = audio.position.inMilliseconds;
      final diffMs = (targetMs - actualMs).abs();
      if (diffMs <= 350) return;
      await audio.seekFromRoomSync(target);
    }
  }

  Future<void> _postSettleGuestSeek({
    required AudioPlayerService audio,
    required Duration target,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    final targetMs = target.inMilliseconds;
    final actualMs = audio.position.inMilliseconds;
    final diffMs = (targetMs - actualMs).abs();
    if (diffMs <= 260) return;
    _log(
      'guest post-settle seek targetMs=$targetMs actualMs=$actualMs diffMs=$diffMs',
    );
    await audio.seekFromRoomSync(target);
  }

  Future<void> _guestTightSync(AudioPlayerService audio) async {
    if (!ListeningRoomSession.instance.active) {
      await disconnect();
      return;
    }
    if (_isHost || _channel == null || !_guestTargetPlaying) {
      return;
    }
    final anchorLocal = _guestTargetAnchorLocalMs;
    if (anchorLocal <= 0) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final elapsedMs = (nowMs - anchorLocal).clamp(0, 15000);
    final targetSec = _guestTargetPositionSeconds + (elapsedMs / 1000.0);
    final actualSec = audio.position.inMilliseconds / 1000.0;
    final driftSec = targetSec - actualSec;
    final sinceLastSeekMs = nowMs - _guestLastTightSeekAtMs;
    if (!audio.isPlaying) {
      return;
    }
    final needForwardCatchup = driftSec >= 1.6;
    // Лёгкое опережение не трогаем: иначе возможны заметные подёргивания.
    final needBackwardCorrection = driftSec <= -3.2;
    if ((needForwardCatchup || needBackwardCorrection) && sinceLastSeekMs >= 3500) {
      _log(
        'guest tight sync correct drift=${driftSec.toStringAsFixed(3)} target=${targetSec.toStringAsFixed(3)} actual=${actualSec.toStringAsFixed(3)}',
      );
      _guestLastTightSeekAtMs = nowMs;
      await audio.seekFromRoomSync(
        Duration(milliseconds: (targetSec * 1000).round()),
      );
    }
  }

  int? _resolveTrackId(Track? track) {
    if (track == null) return null;
    return TracksApi().resolveServerTrackId(
      assetPath: track.assetPath,
      audioFilePath: track.audioFilePath,
    );
  }

  List<int> _queueTrackIdsFromAudio(AudioPlayerService audio) {
    final out = <int>[];
    for (final track in audio.activeQueue) {
      final id = _resolveTrackId(track);
      if (id != null && !out.contains(id)) out.add(id);
    }
    return out;
  }

  List<String> _queueTrackKeysFromAudio(AudioPlayerService audio) {
    final out = <String>[];
    for (final track in audio.activeQueue) {
      final key = TracksApi().trackKeyForPaths(
        assetPath: track.assetPath,
        audioFilePath: track.audioFilePath,
      );
      if (!out.contains(key)) out.add(key);
    }
    return out;
  }

  Future<Track> _trackFromServerId(int tid) async {
    final cached = _trackCache[tid];
    if (cached != null) return cached;
    final base = ApiConfig.baseUrl.replaceAll(RegExp(r'/+$'), '');
    String title = '—';
    String? artist;
    try {
      final remote = await TracksApi().fetchTrackById(tid);
      title = remote.title.trim().isEmpty ? '—' : remote.title.trim();
      artist = remote.artist;
    } catch (_) {}
    final built = Track(
      assetPath: 'server_track_$tid',
      title: title,
      artist: artist,
      audioFilePath: '$base/tracks/$tid/stream',
      coverAssetPath: '$base/tracks/$tid/cover',
    );
    _trackCache[tid] = built;
    return built;
  }

  Future<List<Track>> _buildQueueFromTrackIds(List<int> trackIds) async {
    final queue = <Track>[];
    for (final id in trackIds) {
      queue.add(await _trackFromServerId(id));
    }
    return queue;
  }

  Future<List<Track>> _buildQueueFromTrackKeys(List<String> trackKeys) async {
    final queue = <Track>[];
    for (final key in trackKeys) {
      queue.add(await _trackFromTrackKey(key));
    }
    return queue;
  }

  Future<void> _ensureLocalCacheLoaded() async {
    if (_localTrackCacheByAssetPath != null) return;
    final list = await loadLocalTracks();
    _localTrackCacheByAssetPath = {
      for (final t in list) t.assetPath: t,
    };
  }

  Future<Track> _trackFromTrackKey(String key) async {
    if (key.startsWith('srv:')) {
      final id = int.tryParse(key.substring(4));
      if (id != null && id > 0) return _trackFromServerId(id);
    }
    if (key.startsWith('asset:')) {
      await _ensureLocalCacheLoaded();
      final assetPath = key.substring(6);
      final local = _localTrackCacheByAssetPath?[assetPath];
      if (local != null) return local;
      return Track(assetPath: assetPath, title: assetPath);
    }
    return Track(assetPath: key, title: key);
  }

  bool _sameIntList(List<int> a, List<int> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool _sameStringList(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _applySessionState(Map<String, dynamic> j) {
    final session = ListeningRoomSession.instance;
    if (!session.active) return;
    final participantIds = (j['participantIds'] as List?) ?? const [];
    session.applyRealtimeState(
      listenersCount: participantIds.length,
      participantIds: participantIds
          .map((e) => (e as num?)?.toInt())
          .whereType<int>()
          .toList(),
      privateRoom: !(j['isOpen'] as bool? ?? false),
      pauseHostOnly: j['controlPauseHostOnly'] as bool? ?? true,
      seekHostOnly: j['controlSeekHostOnly'] as bool? ?? true,
      shuffleHostOnly: j['controlShuffleHostOnly'] as bool? ?? true,
      repeatHostOnly: j['controlRepeatHostOnly'] as bool? ?? true,
      skipHostOnly: j['controlSkipHostOnly'] as bool? ?? true,
      playlistHostOnly: j['controlPlaylistHostOnly'] as bool? ?? true,
    );
  }

  void updateRoomSettings({
    required bool privateRoom,
    required bool pauseHostOnly,
    required bool seekHostOnly,
    required bool shuffleHostOnly,
    required bool repeatHostOnly,
    required bool skipHostOnly,
    required bool playlistHostOnly,
  }) {
    if (!_isHost || _channel == null || _roomId == null) return;
    _sink(jsonEncode(<String, dynamic>{
      'type': 'update_settings',
      'privateRoom': privateRoom,
      'controlPauseHostOnly': pauseHostOnly,
      'controlSeekHostOnly': seekHostOnly,
      'controlShuffleHostOnly': shuffleHostOnly,
      'controlRepeatHostOnly': repeatHostOnly,
      'controlSkipHostOnly': skipHostOnly,
      'controlPlaylistHostOnly': playlistHostOnly,
    }));
  }

  void onGuestManualPlayPauseToggle(AudioPlayerService audio) {
    if (_isHost || !ListeningRoomSession.instance.active) return;
  }

  void pushHostState(AudioPlayerService audio) {
    if (!_isHost || _channel == null) return;
    final current = audio.currentTrack;
    final tid = current == null
        ? null
        : TracksApi().resolveServerTrackId(
            assetPath: current.assetPath,
            audioFilePath: current.audioFilePath,
          );
    final queueIds = _queueTrackIdsFromAudio(audio);
    final trackKey = current == null
        ? null
        : TracksApi().trackKeyForPaths(
            assetPath: current.assetPath,
            audioFilePath: current.audioFilePath,
          );
    final queueKeys = _queueTrackKeysFromAudio(audio);
    _sink(jsonEncode(<String, dynamic>{
      'type': 'host_state',
      if (tid case final value?) 'trackId': value,
      if (trackKey case final value?) 'trackKey': value,
      'queueTrackIds': queueIds,
      'queueTrackKeys': queueKeys,
      'position': audio.position.inMilliseconds / 1000.0,
      'playing': audio.isPlaying,
    }));
  }
}
