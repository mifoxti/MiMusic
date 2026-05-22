import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../audio/audio_player_service.dart';
import '../audio/track.dart';
import '../auth/auth_session_store.dart';
import '../network/api_config.dart';
import '../network/colisten_api.dart';
import '../network/friends_api.dart';
import '../network/tracks_api.dart';
import '../audio/local_tracks.dart';
import 'listening_room_session.dart';

/// WebSocket Colisten: гость подстраивает плеер под состояние комнаты, хост пушит seek/track/play.
class ColistenController {
  ColistenController._();

  static final ColistenController instance = ColistenController._();
  static const bool _debugLogs = bool.fromEnvironment(
    'COLISTEN_DEBUG',
    defaultValue: true,
  );

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _hostTimer;
  Timer? _hostSnapshotTimer;
  Timer? _guestPollTimer;
  Timer? _guestApplyDebounceTimer;
  Map<String, dynamic>? _guestPendingApplyState;
  int _guestPendingApplyGeneration = 0;
  bool? _guestLastKnownPlaying;
  Timer? _guestSnapshotTimer;
  void Function()? _hostListener;
  AudioPlayerService? _hostAudio;
  bool _hostRestSyncInFlight = false;
  bool _hostPendingRestSync = false;
  Map<String, dynamic>? _guestPendingCommandPayload;
  int _hostLastRestSyncAtMs = 0;
  int _hostLastWsSyncAtMs = 0;
  int _hostLastPlayPausePushAtMs = 0;
  bool? _hostLastPlayPausePushedPlaying;
  /// Макс. «догон» позиции гостя по wallClock (без экстраполяции гость убегает вперёд).
  static const int _guestMaxLeadMs = 350;
  static const int _guestNetworkLatencyMs = 200;
  static const int _guestWsSnapshotSilenceMs = 20000;
  static const int _guestPollIntervalMs = 800;
  static const int _guestPollWsSilenceMs = 1200;
  static const int _guestForcedRestSyncMs = 1500;
  bool _guestBootstrapComplete = false;
  Map<String, dynamic>? _guestCoalescedState;
  bool _guestCoalesceFlushScheduled = false;
  Timer? _guestForcedRestTimer;
  Map<String, dynamic>? _guestPendingInitialState;
  int _guestPendingInitialVersion = 0;
  final List<String> _guestWsBootstrapBuffer = <String>[];
  bool _guestWsBootstrapDone = false;
  Future<void> _guestWsApplyChain = Future<void>.value();
  Future<void> _guestTransportApplyChain = Future<void>.value();
  Future<void> _guestPlayPauseChain = Future<void>.value();
  Object? _guestSeekToken;
  Map<String, dynamic>? _guestPendingTransportState;
  int _guestPendingTransportVer = 0;
  int _guestPendingTransportGeneration = 0;
  AudioPlayerService? _guestPendingTransportAudio;
  bool _guestTransportDrainQueued = false;
  String? _hostLastSentSignature;
  int _connectionGeneration = 0;
  int _hostAppliedRoomVersion = 0;
  int _hostOutboundBlockers = 0;
  int _hostSuppressOutboundUntilMs = 0;
  int _hostListenerMutedUntilMs = 0;
  Timer? _hostRestDebounceTimer;
  Map<String, dynamic>? _hostRestDebouncePayload;
  AudioPlayerService? _hostRestDebounceAudio;
  Timer? _hostControlRestTimer;
  int _hostControlRestSerial = 0;
  int _guestLastWsStateAtMs = 0;
  int _guestHostPausedAtMs = 0;
  int _guestWsConnectedAtMs = 0;
  Future<void> _hostWsApplyChain = Future<void>.value();
  Future<void> _hostRemoteCommandChain = Future<void>.value();
  int _hostRemoteCommandSerial = 0;
  int _hostLocalActionSerial = 0;
  Map<String, dynamic>? _hostRemoteAuthoritativeOverride;
  int _hostRemoteAuthoritativeOverrideUntilMs = 0;
  Future<void>? _connectInFlight;
  bool _guestBootstrapApplyInFlight = false;
  Map<String, dynamic>? _guestDeferredRoomState;

  bool _isHost = false;
  int _guestLastSeenVersion = 0;
  int _guestAppliedVersion = 0;
  int _guestLastControlSeq = 0;
  double _guestTargetPositionSeconds = 0;
  bool _guestTargetPlaying = false;
  int _guestTargetAnchorLocalMs = 0;
  bool _guestNeedsInitialHardSync = false;
  bool _guestNeedsFirstRealtimeHardSync = false;
  Completer<void>? _guestFirstRealtimeStateCompleter;
  int _lastGuestPlayPauseCommandAtMs = 0;
  int _lastGuestPlayPauseCommandPositionMs = 0;
  bool? _lastGuestPlayPauseCommandPlaying;
  bool? _guestPendingPlayPausePlaying;
  int _guestPendingPlayPauseUntilMs = 0;
  int _guestCommandSerial = 0;
  String? _guestLastAppliedPlaybackSig;
  double? _guestLastTransportPositionSeconds;
  bool? _guestLastKnownShuffleEnabled;
  String? _guestLastKnownRepeatMode;
  String? _roomId;
  final Map<int, Track> _trackCache = <int, Track>{};
  final Map<int, String> _participantNameCache = <int, String>{};
  Map<String, Track>? _localTrackCacheByAssetPath;

  bool _guestServerPlayingChanged(bool serverPlaying) =>
      _guestLastKnownPlaying != serverPlaying;

  bool _guestEngineMatchesServer(bool serverPlaying, AudioPlayerService audio) =>
      serverPlaying == audio.engineIsPlaying;

  bool _guestOutOfSyncWithServer(bool serverPlaying, AudioPlayerService audio) =>
      _guestServerPlayingChanged(serverPlaying) ||
      !_guestEngineMatchesServer(serverPlaying, audio);

  /// In-flight transport устарел: в очереди уже лежит более новый pending snapshot.
  /// Не сравниваем с [_guestLastSeenVersion]: WS может обновить seen до drain,
  /// и тогда пауза/плей из pending никогда не доходит до ExoPlayer.
  bool _guestTransportSuperseded(int ver, int generation) {
    if (_connectionGeneration != generation) return true;
    if (ver <= 0) return false;
    final pendingVer = _guestPendingTransportVer;
    final hasNewerPending = _guestPendingTransportState != null &&
        _guestPendingTransportGeneration == generation &&
        pendingVer > ver;
    return hasNewerPending;
  }

  bool _guestEngineDrifted(AudioPlayerService audio) {
    if (audio.currentTrack == null) return false;
    if (_guestLastKnownPlaying == null) return false;
    return !_guestEngineMatchesServer(_guestLastKnownPlaying!, audio);
  }

  bool _guestTransportFieldsChanged(
    Map<String, dynamic> j,
    AudioPlayerService audio,
  ) {
    final playing = j['playing'] as bool? ?? false;
    if (_guestServerPlayingChanged(playing)) return true;
    if (_guestNeedsTrackReload(j, audio)) return true;
    final pos =
        ((j['positionSeconds'] as num?) ?? (j['position'] as num?))
            ?.toDouble() ??
        0;
    final lastPos = _guestLastTransportPositionSeconds;
    if (lastPos == null) return true;
    return (lastPos - pos).abs() >= 0.2;
  }

  bool _guestMetadataChanged(Map<String, dynamic> j) {
    final shuffle = j['shuffleEnabled'] as bool?;
    final repeat = (j['repeatMode'] as String?)?.trim().toLowerCase();
    if (shuffle != null && shuffle != _guestLastKnownShuffleEnabled) {
      return true;
    }
    if (repeat != null &&
        repeat.isNotEmpty &&
        repeat != _guestLastKnownRepeatMode) {
      return true;
    }
    return false;
  }

  bool _guestSessionSettingsChanged(Map<String, dynamic> j) {
    final session = ListeningRoomSession.instance;
    if (!session.active) return false;
    final privateRoom = !(j['isOpen'] as bool? ?? false);
    if (privateRoom != session.privateRoom) return true;
    if ((j['controlPauseHostOnly'] as bool? ?? true) != session.pauseHostOnly) {
      return true;
    }
    if ((j['controlSeekHostOnly'] as bool? ?? true) != session.seekHostOnly) {
      return true;
    }
    if ((j['controlShuffleHostOnly'] as bool? ?? true) !=
        session.shuffleHostOnly) {
      return true;
    }
    if ((j['controlRepeatHostOnly'] as bool? ?? true) != session.repeatHostOnly) {
      return true;
    }
    if ((j['controlSkipHostOnly'] as bool? ?? true) != session.skipHostOnly) {
      return true;
    }
    if ((j['controlPlaylistHostOnly'] as bool? ?? true) !=
        session.playlistHostOnly) {
      return true;
    }
    return false;
  }

  bool _guestLightweightStateChanged(Map<String, dynamic> j) =>
      _guestMetadataChanged(j) || _guestSessionSettingsChanged(j);

  bool _guestNeedsTransportSync(
    Map<String, dynamic> j,
    AudioPlayerService audio,
  ) {
    final playing = j['playing'] as bool? ?? false;
    if (_guestServerPlayingChanged(playing)) return true;
    if (!_guestEngineMatchesServer(playing, audio)) return true;
    final pos =
        ((j['positionSeconds'] as num?) ?? (j['position'] as num?))
            ?.toDouble() ??
        0;
    final lastPos = _guestLastTransportPositionSeconds;
    if (lastPos != null && (lastPos - pos).abs() >= 0.2) return true;
    return _guestControlSeqAdvanced(j) &&
        _guestTransportFieldsChanged(j, audio);
  }

  void _resetGuestTransportPending() {
    _guestPendingTransportState = null;
    _guestPendingTransportVer = 0;
    _guestPendingTransportGeneration = 0;
    _guestPendingTransportAudio = null;
    _guestTransportDrainQueued = false;
    _guestPlayPauseChain = Future<void>.value();
    _guestSeekToken = null;
  }

  static const Duration _guestEngineOpTimeout = Duration(seconds: 2);

  Future<void> _runGuestPlayPause(Future<void> Function() op) {
    final scheduled = _guestPlayPauseChain.then((_) async {
      if (_isHost || !ListeningRoomSession.instance.active) return;
      try {
        await op().timeout(_guestEngineOpTimeout);
      } on TimeoutException {
        _log('guest playpause sync timeout room=$_roomId');
      }
    });
    _guestPlayPauseChain = scheduled.catchError((Object e) {
      _log('guest playpause sync error room=$_roomId error=$e');
    });
    return scheduled;
  }

  Future<void> _guestTransportEngineOp(
    Future<void> Function() op, {
    required String label,
  }) async {
    try {
      await op().timeout(_guestEngineOpTimeout);
    } on TimeoutException {
      _log('guest transport $label timeout room=$_roomId');
    } catch (e) {
      _log('guest transport $label error room=$_roomId error=$e');
    }
  }

  /// Только последний seek; не ждём предыдущий (длинный seek не блокирует resume).
  Future<void> _runGuestSeek(Future<void> Function() op) {
    final token = Object();
    _guestSeekToken = token;
    return Future<void>(() async {
      if (_isHost || !ListeningRoomSession.instance.active) return;
      if (_guestSeekToken != token) return;
      try {
        await op().timeout(const Duration(seconds: 3));
      } on TimeoutException {
        if (_guestSeekToken == token) {
          _log('guest seek timeout room=$_roomId');
        }
      } catch (e) {
        if (_guestSeekToken == token) {
          _log('guest seek sync error room=$_roomId error=$e');
        }
      }
    });
  }

  Future<void> _guestApplyPlayPauseIntent(
    AudioPlayerService audio, {
    required bool playing,
    required Duration target,
  }) async {
    if (playing) {
      await audio.playFromRoomSync();
      if (!audio.engineIsPlaying) {
        await audio.seekFromRoomSync(target);
        await audio.playFromRoomSync();
      }
    } else {
      await audio.pauseFromRoomSync();
    }
  }

  bool _shouldReplaceGuestPendingTransport(
    int generation,
    Map<String, dynamic> j,
  ) {
    final pending = _guestPendingTransportState;
    if (pending == null || _guestPendingTransportGeneration != generation) {
      return true;
    }
    final incomingVer = _stateVersionFromJson(j);
    final incomingCs = _guestControlSeqFrom(j);
    final pendingVer = _guestPendingTransportVer;
    final pendingCs = _guestControlSeqFrom(pending);
    if (incomingVer > pendingVer) return true;
    if (incomingVer == pendingVer && incomingCs >= pendingCs) return true;
    return false;
  }

  Future<void> _applyGuestMetadataOnly(
    Map<String, dynamic> j,
    AudioPlayerService audio,
    int generation,
    int ver,
  ) async {
    if (_connectionGeneration != generation) return;
    _applySessionState(j);
    final playing = j['playing'] as bool? ?? false;
    _guestLastKnownPlaying = playing;
    final shuffle = j['shuffleEnabled'] as bool?;
    final repeat = (j['repeatMode'] as String?)?.trim().toLowerCase();
    await audio.applyRoomPlaybackModes(
      shuffleEnabled: shuffle,
      repeatMode: repeat,
    );
    if (_connectionGeneration != generation) return;
    final cs = _guestControlSeqFrom(j);
    if (cs > _guestLastControlSeq) {
      _guestLastControlSeq = cs;
    }
    if (shuffle != null) {
      _guestLastKnownShuffleEnabled = shuffle;
    }
    if (repeat != null && repeat.isNotEmpty) {
      _guestLastKnownRepeatMode = repeat;
    }
    if (ver > _guestAppliedVersion) {
      _guestAppliedVersion = ver;
      _markGuestWsApplied(ver);
    }
    if (ver > _guestLastSeenVersion) {
      _guestLastSeenVersion = ver;
    }
    _log(
      'guest metadata apply v=$ver cs=$cs shuffle=$shuffle repeat=$repeat',
    );
  }

  Future<void> _applyGuestServerPlaying(
    AudioPlayerService audio, {
    required bool serverPlaying,
  }) async {
    if (_guestEngineMatchesServer(serverPlaying, audio)) {
      _guestLastKnownPlaying = serverPlaying;
      return;
    }
    final target = Duration(milliseconds: audio.position.inMilliseconds);
    if (serverPlaying) {
      await _guestApplyPlayPauseIntent(
        audio,
        playing: true,
        target: target,
      );
    } else {
      await audio.pauseFromRoomSync();
      _guestHostPausedAtMs = DateTime.now().millisecondsSinceEpoch;
    }
    if (_guestEngineMatchesServer(serverPlaying, audio)) {
      _guestLastKnownPlaying = serverPlaying;
    } else {
      _log(
        'guest transport engine drift room=$_roomId wantPlaying=$serverPlaying engine=${audio.engineIsPlaying}',
      );
    }
  }

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

  /// Сервер (kotlinx.serialization) может не слать `type` при encodeDefaults=false.
  static bool _isRoomStatePayload(Map<String, dynamic> j) {
    final type = (j['type'] as String?)?.trim() ?? '';
    if (type == 'state') return true;
    if (type.isNotEmpty) return false;
    return j['stateVersion'] != null &&
        (j['roomId'] != null || j['trackId'] != null || j['trackKey'] != null);
  }

  bool get isConnected => _channel != null;

  Future<void> disconnect() async {
    _hostTimer?.cancel();
    _hostTimer = null;
    _hostSnapshotTimer?.cancel();
    _hostSnapshotTimer = null;
    _guestPollTimer?.cancel();
    _guestPollTimer = null;
    _guestForcedRestTimer?.cancel();
    _guestForcedRestTimer = null;
    _guestCoalescedState = null;
    _guestCoalesceFlushScheduled = false;
    _resetGuestTransportPending();
    _guestApplyDebounceTimer?.cancel();
    _guestApplyDebounceTimer = null;
    _guestPendingApplyState = null;
    _guestSnapshotTimer?.cancel();
    _guestSnapshotTimer = null;
    if (_hostListener != null && _hostAudio != null) {
      _hostAudio!.removeListener(_hostListener!);
    }
    _hostListener = null;
    _hostAudio = null;
    _hostRestSyncInFlight = false;
    _hostPendingRestSync = false;
    _guestPendingCommandPayload = null;
    _hostLastRestSyncAtMs = 0;
    _hostLastWsSyncAtMs = 0;
    _hostLastSentSignature = null;
    _hostAppliedRoomVersion = 0;
    _hostOutboundBlockers = 0;
    _hostSuppressOutboundUntilMs = 0;
    _hostListenerMutedUntilMs = 0;
    _hostRestDebounceTimer?.cancel();
    _hostRestDebounceTimer = null;
    _hostRestDebouncePayload = null;
    _hostRestDebounceAudio = null;
    _hostControlRestTimer?.cancel();
    _hostControlRestTimer = null;
    _hostControlRestSerial = 0;
    _guestLastWsStateAtMs = 0;
    _guestHostPausedAtMs = 0;
    _guestWsConnectedAtMs = 0;
    _hostWsApplyChain = Future<void>.value();
    _hostRemoteCommandChain = Future<void>.value();
    _hostRemoteCommandSerial = 0;
    _hostLocalActionSerial = 0;
    _hostRemoteAuthoritativeOverride = null;
    _hostRemoteAuthoritativeOverrideUntilMs = 0;
    _connectionGeneration++;
    try {
      await _sub?.cancel().timeout(const Duration(seconds: 2));
    } catch (_) {}
    _sub = null;
    try {
      await _channel?.sink.close().timeout(const Duration(seconds: 2));
    } catch (_) {}
    _channel = null;
    _isHost = false;
    _guestLastSeenVersion = 0;
    _guestAppliedVersion = 0;
    _guestLastControlSeq = 0;
    _guestTargetPositionSeconds = 0;
    _guestTargetPlaying = false;
    _guestTargetAnchorLocalMs = 0;
    _guestNeedsInitialHardSync = false;
    _guestNeedsFirstRealtimeHardSync = false;
    _guestFirstRealtimeStateCompleter = null;
    _lastGuestPlayPauseCommandAtMs = 0;
    _lastGuestPlayPauseCommandPositionMs = 0;
    _lastGuestPlayPauseCommandPlaying = null;
    _guestPendingPlayPausePlaying = null;
    _guestPendingPlayPauseUntilMs = 0;
    _guestCommandSerial = 0;
    _guestLastAppliedPlaybackSig = null;
    _guestLastTransportPositionSeconds = null;
    _guestLastKnownShuffleEnabled = null;
    _guestLastKnownRepeatMode = null;
    _guestLastKnownPlaying = null;
    _guestWsBootstrapBuffer.clear();
    _guestWsBootstrapDone = false;
    _guestBootstrapComplete = false;
    _guestPendingInitialState = null;
    _guestPendingInitialVersion = 0;
    _guestBootstrapApplyInFlight = false;
    _guestDeferredRoomState = null;
    _guestWsApplyChain = Future<void>.value();
    _guestTransportApplyChain = Future<void>.value();
    _roomId = null;
    _trackCache.clear();
    _participantNameCache.clear();
    _localTrackCacheByAssetPath = null;
    ListeningRoomSession.instance.setJoining(false);
  }

  Future<void> connectGuest({
    required String roomId,
    required AudioPlayerService audio,
  }) async {
    while (_connectInFlight != null) {
      try {
        await _connectInFlight;
      } catch (_) {}
    }
    final connectCompleter = Completer<void>();
    _connectInFlight = connectCompleter.future;
    try {
      await _connectGuestImpl(roomId: roomId, audio: audio);
    } finally {
      if (!connectCompleter.isCompleted) connectCompleter.complete();
      if (identical(_connectInFlight, connectCompleter.future)) {
        _connectInFlight = null;
      }
    }
  }

  Future<void> _connectGuestImpl({
    required String roomId,
    required AudioPlayerService audio,
  }) async {
    if (!_isHost &&
        _roomId == roomId &&
        _channel != null &&
        _guestBootstrapComplete &&
        ListeningRoomSession.instance.active) {
      _log('guest reconnect skipped already room=$roomId');
      await forceGuestSnapshotSync(audio);
      return;
    }
    await disconnect();
    if (!ListeningRoomSession.instance.active) return;
    final generation = _connectionGeneration;
    final acc = await AuthSessionStore.readAccount();
    final token = acc?.sessionToken.trim() ?? '';
    if (token.isEmpty) throw StateError('Not logged in');
    _isHost = false;
    _roomId = roomId;
    _guestLastSeenVersion = 0;
    _guestNeedsInitialHardSync = true;
    _guestNeedsFirstRealtimeHardSync = true;
    _guestFirstRealtimeStateCompleter = Completer<void>();
    ListeningRoomSession.instance.setJoining(true);
    _log('guest connect start room=$roomId gen=$generation');
    var initialBootstrapOk = false;
    try {
    _guestWsBootstrapDone = false;
    _guestBootstrapComplete = false;
    _guestWsBootstrapBuffer.clear();
    final uri = Uri.parse(wsUrl(roomId, token));
    _channel = WebSocketChannel.connect(uri);
    _guestWsConnectedAtMs = DateTime.now().millisecondsSinceEpoch;
    // Подписка до ready: иначе теряем snapshot сразу после join на сервере.
    _sub = _channel!.stream.listen(
      (raw) {
        if (raw is! String) {
          _log('guest ws recv non-string room=$roomId type=${raw.runtimeType}');
          return;
        }
        if (!_guestWsBootstrapDone) {
          _bufferGuestWsDuringBootstrap(raw, roomId);
          return;
        }
        _enqueueGuestWsMessage(raw, audio, generation);
      },
      onError: (Object e, StackTrace st) {
        _log('guest ws error room=$roomId error=$e');
        _scheduleGuestWsReconnect(roomId, audio, generation);
      },
      onDone: () {
        _log('guest ws done room=$roomId');
        _scheduleGuestWsReconnect(roomId, audio, generation);
      },
      cancelOnError: false,
    );
    try {
      await _channel!.ready.timeout(const Duration(seconds: 10));
      _log('guest ws ready room=$roomId');
    } catch (e) {
      _log('guest ws ready timeout room=$roomId error=$e');
    }
    try {
      try {
        final initial = await ColistenApi().getRoomState(roomId);
        _log(
          'guest initial state room=$roomId v=${initial.stateVersion} trackId=${initial.trackId} key=${initial.trackKey} pos=${initial.positionSeconds.toStringAsFixed(3)} playing=${initial.playing} queue=${initial.queueTrackKeys.length}/${initial.queueTrackIds.length}',
        );
        if (initial.stateVersion > _guestAppliedVersion) {
          _guestPendingInitialState = _roomStateMapFromDto(initial);
          _guestPendingInitialVersion = initial.stateVersion;
          _guestLastControlSeq = initial.controlSeq;
          initialBootstrapOk = true;
        }
      } catch (_) {}
      _finishGuestBootstrap(
        roomId: roomId,
        audio: audio,
        generation: generation,
        initialBootstrapOk: initialBootstrapOk,
      );
      final firstRealtime = _guestFirstRealtimeStateCompleter;
      if (firstRealtime != null && !firstRealtime.isCompleted) {
        try {
          await firstRealtime.future.timeout(
            const Duration(milliseconds: 1200),
          );
        } catch (_) {}
      }
      if (_guestLastWsStateAtMs == 0) {
        unawaited(
          _guestPollRoomState(
            roomId,
            audio,
            generation,
            forceApply: true,
          ),
        );
      }
    } finally {
      ListeningRoomSession.instance.setJoining(false);
    }
    } catch (e) {
      _log('guest connect failed room=$roomId gen=$generation error=$e');
      if (_connectionGeneration == generation && !_isHost) {
        await disconnect();
      }
      rethrow;
    }
  }

  void _bufferGuestWsDuringBootstrap(String raw, String roomId) {
    _guestWsBootstrapBuffer.add(raw);
    if (_guestWsBootstrapBuffer.length > 8) {
      final latest = _latestGuestBootstrapMessage(_guestWsBootstrapBuffer);
      _guestWsBootstrapBuffer.clear();
      if (latest != null) {
        _guestWsBootstrapBuffer.add(latest);
      }
    }
    _log(
      'guest ws buffered during bootstrap room=$roomId len=${_guestWsBootstrapBuffer.length}',
    );
  }

  String? _latestGuestBootstrapMessage(List<String> rawMessages) {
    String? bestRaw;
    var bestVersion = -1;
    var bestControlSeq = -1;
    for (final raw in rawMessages) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        if (!_isRoomStatePayload(j)) continue;
        final ver = _stateVersionFromJson(j);
        final cs = _guestControlSeqFrom(j);
        if (ver > bestVersion ||
            (ver == bestVersion && cs >= bestControlSeq)) {
          bestVersion = ver;
          bestControlSeq = cs;
          bestRaw = raw;
        }
      } catch (_) {}
    }
    return bestRaw;
  }

  void _finishGuestBootstrap({
    required String roomId,
    required AudioPlayerService audio,
    required int generation,
    required bool initialBootstrapOk,
  }) {
    _guestWsBootstrapDone = true;
    final dropped = _guestWsBootstrapBuffer.length;
    final latestRaw = _latestGuestBootstrapMessage(_guestWsBootstrapBuffer);
    _guestWsBootstrapBuffer.clear();

    Map<String, dynamic>? latestMap;
    var latestVer = 0;
    var latestCs = 0;
    if (latestRaw != null) {
      try {
        latestMap = jsonDecode(latestRaw) as Map<String, dynamic>;
        latestVer = _stateVersionFromJson(latestMap);
        latestCs = _guestControlSeqFrom(latestMap);
      } catch (_) {}
    }

    final pendingInitial = _guestPendingInitialState;
    final pendingInitialVer = _guestPendingInitialVersion;
    _guestPendingInitialState = null;
    _guestPendingInitialVersion = 0;

    final useLatestWs = latestMap != null &&
        latestVer > 0 &&
        latestVer >= pendingInitialVer;

    if (useLatestWs) {
      if (latestCs > _guestLastControlSeq) {
        _guestLastControlSeq = latestCs;
      }
      _log(
        'guest bootstrap apply latest-ws room=$roomId droppedBuffered=$dropped v=$latestVer cs=$latestCs restV=$pendingInitialVer',
      );
      _runGuestBootstrapApply(
        roomId: roomId,
        audio: audio,
        generation: generation,
        label: 'bootstrap-ws',
        apply: () => _applyGuestState(
          latestMap!,
          audio,
          generation: generation,
          forceTrackReload: true,
          forcePositionSync: true,
        ),
      );
      return;
    } else if (pendingInitial != null && pendingInitialVer > _guestAppliedVersion) {
      _log(
        'guest bootstrap apply initial-rest room=$roomId v=$pendingInitialVer',
      );
      _runGuestBootstrapApply(
        roomId: roomId,
        audio: audio,
        generation: generation,
        label: 'bootstrap-rest',
        apply: () => _applyGuestState(
          pendingInitial,
          audio,
          generation: generation,
          forceTrackReload: true,
          forcePositionSync: true,
        ),
      );
      return;
    } else if (!initialBootstrapOk) {
      _log('guest bootstrap no snapshot room=$roomId, REST fallback');
      _runGuestBootstrapApply(
        roomId: roomId,
        audio: audio,
        generation: generation,
        label: 'bootstrap-fallback',
        apply: () => forceGuestSnapshotSync(
          audio,
          forceTrackReload: true,
          forcePositionSync: true,
        ),
      );
      return;
    }
    _onGuestBootstrapReady(roomId: roomId, audio: audio, generation: generation);
  }

  void _onGuestBootstrapReady({
    required String roomId,
    required AudioPlayerService audio,
    required int generation,
  }) {
    if (_connectionGeneration != generation ||
        _isHost ||
        _roomId != roomId ||
        !ListeningRoomSession.instance.active) {
      return;
    }
    _guestBootstrapComplete = true;
    ListeningRoomSession.instance.setJoining(false);
    _guestPollTimer?.cancel();
    _guestPollTimer = Timer.periodic(
      const Duration(milliseconds: _guestPollIntervalMs),
      (_) {
        unawaited(_guestPollRoomState(roomId, audio, generation));
      },
    );
    _guestForcedRestTimer?.cancel();
    _guestForcedRestTimer = Timer.periodic(
      const Duration(milliseconds: _guestForcedRestSyncMs),
      (_) {
        unawaited(_guestForcedRestSync(roomId, audio, generation));
      },
    );
  }

  void _runGuestBootstrapApply({
    required String roomId,
    required AudioPlayerService audio,
    required int generation,
    required String label,
    required Future<void> Function() apply,
  }) {
    _guestBootstrapApplyInFlight = true;
    unawaited(() async {
      try {
        if (_connectionGeneration != generation ||
            _isHost ||
            _roomId != roomId ||
            !ListeningRoomSession.instance.active) {
          return;
        }
        await apply();
        if (_connectionGeneration != generation) return;
        _log('guest bootstrap apply done room=$roomId label=$label');
      } catch (e) {
        _log('guest bootstrap apply error room=$roomId label=$label error=$e');
      } finally {
        if (_connectionGeneration != generation) {
          _guestBootstrapApplyInFlight = false;
          return;
        }
        _guestBootstrapApplyInFlight = false;
        final deferred = _guestDeferredRoomState;
        _guestDeferredRoomState = null;
        if (deferred != null) {
          _log(
            'guest bootstrap flush deferred room=$roomId v=${_stateVersionFromJson(deferred)}',
          );
          _enqueueGuestApply(
            generation,
            () => _applyGuestStateFromWire(
              deferred,
              audio,
              generation: generation,
            ),
            debugLabel: 'deferred-after-bootstrap',
          );
        }
        _onGuestBootstrapReady(
          roomId: roomId,
          audio: audio,
          generation: generation,
        );
        unawaited(
          _guestPollRoomState(
            roomId,
            audio,
            generation,
            forceApply: true,
          ),
        );
      }
    }());
  }

  void _scheduleGuestWsReconnect(
    String roomId,
    AudioPlayerService audio,
    int generation,
  ) {
    if (_isHost ||
        _connectionGeneration != generation ||
        _roomId != roomId ||
        !ListeningRoomSession.instance.active) {
      return;
    }
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 400), () async {
        if (_isHost ||
            _connectionGeneration != generation ||
            _roomId != roomId ||
            !ListeningRoomSession.instance.active) {
          return;
        }
        _log('guest ws reconnect room=$roomId');
        try {
          final acc = await AuthSessionStore.readAccount();
          final token = acc?.sessionToken.trim() ?? '';
          if (token.isEmpty) return;
          try {
            await _sub?.cancel();
          } catch (_) {}
          _sub = null;
          try {
            await _channel?.sink.close();
          } catch (_) {}
          _channel = null;
          final uri = Uri.parse(wsUrl(roomId, token));
          _channel = WebSocketChannel.connect(uri);
          _guestWsConnectedAtMs = DateTime.now().millisecondsSinceEpoch;
          _sub = _channel!.stream.listen(
            (raw) {
              if (raw is! String) return;
              _enqueueGuestWsMessage(raw, audio, generation);
            },
            onError: (Object e, StackTrace st) {
              _log('guest ws reconnect error room=$roomId error=$e');
            },
            onDone: () {
              _log('guest ws reconnect done room=$roomId');
            },
            cancelOnError: false,
          );
          await _channel!.ready.timeout(const Duration(seconds: 8));
          _log('guest ws reconnect ready room=$roomId');
        } catch (e) {
          _log('guest ws reconnect failed room=$roomId error=$e');
        }
        await _guestPollRoomState(
          roomId,
          audio,
          generation,
          forceApply: true,
        );
      }),
    );
  }

  Future<void> _guestForcedRestSync(
    String roomId,
    AudioPlayerService audio,
    int generation, {
    bool forceApply = false,
  }) async {
    if (!_guestBootstrapComplete ||
        _connectionGeneration != generation ||
        _isHost ||
        _roomId != roomId ||
        !ListeningRoomSession.instance.active) {
      return;
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final localEngineDrift = _guestEngineDrifted(audio);
    if (!forceApply &&
        !localEngineDrift &&
        _guestLastWsStateAtMs > 0 &&
        nowMs - _guestLastWsStateAtMs < _guestPollWsSilenceMs) {
      return;
    }
    await _guestPollRoomState(
      roomId,
      audio,
      generation,
      forceApply: forceApply || localEngineDrift,
    );
  }

  void _enqueueGuestWsMessage(
    String raw,
    AudioPlayerService audio,
    int generation,
  ) {
    _enqueueGuestApply(
      generation,
      () => _handleGuestMessage(raw, audio, generation),
      debugLabel: 'ws',
    );
  }

  Future<void> _refreshGuestSnapshot(
    String roomId,
    AudioPlayerService audio, {
    required int generation,
    int delayMs = 700,
    bool forceTrackReload = false,
    bool forcePositionSync = false,
  }) async {
    await Future<void>.delayed(Duration(milliseconds: delayMs));
    if (_connectionGeneration != generation) return;
    if (_isHost || _roomId != roomId || !ListeningRoomSession.instance.active) {
      return;
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (!forceTrackReload && !forcePositionSync) {
      final wsSilent = _guestLastWsStateAtMs == 0 ||
          nowMs - _guestLastWsStateAtMs >= _guestWsSnapshotSilenceMs;
      if (!wsSilent) return;
    }
    try {
      final state = await ColistenApi().getRoomState(roomId);
      _log(
        'guest snapshot room=$roomId v=${state.stateVersion} trackId=${state.trackId} key=${state.trackKey} pos=${state.positionSeconds.toStringAsFixed(3)} playing=${state.playing}',
      );
      if (state.stateVersion <= _guestAppliedVersion) return;
      await _runOnGuestApplyChain(generation, () async {
        if (state.stateVersion <= _guestAppliedVersion) return;
        await _applyGuestState(
          _roomStateMapFromDto(state),
          audio,
          generation: generation,
          forceTrackReload: forceTrackReload,
          forcePositionSync: forcePositionSync,
        );
      });
    } catch (_) {}
  }

  Future<void> forceGuestSnapshotSync(
    AudioPlayerService audio, {
    bool forceTrackReload = true,
    bool forcePositionSync = false,
  }) async {
    final generation = _connectionGeneration;
    final roomId = _roomId;
    if (_isHost ||
        roomId == null ||
        roomId.isEmpty ||
        !ListeningRoomSession.instance.active) {
      return;
    }
    try {
      final state = await ColistenApi().getRoomState(roomId);
      _log(
        'guest force snapshot room=$roomId v=${state.stateVersion} trackId=${state.trackId} key=${state.trackKey} pos=${state.positionSeconds.toStringAsFixed(3)} playing=${state.playing} forceReload=$forceTrackReload',
      );
      final engineDrift = _guestOutOfSyncWithServer(state.playing, audio);
      if (state.stateVersion <= _guestAppliedVersion &&
          !forceTrackReload &&
          !forcePositionSync &&
          !engineDrift) {
        return;
      }
      await _runOnGuestApplyChain(generation, () async {
        if (state.stateVersion <= _guestAppliedVersion &&
            !forceTrackReload &&
            !forcePositionSync &&
            !engineDrift) {
          return;
        }
        await _applyGuestState(
          _roomStateMapFromDto(state),
          audio,
          generation: generation,
          forceTrackReload: forceTrackReload,
          forcePositionSync: forcePositionSync,
        );
      });
    } catch (_) {}
  }

  ({int? trackId, String? trackKey}) _resolveHostTrackFields(
    AudioPlayerService audio,
  ) {
    final api = TracksApi();
    final playablePath = audio.currentPlayablePath?.trim() ?? '';
    if (playablePath.isNotEmpty) {
      final fromPath = api.parseServerTrackId(playablePath);
      if (fromPath != null) {
        return (trackId: fromPath, trackKey: 'srv:$fromPath');
      }
      final key = api.trackKeyForPaths(
        assetPath: playablePath,
        audioFilePath: playablePath,
      );
      if (key.isNotEmpty) return (trackId: null, trackKey: key);
    }
    final current = audio.currentTrack;
    if (current == null) return (trackId: null, trackKey: null);
    return (
      trackId: api.resolveServerTrackId(
        assetPath: current.assetPath,
        audioFilePath: current.audioFilePath,
      ),
      trackKey: api.trackKeyForPaths(
        assetPath: current.assetPath,
        audioFilePath: current.audioFilePath,
      ),
    );
  }

  Map<String, dynamic> _hostStatePayload(AudioPlayerService audio) {
    final resolved = _resolveHostTrackFields(audio);
    final tid = resolved.trackId;
    final trackKey = resolved.trackKey;
    final payload = <String, dynamic>{
      'type': 'host_state',
      'queueTrackIds': _queueTrackIdsFromAudio(audio),
      'queueTrackKeys': _queueTrackKeysFromAudio(audio),
      'position': audio.enginePosition.inMilliseconds / 1000.0,
      'playing': audio.engineIsPlaying,
      'shuffleEnabled': audio.shuffleEnabled,
      'repeatMode': audio.roomRepeatModeWire,
    };
    if (_hostAppliedRoomVersion > 0) {
      payload['baseStateVersion'] = _hostAppliedRoomVersion;
    }
    if (tid != null) payload['trackId'] = tid;
    if (trackKey != null) payload['trackKey'] = trackKey;
    return payload;
  }

  Map<String, dynamic> _hostStatePayloadForSend(
    AudioPlayerService audio, {
    required bool explicitAction,
  }) {
    final payload = _hostStatePayload(audio);
    if (explicitAction) {
      payload['explicitAction'] = true;
    }
    return payload;
  }

  bool _payloadHasTransport(Map<String, dynamic> payload) =>
      payload.containsKey('playing') || payload.containsKey('position');

  bool _canSendHostWs(Map<String, dynamic> payload, {required bool forceWs}) {
    if (forceWs) return true;
    final hasTrack =
        payload['trackId'] != null ||
        (payload['trackKey'] is String &&
            (payload['trackKey'] as String).isNotEmpty);
    final hasQueue =
        ((payload['queueTrackIds'] as List?)?.isNotEmpty ?? false) ||
        ((payload['queueTrackKeys'] as List?)?.isNotEmpty ?? false);
    final explicit = payload['explicitAction'] == true;
    return hasTrack || hasQueue || (explicit && _payloadHasTransport(payload));
  }

  int _guestControlSeqFrom(Map<String, dynamic> j) =>
      (j['controlSeq'] as num?)?.toInt() ?? 0;

  bool _guestControlSeqAdvanced(Map<String, dynamic> j) =>
      _guestControlSeqFrom(j) > _guestLastControlSeq;

  int _stateVersionFromJson(Map<String, dynamic> j) =>
      (j['stateVersion'] as num?)?.toInt() ?? 0;

  /// Устаревший snapshot: отклоняем по stateVersion и controlSeq (важно для play/pause).
  bool _guestIncomingStateIsObsolete(Map<String, dynamic> j) {
    final ver = _stateVersionFromJson(j);
    final cs = _guestControlSeqFrom(j);
    if (ver > 0 && ver < _guestAppliedVersion) return true;
    if (cs > 0 && cs < _guestLastControlSeq) return true;
    return false;
  }

  /// Очередь transport: при burst WS/poll применяем только последний snapshot,
  /// иначе await play/pause блокирует цепочку и гость «залипает».
  void _enqueueGuestTransportApply(
    int generation,
    Map<String, dynamic> state,
    int ver,
    AudioPlayerService audio, {
    String? debugLabel,
  }) {
    if (_shouldReplaceGuestPendingTransport(generation, state)) {
      _guestPendingTransportState = Map<String, dynamic>.from(state);
      _guestPendingTransportVer = ver;
      _guestPendingTransportGeneration = generation;
      _guestPendingTransportAudio = audio;
    }
    if (_guestTransportDrainQueued) return;
    _guestTransportDrainQueued = true;
    _guestTransportApplyChain = _guestTransportApplyChain.then((_) async {
      try {
      while (_guestPendingTransportState != null) {
        if (_connectionGeneration != _guestPendingTransportGeneration ||
            _isHost ||
            !ListeningRoomSession.instance.active) {
          _resetGuestTransportPending();
          return;
        }
        final j = _guestPendingTransportState!;
        final applyVer = _guestPendingTransportVer;
        final applyGen = _guestPendingTransportGeneration;
        final applyAudio = _guestPendingTransportAudio;
        _guestPendingTransportState = null;
        if (applyAudio == null) continue;
        try {
          await _applyGuestTransportFromWs(j, applyAudio, applyGen, applyVer);
        } catch (e) {
          _log(
            'guest transport apply error room=$_roomId label=${debugLabel ?? "transport"} error=$e',
          );
        }
      }
      } finally {
        _guestTransportDrainQueued = false;
      }
    });
  }

  void _enqueueGuestApply(
    int generation,
    Future<void> Function() apply, {
    String? debugLabel,
  }) {
    _guestWsApplyChain = _guestWsApplyChain.then((_) async {
      if (_connectionGeneration != generation) {
        _log(
          'guest apply dropped generation room=$_roomId label=${debugLabel ?? "apply"} gen=$generation current=$_connectionGeneration',
        );
        return;
      }
      if (_isHost) {
        _log(
          'guest apply dropped isHost room=$_roomId label=${debugLabel ?? "apply"}',
        );
        return;
      }
      if (!ListeningRoomSession.instance.active) {
        _log(
          'guest apply dropped inactive room=$_roomId label=${debugLabel ?? "apply"}',
        );
        return;
      }
      try {
        await apply();
      } catch (e) {
        _log(
          'guest apply error room=$_roomId label=${debugLabel ?? "apply"} error=$e',
        );
      }
    });
  }

  void _coalesceGuestRoomState(
    Map<String, dynamic> j,
    AudioPlayerService audio,
    int generation,
  ) {
    if (_guestBootstrapApplyInFlight) {
      final incomingVer = _stateVersionFromJson(j);
      final deferredVer = _guestDeferredRoomState == null
          ? -1
          : _stateVersionFromJson(_guestDeferredRoomState!);
      if (incomingVer >= deferredVer) {
        _guestDeferredRoomState = j;
      }
      _log(
        'guest ws defer full apply during bootstrap room=$_roomId v=$incomingVer',
      );
      return;
    }
    final incomingVer = _stateVersionFromJson(j);
    final incomingCs = _guestControlSeqFrom(j);
    final current = _guestCoalescedState;
    if (current != null) {
      final curVer = _stateVersionFromJson(current);
      final curCs = _guestControlSeqFrom(current);
      if (incomingVer < curVer ||
          (incomingVer == curVer && incomingCs < curCs)) {
        return;
      }
    }
    _guestCoalescedState = j;
    if (_guestCoalesceFlushScheduled) return;
    _guestCoalesceFlushScheduled = true;
    _enqueueGuestApply(
      generation,
      () => _flushCoalescedGuestState(audio, generation),
      debugLabel: 'coalesced',
    );
  }

  Future<void> _flushCoalescedGuestState(
    AudioPlayerService audio,
    int generation,
  ) async {
    _guestCoalesceFlushScheduled = false;
    while (_guestCoalescedState != null) {
      final j = _guestCoalescedState!;
      _guestCoalescedState = null;
      await _applyGuestStateFromWire(j, audio, generation: generation);
      if (_connectionGeneration != generation) return;
    }
  }

  void _markGuestWsApplied(int version) {
    if (version > 0) {
      _guestLastWsStateAtMs = DateTime.now().millisecondsSinceEpoch;
    }
  }

  Future<void> _runOnGuestApplyChain(
    int generation,
    Future<void> Function() apply,
  ) {
    final done = Completer<void>();
    _enqueueGuestApply(
      generation,
      () async {
        try {
          await apply();
        } finally {
          if (!done.isCompleted) done.complete();
        }
      },
    );
    return done.future;
  }

  Map<String, dynamic> _roomStateMapFromDto(ColistenRoomStateDto state) =>
      <String, dynamic>{
        'stateVersion': state.stateVersion,
        'controlSeq': state.controlSeq,
        'isOpen': state.isOpen,
        'trackId': state.trackId,
        'trackKey': state.trackKey,
        'queueTrackIds': state.queueTrackIds,
        'queueTrackKeys': state.queueTrackKeys,
        'positionSeconds': state.positionSeconds,
        'playing': state.playing,
        'shuffleEnabled': state.shuffleEnabled,
        'repeatMode': state.repeatMode,
        'controlPauseHostOnly': state.controlPauseHostOnly,
        'controlSeekHostOnly': state.controlSeekHostOnly,
        'controlShuffleHostOnly': state.controlShuffleHostOnly,
        'controlRepeatHostOnly': state.controlRepeatHostOnly,
        'controlSkipHostOnly': state.controlSkipHostOnly,
        'controlPlaylistHostOnly': state.controlPlaylistHostOnly,
        'participantIds': state.participantIds,
        'wallClockMs': state.wallClockMs,
      };

  /// Дискретная команда хоста: WS `command` + короткий REST-ack (второй broadcast с controlSeq).
  void _pushHostControlPacket(
    AudioPlayerService audio, {
    Map<String, dynamic>? overrides,
  }) {
    if (!_isHost) return;
    // Не подмешивать override от прошлой команды — иначе гость получает
    // предыдущее playing/position (отставание ровно на одно действие).
    _hostRemoteAuthoritativeOverride = null;
    _hostRemoteAuthoritativeOverrideUntilMs = 0;
    final payload = _hostStatePayloadForSend(audio, explicitAction: true);
    payload['type'] = 'command';
    if (overrides != null) {
      for (final entry in overrides.entries) {
        if (entry.value != null) {
          payload[entry.key] = entry.value;
        }
      }
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    _hostLastWsSyncAtMs = nowMs;
    _hostLastSentSignature = _hostStateSignature(payload);
    _log(
      'host control packet room=$_roomId trackId=${payload['trackId']} key=${payload['trackKey']} pos=${((payload['position'] as num?)?.toDouble() ?? 0).toStringAsFixed(3)} playing=${payload['playing']}',
    );
    if (_canSendHostWs(payload, forceWs: true)) {
      _sink(jsonEncode(payload));
    }
    _scheduleHostControlRestAck(audio, Map<String, dynamic>.from(payload));
  }

  /// REST-ack для `command`: один отложенный запрос с последним payload.
  /// Иначе при быстром play→pause→play срабатывает таймер прошлой паузы и гость
  /// получает playing=false уже после resume по WS.
  void _scheduleHostControlRestAck(
    AudioPlayerService audio,
    Map<String, dynamic> payload,
  ) {
    _hostControlRestTimer?.cancel();
    final serial = ++_hostControlRestSerial;
    _hostControlRestTimer = Timer(const Duration(milliseconds: 50), () {
      if (serial != _hostControlRestSerial) return;
      if (!_isHost || !ListeningRoomSession.instance.active) return;
      _syncHostStateViaRest(audio, force: true, payloadOverride: payload);
    });
  }

  String _hostStateSignature(Map<String, dynamic> payload) {
    final playing = payload['playing'] as bool? ?? false;
    final pos = ((payload['position'] as num?)?.toDouble() ?? 0) * 1000;
    final posBucket = playing ? (pos / 1000).round() : (pos / 250).round();
    final queueKeys = ((payload['queueTrackKeys'] as List?) ?? const [])
        .map((e) => e.toString())
        .join(',');
    final queueIds = ((payload['queueTrackIds'] as List?) ?? const [])
        .map((e) => e.toString())
        .join(',');
    return [
      payload['trackKey'],
      payload['trackId'],
      queueKeys,
      queueIds,
      posBucket,
      playing,
      payload['shuffleEnabled'],
      payload['repeatMode'],
    ].join('|');
  }

  void _syncHostStateViaRest(
    AudioPlayerService audio, {
    bool force = false,
    Map<String, dynamic>? payloadOverride,
  }) {
    final roomId = _roomId;
    if (!_isHost || roomId == null || roomId.isEmpty) return;
    final payload = payloadOverride == null
        ? _hostStatePayloadForSend(audio, explicitAction: force)
        : Map<String, dynamic>.from(payloadOverride);
    if (force) {
      payload['explicitAction'] = true;
    }
    _applyHostRemoteAuthoritativeOverride(payload);
    if (_hostRestSyncInFlight) {
      if (force) {
        _log('host rest pending room=$roomId');
        _hostPendingRestSync = true;
        _hostRestDebouncePayload = Map<String, dynamic>.from(payload);
        _hostRestDebounceAudio = audio;
      }
      return;
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (!force && nowMs - _hostLastRestSyncAtMs < 1200) return;
    _hostRestSyncInFlight = true;
    _hostLastRestSyncAtMs = nowMs;
    _hostPendingRestSync = false;
    final trackId = (payload['trackId'] as num?)?.toInt();
    final trackKey = payload['trackKey'] as String?;
    final queueTrackIds = ((payload['queueTrackIds'] as List?) ?? const [])
        .map((e) => (e as num?)?.toInt())
        .whereType<int>()
        .toList();
    final queueTrackKeys = ((payload['queueTrackKeys'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList();
    _log(
      'host rest send room=$roomId trackId=$trackId key=$trackKey pos=${((payload['position'] as num?)?.toDouble() ?? 0).toStringAsFixed(3)} playing=${payload['playing']} shuffle=${payload['shuffleEnabled']} repeat=${payload['repeatMode']} queue=${queueTrackKeys.length}/${queueTrackIds.length}',
    );
    unawaited(
      ColistenApi()
          .pushHostState(
            roomId: roomId,
            messageType: (payload['type'] as String?) ?? 'host_state',
            trackId: trackId,
            trackKey: trackKey,
            queueTrackIds: queueTrackIds,
            queueTrackKeys: queueTrackKeys,
            positionSeconds: (payload['position'] as num?)?.toDouble() ?? 0,
            playing: payload['playing'] as bool? ?? false,
            shuffleEnabled: payload['shuffleEnabled'] as bool? ?? false,
            repeatMode: payload['repeatMode'] as String? ?? 'off',
            baseStateVersion: (payload['baseStateVersion'] as num?)?.toInt(),
            explicitAction: payload['explicitAction'] == true,
          )
          .then((state) {
            if (state != null) {
              _applyRoomDtoToSession(state);
              _noteHostRoomVersion(state.stateVersion);
            }
            _log('host rest ok room=$roomId');
          })
          .catchError((e) {
            _log('host rest error room=$roomId error=$e');
            return null;
          })
          .whenComplete(() {
            _hostRestSyncInFlight = false;
            if (_hostPendingRestSync && _isHost && _roomId == roomId) {
              _hostPendingRestSync = false;
              final pendingAudio = _hostRestDebounceAudio ?? audio;
              final pendingPayload = _hostRestDebouncePayload;
              _hostRestDebouncePayload = null;
              _hostRestDebounceAudio = null;
              _syncHostStateViaRest(
                pendingAudio,
                force: true,
                payloadOverride: pendingPayload,
              );
            }
          }),
    );
  }

  void _scheduleDebouncedHostRest(
    AudioPlayerService audio,
    Map<String, dynamic> payload,
  ) {
    _hostRestDebounceAudio = audio;
    _hostRestDebouncePayload = Map<String, dynamic>.from(payload);
    _hostRestDebounceTimer?.cancel();
    _hostRestDebounceTimer = Timer(const Duration(milliseconds: 350), () {
      final a = _hostRestDebounceAudio;
      final p = _hostRestDebouncePayload;
      if (a == null || p == null || !_isHost || !ListeningRoomSession.instance.active) {
        return;
      }
      _syncHostStateViaRest(a, force: true, payloadOverride: p);
    });
  }

  void _pushHostStateNow(
    AudioPlayerService audio, {
    bool forceRest = false,
    bool forceWs = false,
    Map<String, dynamic>? guestPayloadOverride,
    Map<String, dynamic>? hostPayloadOverride,
    bool includeQueueForGuest = false,
  }) {
    if (!_isHost) {
      final roomId = _roomId;
      if (!ListeningRoomSession.instance.active ||
          roomId == null ||
          roomId.isEmpty) {
        return;
      }
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (!forceWs && nowMs - _hostLastWsSyncAtMs < 120) return;
      _hostLastWsSyncAtMs = nowMs;
      final payload =
          (guestPayloadOverride == null
                ? _hostStatePayload(audio)
                : Map<String, dynamic>.from(guestPayloadOverride))
            ..['type'] = 'command';
      if (guestPayloadOverride == null && !includeQueueForGuest) {
        // Regular command actions (play/pause/seek/skip/shuffle/repeat)
        // must not mutate playlist implicitly.
        payload.remove('queueTrackIds');
        payload.remove('queueTrackKeys');
      }
      _log(
        'guest command room=$_roomId ws=$forceWs rest=$forceRest trackId=${payload['trackId']} key=${payload['trackKey']} pos=${((payload['position'] as num?)?.toDouble() ?? 0).toStringAsFixed(3)} playing=${payload['playing']} shuffle=${payload['shuffleEnabled']} repeat=${payload['repeatMode']}',
      );
      if (forceWs) {
        _sink(jsonEncode(payload));
      }
      if (forceRest && _hostRestSyncInFlight) {
        _guestPendingCommandPayload = Map<String, dynamic>.from(payload);
        return;
      }
      if (forceRest) {
        _hostRestSyncInFlight = true;
        final trackId = (payload['trackId'] as num?)?.toInt();
        final trackKey = payload['trackKey'] as String?;
        final queueTrackIdsRaw = payload['queueTrackIds'] as List?;
        final queueTrackKeysRaw = payload['queueTrackKeys'] as List?;
        final queueTrackIds = queueTrackIdsRaw
            ?.map((e) => (e as num?)?.toInt())
            .whereType<int>()
            .toList();
        final queueTrackKeys = queueTrackKeysRaw
            ?.map((e) => e.toString())
            .toList();
        unawaited(
          ColistenApi()
              .pushHostState(
                roomId: roomId,
                messageType: 'command',
                trackId: trackId,
                trackKey: trackKey,
                queueTrackIds: queueTrackIds,
                queueTrackKeys: queueTrackKeys,
                positionSeconds: (payload['position'] as num?)?.toDouble() ?? 0,
                playing: payload['playing'] as bool? ?? false,
                shuffleEnabled: payload['shuffleEnabled'] as bool? ?? false,
                repeatMode: payload['repeatMode'] as String? ?? 'off',
              )
              .then((state) async {
                if (state != null) {
                  _applyRoomDtoToSession(state);
                  if (_isHost) {
                    _noteHostRoomVersion(state.stateVersion);
                  }
                }
                _log('guest rest command ok room=$roomId');
              })
              .catchError((e) {
                _log('guest rest push error room=$roomId error=$e');
                return null;
              })
              .whenComplete(() {
                _hostRestSyncInFlight = false;
                final pending = _guestPendingCommandPayload;
                _guestPendingCommandPayload = null;
                if (pending != null &&
                    !_isHost &&
                    _roomId == roomId &&
                    ListeningRoomSession.instance.active) {
                  _pushHostStateNow(
                    audio,
                    forceRest: true,
                    forceWs: false,
                    guestPayloadOverride: pending,
                  );
                }
              }),
        );
      }
      return;
    }
    if (_hostOutboundBlockers > 0 && !forceRest && !forceWs) {
      _log(
        'host push blocked room=$_roomId blockers=$_hostOutboundBlockers forceRest=$forceRest forceWs=$forceWs',
      );
      return;
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (!forceRest && !forceWs && nowMs < _hostSuppressOutboundUntilMs) {
      return;
    }
    final payload = _hostStatePayloadForSend(
      audio,
      explicitAction: forceRest || forceWs,
    );
    _applyHostRemoteAuthoritativeOverride(payload);
    if (hostPayloadOverride != null) {
      for (final entry in hostPayloadOverride.entries) {
        if (entry.value != null) {
          payload[entry.key] = entry.value;
        }
      }
    }
    final signature = _hostStateSignature(payload);
    if (!forceRest && !forceWs && signature == _hostLastSentSignature) return;
    final hasTrack = payload['trackId'] != null || payload['trackKey'] != null;
    final hasQueue =
        ((payload['queueTrackIds'] as List?)?.isNotEmpty ?? false) ||
        ((payload['queueTrackKeys'] as List?)?.isNotEmpty ?? false);
    _log(
      'host push room=$_roomId ws=${_channel != null} hasTrack=$hasTrack hasQueue=$hasQueue trackId=${payload['trackId']} key=${payload['trackKey']} pos=${((payload['position'] as num?)?.toDouble() ?? 0).toStringAsFixed(3)} playing=${payload['playing']} shuffle=${payload['shuffleEnabled']} repeat=${payload['repeatMode']}',
    );
    final shouldSendWs = forceWs || nowMs - _hostLastWsSyncAtMs >= 280;
    var sent = false;
    if (_canSendHostWs(payload, forceWs: forceWs) && shouldSendWs) {
      _hostLastWsSyncAtMs = nowMs;
      _sink(jsonEncode(payload));
      sent = true;
    }
    // REST только для явных действий (play/pause/очередь). Иначе гость получает
    // устаревшие snapshot с промежуточными stateVersion и «отстаёт» на секунды.
    if (forceRest) {
      _syncHostStateViaRest(audio, force: true, payloadOverride: payload);
      sent = true;
    }
    if (sent) {
      _hostLastSentSignature = signature;
    }
  }

  void _setHostRemoteAuthoritativeOverride(Map<String, dynamic> command) {
    final override = _authoritativeRemoteAckPayload(command);
    if (override.isEmpty) return;
    _hostRemoteAuthoritativeOverride = override;
    _hostRemoteAuthoritativeOverrideUntilMs =
        DateTime.now().millisecondsSinceEpoch + 2200;
  }

  void _setHostAuthoritativeOverride(
    Map<String, dynamic> override, {
    int durationMs = 2200,
  }) {
    if (override.isEmpty) return;
    _hostRemoteAuthoritativeOverride = Map<String, dynamic>.from(override);
    _hostRemoteAuthoritativeOverrideUntilMs =
        DateTime.now().millisecondsSinceEpoch + durationMs;
  }

  void _applyHostRemoteAuthoritativeOverride(Map<String, dynamic> payload) {
    final override = _hostRemoteAuthoritativeOverride;
    if (override == null) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs >= _hostRemoteAuthoritativeOverrideUntilMs) {
      _hostRemoteAuthoritativeOverride = null;
      _hostRemoteAuthoritativeOverrideUntilMs = 0;
      return;
    }
    for (final entry in override.entries) {
      if (entry.value != null) {
        payload[entry.key] = entry.value;
      }
    }
  }

  Future<void> connectHost({
    required String roomId,
    required AudioPlayerService audio,
  }) async {
    if (_isHost &&
        _roomId == roomId &&
        _channel != null &&
        ListeningRoomSession.instance.active) {
      _log('host reconnect skipped already room=$roomId');
      _pushHostStateNow(audio, forceRest: true, forceWs: true);
      return;
    }
    while (_connectInFlight != null) {
      try {
        await _connectInFlight;
      } catch (_) {}
    }
    final connectCompleter = Completer<void>();
    _connectInFlight = connectCompleter.future;
    try {
      await _connectHostImpl(roomId: roomId, audio: audio);
    } finally {
      if (!connectCompleter.isCompleted) connectCompleter.complete();
      if (identical(_connectInFlight, connectCompleter.future)) {
        _connectInFlight = null;
      }
    }
  }

  Future<void> _connectHostImpl({
    required String roomId,
    required AudioPlayerService audio,
  }) async {
    await disconnect();
    if (!ListeningRoomSession.instance.active) {
      _log('host connect aborted: room session inactive room=$roomId');
      return;
    }
    final acc = await AuthSessionStore.readAccount();
    final token = acc?.sessionToken.trim() ?? '';
    if (token.isEmpty) throw StateError('Not logged in');
    _isHost = true;
    _roomId = roomId;
    _hostAudio = audio;
    final uri = Uri.parse(wsUrl(roomId, token));
    _channel = WebSocketChannel.connect(uri);
    _sub = _channel!.stream.listen(
      (raw) {
        if (raw is! String) return;
        _onHostStateMessage(raw);
      },
      onError: (Object e, StackTrace st) {
        _log('host ws error room=$roomId error=$e');
      },
      onDone: () {
        _log('host ws done room=$roomId');
      },
      cancelOnError: false,
    );
    try {
      await _channel!.ready.timeout(const Duration(seconds: 10));
      _log('host ws ready room=$roomId');
    } catch (e) {
      _log('host ws ready timeout room=$roomId error=$e');
    }

    _hostListener = null;

    // Позицию на сервер пушим только при явных действиях (pause/seek/skip),
    // не раз в секунду — иначе гости захлёбываются очередью apply.
    _hostSnapshotTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_refreshHostSessionSnapshot(roomId));
    });
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!_isHost || _roomId != roomId || !ListeningRoomSession.instance.active) {
      return;
    }
    _hostListenerMutedUntilMs =
        DateTime.now().millisecondsSinceEpoch + 800;
    _pushHostStateNow(audio, forceRest: true, forceWs: true);
    _log('host connect ready room=$roomId');
  }

  Future<void> _refreshHostSessionSnapshot(String roomId) async {
    if (!_isHost ||
        _roomId != roomId ||
        !ListeningRoomSession.instance.active) {
      return;
    }
    try {
      final state = await ColistenApi().getRoomState(roomId);
      if (!_isHost || _roomId != roomId) return;
      _applyRoomDtoToSession(state);
    } catch (_) {}
  }

  void _onHostStateMessage(String raw) {
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      if (j['type'] == 'remote_command') {
        _onHostRemoteCommand(j);
        return;
      }
      if (!_isRoomStatePayload(j)) return;
      _applySessionState(j);
      final ver = (j['stateVersion'] as num?)?.toInt() ?? 0;
      if (ver <= 0) return;
      if (ver <= _hostAppliedRoomVersion) return;
      final audio = _hostAudio;
      if (audio == null) return;
      final generation = _connectionGeneration;
      _hostOutboundBlockers++;
      _hostSuppressOutboundUntilMs =
          DateTime.now().millisecondsSinceEpoch + 1800;
      _hostWsApplyChain = _hostWsApplyChain.then((_) async {
        try {
          if (_connectionGeneration != generation || !_isHost) return;
          if (ver <= _hostAppliedRoomVersion) return;
          await _applyHostInboundRoomState(
            j,
            audio,
            applyGeneration: generation,
          );
          if (_connectionGeneration != generation || !_isHost) return;
          _hostAppliedRoomVersion = ver;
          // Give inbound authoritative state a brief head start so host ticker
          // cannot immediately overwrite a successfully applied guest command.
          _hostSuppressOutboundUntilMs =
              DateTime.now().millisecondsSinceEpoch + 1800;
        } catch (e) {
          _log('host ws apply error room=$_roomId v=$ver error=$e');
        } finally {
          if (_hostOutboundBlockers > 0) _hostOutboundBlockers--;
        }
      });
    } catch (_) {}
  }

  void _onHostRemoteCommand(Map<String, dynamic> j) {
    final audio = _hostAudio;
    final roomId = _roomId;
    if (!_isHost || audio == null || roomId == null || roomId.isEmpty) return;
    final generation = _connectionGeneration;
    _log(
      'host remote command room=$roomId sender=${j['senderUserId']} trackId=${j['trackId']} key=${j['trackKey']} pos=${j['positionSeconds'] ?? j['position']} playing=${j['playing']} shuffle=${j['shuffleEnabled']} repeat=${j['repeatMode']}',
    );
    final remoteSerial = ++_hostRemoteCommandSerial;
    final localActionSerialAtReceipt = _hostLocalActionSerial;
    _hostRemoteCommandChain = _hostRemoteCommandChain.then((_) async {
      if (!_isCurrentRemoteCommand(
        generation: generation,
        remoteSerial: remoteSerial,
        localActionSerialAtReceipt: localActionSerialAtReceipt,
      )) {
        _log('host remote command dropped stale-before-apply room=$roomId');
        return;
      }
      _hostOutboundBlockers++;
      _hostSuppressOutboundUntilMs =
          DateTime.now().millisecondsSinceEpoch + 2200;
      _setHostRemoteAuthoritativeOverride(j);
      try {
        if (_connectionGeneration != generation || !_isHost) return;
        await _applyRemoteCommandPayload(
          j,
          audio,
          generation: generation,
          remoteSerial: remoteSerial,
          localActionSerialAtReceipt: localActionSerialAtReceipt,
        );
        if (!_isCurrentRemoteCommand(
              generation: generation,
              remoteSerial: remoteSerial,
              localActionSerialAtReceipt: localActionSerialAtReceipt,
            ) ||
            _roomId != roomId) {
          _log('host remote command dropped stale-after-apply room=$roomId');
          return;
        }
        _hostSuppressOutboundUntilMs =
            DateTime.now().millisecondsSinceEpoch + 1800;
      } catch (e) {
        _log('host remote command error room=$roomId error=$e');
      } finally {
        if (_hostOutboundBlockers > 0) _hostOutboundBlockers--;
      }
      if (_isCurrentRemoteCommand(
            generation: generation,
            remoteSerial: remoteSerial,
            localActionSerialAtReceipt: localActionSerialAtReceipt,
          ) &&
          _roomId == roomId) {
        _pushHostStateNow(
          audio,
          forceRest: true,
          forceWs: true,
          hostPayloadOverride: _authoritativeRemoteAckPayload(j),
        );
      }
    });
  }

  Map<String, dynamic> _authoritativeRemoteAckPayload(
    Map<String, dynamic> command,
  ) {
    final ack = <String, dynamic>{};
    for (final key in <String>[
      'position',
      'positionSeconds',
      'playing',
      'shuffleEnabled',
      'repeatMode',
      'trackId',
      'trackKey',
      'queueTrackIds',
      'queueTrackKeys',
    ]) {
      if (command.containsKey(key) && command[key] != null) {
        ack[key] = command[key];
      }
    }
    return ack;
  }

  bool _isCurrentRemoteCommand({
    required int generation,
    required int remoteSerial,
    required int localActionSerialAtReceipt,
  }) {
    return _connectionGeneration == generation &&
        _isHost &&
        remoteSerial == _hostRemoteCommandSerial &&
        localActionSerialAtReceipt == _hostLocalActionSerial;
  }

  Future<void> _applyRemoteCommandPayload(
    Map<String, dynamic> j,
    AudioPlayerService audio, {
    required int generation,
    required int remoteSerial,
    required int localActionSerialAtReceipt,
  }) async {
    final payload = Map<String, dynamic>.from(_hostStatePayload(audio));
    for (final key in <String>[
      'trackId',
      'trackKey',
      'queueTrackIds',
      'queueTrackKeys',
      'position',
      'positionSeconds',
      'playing',
      'shuffleEnabled',
      'repeatMode',
    ]) {
      if (j.containsKey(key) && j[key] != null) {
        payload[key] = j[key];
      }
    }
    payload['type'] = 'state';
    final hasTrackCommand =
        j['trackId'] != null ||
        (j['trackKey'] is String && (j['trackKey'] as String).isNotEmpty);
    final hasQueueCommand =
        (j['queueTrackIds'] is List &&
            (j['queueTrackIds'] as List).isNotEmpty) ||
        (j['queueTrackKeys'] is List &&
            (j['queueTrackKeys'] as List).isNotEmpty);
    if (!hasTrackCommand && !hasQueueCommand) {
      await _applyLightweightRemoteCommand(
        j,
        audio,
        generation: generation,
        remoteSerial: remoteSerial,
        localActionSerialAtReceipt: localActionSerialAtReceipt,
      );
      return;
    }
    await _applyRoomPlaybackPayload(
      payload,
      audio,
      applyGeneration: generation,
      forceTrackReload: hasTrackCommand,
      forcePositionSync: j['position'] != null || j['positionSeconds'] != null,
      guestTimelineHints: false,
    );
  }

  Future<void> _applyLightweightRemoteCommand(
    Map<String, dynamic> j,
    AudioPlayerService audio, {
    required int generation,
    required int remoteSerial,
    required int localActionSerialAtReceipt,
  }) async {
    final pos = ((j['positionSeconds'] as num?) ?? (j['position'] as num?))
        ?.toDouble();
    final playing = j['playing'] as bool?;
    final shuffleEnabled = j['shuffleEnabled'] as bool?;
    final repeatMode = (j['repeatMode'] as String?)?.trim().toLowerCase();
    _log(
      'host remote lightweight room=$_roomId pos=${pos?.toStringAsFixed(3)} playing=$playing shuffle=$shuffleEnabled repeat=$repeatMode',
    );
    if (playing == false) {
      await audio.pauseFromRoomSync();
      if (!_isCurrentRemoteCommand(
        generation: generation,
        remoteSerial: remoteSerial,
        localActionSerialAtReceipt: localActionSerialAtReceipt,
      )) {
        return;
      }
    }
    if (pos != null) {
      await audio.seekFromRoomSync(
        Duration(milliseconds: (pos * 1000).round()),
      );
      if (!_isCurrentRemoteCommand(
        generation: generation,
        remoteSerial: remoteSerial,
        localActionSerialAtReceipt: localActionSerialAtReceipt,
      )) {
        return;
      }
    }
    if (shuffleEnabled != null || repeatMode != null) {
      await audio.applyRoomPlaybackModes(
        shuffleEnabled: shuffleEnabled,
        repeatMode: repeatMode,
      );
      if (!_isCurrentRemoteCommand(
        generation: generation,
        remoteSerial: remoteSerial,
        localActionSerialAtReceipt: localActionSerialAtReceipt,
      )) {
        return;
      }
    }
    if (playing == true) {
      await audio.playFromRoomSync();
    }
  }

  Future<void> _handleKickedFromRoom(AudioPlayerService audio) async {
    _log('guest kicked room=$_roomId');
    try {
      await audio.stop();
    } catch (_) {}
    ListeningRoomSession.instance.end();
  }

  void _sink(String msg) {
    try {
      _channel?.sink.add(msg);
    } catch (e) {
      _log('ws sink error room=$_roomId error=$e');
    }
  }

  Future<void> _handleGuestMessage(
    String raw,
    AudioPlayerService audio,
    int generation,
  ) async {
    if (_connectionGeneration != generation ||
        _isHost ||
        _roomId == null ||
        !ListeningRoomSession.instance.active) {
      return;
    }
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      if (j['type'] == 'kicked') {
        await _handleKickedFromRoom(audio);
        return;
      }
      if (!_isRoomStatePayload(j)) {
        final msgType = (j['type'] as String?)?.trim() ?? '';
        _log('guest ws ignore type=$msgType room=$_roomId');
        return;
      }
      final ver = _stateVersionFromJson(j);
      if (_guestIncomingStateIsObsolete(j)) {
        _log(
          'guest ws skip obsolete v=$ver applied=$_guestAppliedVersion cs=${_guestControlSeqFrom(j)} lastCs=$_guestLastControlSeq',
        );
        return;
      }
      if (ver > 0 && ver < _guestLastSeenVersion) {
        _log('guest ws skip stale v=$ver seen=$_guestLastSeenVersion');
        return;
      }
      final playing = j['playing'] as bool? ?? false;
      final playingChanged = _guestServerPlayingChanged(playing);
      final enginePlayingDrift = _guestOutOfSyncWithServer(playing, audio);
      final needsTrackReload = _guestNeedsTrackReload(j, audio);
      final queueMismatch = _guestNeedsQueueSync(j, audio);
      final controlAdvanced = _guestControlSeqAdvanced(j);
      final pos = _guestSyncPositionSeconds(j);
      final posDiffMs =
          ((pos * 1000).round() - audio.position.inMilliseconds).abs();
      final positionMeaningful = posDiffMs >= 180;
      _log(
        'guest ws state room=$_roomId v=$ver cs=${_guestControlSeqFrom(j)} trackId=${j['trackId']} key=${j['trackKey']} pos=${pos.toStringAsFixed(3)} playing=$playing reload=$needsTrackReload queue=$queueMismatch ctrl=$controlAdvanced',
      );
      if (ver > _guestLastSeenVersion) _guestLastSeenVersion = ver;
      final needsApply = ver > _guestAppliedVersion ||
          controlAdvanced ||
          playingChanged ||
          enginePlayingDrift ||
          needsTrackReload ||
          queueMismatch ||
          positionMeaningful;
      if (!needsApply) {
        if (ver > _guestLastSeenVersion) _guestLastSeenVersion = ver;
        _log(
          'guest ws skip noop room=$_roomId v=$ver applied=$_guestAppliedVersion cs=${_guestControlSeqFrom(j)}',
        );
        return;
      }
      final transportOnly = audio.currentTrack != null &&
          !needsTrackReload &&
          !queueMismatch &&
          _guestNeedsTransportSync(j, audio);
      final metadataOnly = audio.currentTrack != null &&
          !needsTrackReload &&
          !queueMismatch &&
          _guestLightweightStateChanged(j) &&
          !_guestNeedsTransportSync(j, audio);
      if (transportOnly) {
        _enqueueGuestTransportApply(
          generation,
          j,
          ver,
          audio,
          debugLabel: 'ws-transport',
        );
        if (ver > _guestLastSeenVersion) _guestLastSeenVersion = ver;
        _completeGuestFirstRealtimeIfNeeded();
        return;
      }
      if (metadataOnly) {
        _enqueueGuestApply(
          generation,
          () => _applyGuestMetadataOnly(j, audio, generation, ver),
          debugLabel: 'ws-metadata',
        );
        if (ver > _guestLastSeenVersion) _guestLastSeenVersion = ver;
        _completeGuestFirstRealtimeIfNeeded();
        return;
      }
      _coalesceGuestRoomState(j, audio, generation);
      if (ver > _guestLastSeenVersion) _guestLastSeenVersion = ver;
      _completeGuestFirstRealtimeIfNeeded();
    } catch (e) {
      _log('guest ws parse error room=$_roomId error=$e');
    }
  }

  Future<void> _applyGuestStateFromWire(
    Map<String, dynamic> j,
    AudioPlayerService audio, {
    required int generation,
  }) async {
    final ver = _stateVersionFromJson(j);
    final playing = j['playing'] as bool? ?? false;
    final playingChanged = _guestServerPlayingChanged(playing);
    final enginePlayingDrift = _guestOutOfSyncWithServer(playing, audio);
    final needsTrackReload = _guestNeedsTrackReload(j, audio);
    final queueMismatch = _guestNeedsQueueSync(j, audio);
    final controlAdvanced = _guestControlSeqAdvanced(j);
    final pos = _guestSyncPositionSeconds(j);
    final posDiffMs =
        ((pos * 1000).round() - audio.position.inMilliseconds).abs();
    final positionMeaningful = posDiffMs >= 180;
    final transportOnly = audio.currentTrack != null &&
        !needsTrackReload &&
        !queueMismatch &&
        (controlAdvanced || playingChanged || enginePlayingDrift);
    if (transportOnly) {
      _enqueueGuestTransportApply(
        generation,
        j,
        ver,
        audio,
        debugLabel: 'wire-transport',
      );
      return;
    }
    _guestApplyDebounceTimer?.cancel();
    _guestPendingApplyState = null;
    await _applyGuestState(
      j,
      audio,
      generation: generation,
      forcePositionSync:
          positionMeaningful ||
          _guestNeedsInitialHardSync ||
          controlAdvanced ||
          playingChanged ||
          enginePlayingDrift ||
          queueMismatch,
      forceTrackReload: needsTrackReload || queueMismatch,
    );
    if (_connectionGeneration != generation) return;
    if (ver > _guestLastSeenVersion) _guestLastSeenVersion = ver;
    _markGuestWsApplied(ver);
  }

  Future<void> _applyGuestTransportFromWs(
    Map<String, dynamic> j,
    AudioPlayerService audio,
    int generation,
    int ver,
  ) async {
    if (_connectionGeneration != generation) return;
    if (_guestIncomingStateIsObsolete(j)) {
      _log(
        'guest transport skip obsolete v=$ver applied=$_guestAppliedVersion cs=${_guestControlSeqFrom(j)} lastCs=$_guestLastControlSeq',
      );
      return;
    }
    if (_guestTransportSuperseded(ver, generation)) {
      _log(
        'guest transport skip superseded v=$ver pending=$_guestPendingTransportVer seen=$_guestLastSeenVersion',
      );
      return;
    }
    _applySessionState(j);
    final playing = j['playing'] as bool? ?? false;
    final pos = _guestSyncPositionSeconds(j);
    final hasLoadedTrack = audio.currentTrack != null;
    if (!hasLoadedTrack) {
      _log('guest ws transport defer until track loaded v=$ver');
      _scheduleGuestStateApply(j, audio, generation: generation);
      return;
    }
    final lastTransportPos = _guestLastTransportPositionSeconds;
    final serverPositionChanged = lastTransportPos == null ||
        (lastTransportPos - pos).abs() >= 0.2;
    final targetMs = (pos * 1000).round();
    final target = Duration(milliseconds: targetMs);
    final diffMs = (targetMs - audio.position.inMilliseconds).abs();
    final seekThresholdMs = playing ? 280 : 180;
    final needsSeek = serverPositionChanged || diffMs >= seekThresholdMs;
    final playPauseNeeded = _guestOutOfSyncWithServer(playing, audio);
    // Пауза до seek на Android; seek не ждём play/pause-очередь (иначе seek «замораживается»).
    if (!playing && playPauseNeeded) {
      await _guestTransportEngineOp(() async {
        await audio.pauseFromRoomSync();
        _guestHostPausedAtMs = DateTime.now().millisecondsSinceEpoch;
      }, label: 'pause');
    }
    if (_connectionGeneration != generation ||
        _guestTransportSuperseded(ver, generation)) {
      return;
    }
    if (needsSeek) {
      await _guestTransportEngineOp(
        () => audio.seekFromRoomSync(target),
        label: 'seek',
      );
    }
    if (_connectionGeneration != generation ||
        _guestTransportSuperseded(ver, generation)) {
      return;
    }
    if (playing && playPauseNeeded) {
      await _guestTransportEngineOp(
        () => _guestApplyPlayPauseIntent(
          audio,
          playing: true,
          target: target,
        ),
        label: 'play',
      );
    } else if (playing && !_guestEngineMatchesServer(true, audio)) {
      await _guestTransportEngineOp(
        () => _guestApplyPlayPauseIntent(
          audio,
          playing: true,
          target: target,
        ),
        label: 'play-resync',
      );
    }
    if (_connectionGeneration != generation ||
        _guestTransportSuperseded(ver, generation)) {
      return;
    }
    final controlSeq = _guestControlSeqFrom(j);
    if (controlSeq > _guestLastControlSeq) {
      _guestLastControlSeq = controlSeq;
    }
    _commitGuestTransportApply(j, ver);
    _markGuestWsApplied(ver);
    _log(
      'guest transport apply v=$ver cs=$controlSeq playing=$playing pos=${pos.toStringAsFixed(3)} diffMs=$diffMs',
    );
  }

  void _completeGuestFirstRealtimeIfNeeded() {
    _guestNeedsFirstRealtimeHardSync = false;
    final firstRealtime = _guestFirstRealtimeStateCompleter;
    if (firstRealtime != null && !firstRealtime.isCompleted) {
      firstRealtime.complete();
    }
  }

  String? _guestIncomingTrackKey(Map<String, dynamic> j) {
    final trackKey = (j['trackKey'] as String?)?.trim();
    if (trackKey != null && trackKey.isNotEmpty) return trackKey;
    final tid = (j['trackId'] as num?)?.toInt();
    if (tid != null && tid > 0) return 'srv:$tid';
    return null;
  }

  bool _guestNeedsTrackReload(
    Map<String, dynamic> j,
    AudioPlayerService audio,
  ) {
    final incomingTrackKey = _guestIncomingTrackKey(j);
    if (incomingTrackKey == null) return false;
    final currentTrackKey = TracksApi().trackKeyForPaths(
      assetPath: audio.currentTrack?.assetPath ?? '',
      audioFilePath: audio.currentTrack?.audioFilePath,
    );
    return incomingTrackKey != currentTrackKey;
  }

  bool _guestNeedsQueueSync(
    Map<String, dynamic> j,
    AudioPlayerService audio,
  ) {
    final queueKeys = ((j['queueTrackKeys'] as List?) ?? const [])
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (queueKeys.isEmpty) return false;
    final currentQueueKeys = audio.activeQueue
        .map(
          (t) => TracksApi().trackKeyForPaths(
            assetPath: t.assetPath,
            audioFilePath: t.audioFilePath,
          ),
        )
        .toList();
    return !_sameStringList(currentQueueKeys, queueKeys);
  }

  bool _guestNeedsFullStateApply(
    Map<String, dynamic> j,
    AudioPlayerService audio,
  ) =>
      _guestNeedsTrackReload(j, audio) || _guestNeedsQueueSync(j, audio);

  void _scheduleGuestStateApply(
    Map<String, dynamic> j,
    AudioPlayerService audio, {
    required int generation,
  }) {
    _guestPendingApplyState = j;
    _guestPendingApplyGeneration = generation;
    _guestApplyDebounceTimer?.cancel();
    final delayMs = _guestControlSeqFrom(j) > _guestLastControlSeq ? 0 : 60;
    _guestApplyDebounceTimer = Timer(Duration(milliseconds: delayMs), () {
      unawaited(_flushGuestPendingApply(audio));
    });
  }

  Future<void> _flushGuestPendingApply(AudioPlayerService audio) async {
    final j = _guestPendingApplyState;
    final generation = _guestPendingApplyGeneration;
    if (j == null ||
        _connectionGeneration != generation ||
        !ListeningRoomSession.instance.active) {
      return;
    }
    _guestPendingApplyState = null;
    final ver = (j['stateVersion'] as num?)?.toInt() ?? 0;
    final needsTrackReload = _guestNeedsTrackReload(j, audio);
    if (ver <= _guestAppliedVersion && !needsTrackReload) return;
    final pos = _guestSyncPositionSeconds(j);
    final diffMs =
        ((pos * 1000).round() - audio.position.inMilliseconds).abs();
    final playing = j['playing'] as bool? ?? false;
    final playingChanged = _guestServerPlayingChanged(playing);
    await _applyGuestState(
      j,
      audio,
      generation: generation,
      forcePositionSync:
          _guestNeedsInitialHardSync ||
          diffMs >= 900 ||
          playingChanged,
      forceTrackReload: needsTrackReload,
    );
    if (_connectionGeneration != generation) return;
    _completeGuestFirstRealtimeIfNeeded();
  }

  void _commitGuestTransportApply(Map<String, dynamic> j, int version) {
    final playing = j['playing'] as bool? ?? false;
    final pos = _guestSyncPositionSeconds(j);
    _guestTargetPositionSeconds = pos;
    _guestTargetPlaying = playing;
    _guestTargetAnchorLocalMs =
        (j['wallClockMs'] as num?)?.toInt() ??
        DateTime.now().millisecondsSinceEpoch;
    _applySessionState(j);
    if (version > _guestAppliedVersion) {
      _guestAppliedVersion = version;
    }
    _guestLastAppliedPlaybackSig = _roomPlaybackSignature(j);
    _guestLastTransportPositionSeconds = pos;
    _guestLastKnownPlaying = playing;
    final shuffle = j['shuffleEnabled'] as bool?;
    final repeat = (j['repeatMode'] as String?)?.trim().toLowerCase();
    if (shuffle != null) {
      _guestLastKnownShuffleEnabled = shuffle;
    }
    if (repeat != null && repeat.isNotEmpty) {
      _guestLastKnownRepeatMode = repeat;
    }
    _guestNeedsInitialHardSync = false;
  }

  Future<void> _guestPollRoomState(
    String roomId,
    AudioPlayerService audio,
    int generation, {
    bool forceApply = false,
  }) async {
    if (!_guestBootstrapComplete ||
        _connectionGeneration != generation ||
        _isHost ||
        _roomId != roomId ||
        !ListeningRoomSession.instance.active) {
      return;
    }
    final bootstrapInFlight = _guestBootstrapApplyInFlight;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final localEngineDrift = _guestEngineDrifted(audio);
    if (!forceApply &&
        !localEngineDrift &&
        _guestLastWsStateAtMs > 0 &&
        nowMs - _guestLastWsStateAtMs < _guestPollWsSilenceMs) {
      return;
    }
    try {
      final state = await ColistenApi()
          .getRoomState(roomId)
          .timeout(const Duration(seconds: 2));
      if (_connectionGeneration != generation) return;
      final map = _roomStateMapFromDto(state);
      if (_guestIncomingStateIsObsolete(map)) {
        _log(
          'guest poll skip obsolete room=$roomId v=${state.stateVersion} applied=$_guestAppliedVersion cs=${state.controlSeq} lastCs=$_guestLastControlSeq',
        );
        return;
      }
      final controlAdvanced = state.controlSeq > _guestLastControlSeq;
      final engineDrift = _guestOutOfSyncWithServer(state.playing, audio);
      final playingChanged = _guestServerPlayingChanged(state.playing);
      final trackReload = _guestNeedsTrackReload(map, audio);
      final queueMismatch = _guestNeedsQueueSync(map, audio);
      // Use interpolated position so that normal playback progress doesn't
      // look like drift. Raw positionSeconds stays frozen while audio advances,
      // causing spurious full-applies and seek loops.
      final interpolatedPollPos = _guestSyncPositionSeconds(map);
      final posDiffMs =
          ((interpolatedPollPos * 1000).round() -
                  audio.position.inMilliseconds)
              .abs();
      final needsApply = forceApply ||
          state.stateVersion > _guestAppliedVersion ||
          controlAdvanced ||
          engineDrift ||
          playingChanged ||
          trackReload ||
          queueMismatch;
      if (!needsApply) return;
      _log(
        'guest poll apply room=$roomId v=${state.stateVersion} pos=${state.positionSeconds.toStringAsFixed(3)} playing=${state.playing} force=$forceApply drift=$engineDrift wsAgoMs=${_guestLastWsStateAtMs == 0 ? -1 : nowMs - _guestLastWsStateAtMs}',
      );
      final transportOnly = audio.currentTrack != null &&
          !trackReload &&
          !queueMismatch &&
          (controlAdvanced || engineDrift || playingChanged) &&
          _guestNeedsTransportSync(map, audio);
      final metadataOnly = audio.currentTrack != null &&
          !trackReload &&
          !queueMismatch &&
          _guestLightweightStateChanged(map) &&
          !_guestNeedsTransportSync(map, audio);
      if (transportOnly) {
        _enqueueGuestTransportApply(
          generation,
          map,
          state.stateVersion,
          audio,
          debugLabel: 'poll-transport',
        );
        return;
      } else if (metadataOnly) {
        await _applyGuestMetadataOnly(
          map,
          audio,
          generation,
          state.stateVersion,
        );
        return;
      } else if (bootstrapInFlight) {
        final incomingVer = state.stateVersion;
        final deferredVer = _guestDeferredRoomState == null
            ? -1
            : _stateVersionFromJson(_guestDeferredRoomState!);
        if (incomingVer >= deferredVer) {
          _guestDeferredRoomState = map;
        }
        _log(
          'guest poll defer full apply during bootstrap room=$roomId v=${state.stateVersion}',
        );
      } else if (state.stateVersion > _guestAppliedVersion &&
          _guestNeedsTransportSync(map, audio)) {
        _enqueueGuestTransportApply(
          generation,
          map,
          state.stateVersion,
          audio,
          debugLabel: 'poll-transport-catchup',
        );
      } else if (!engineDrift &&
          !playingChanged &&
          !trackReload &&
          !queueMismatch &&
          posDiffMs < 900 &&
          state.stateVersion > _guestAppliedVersion &&
          _guestEngineMatchesServer(state.playing, audio)) {
        if (state.stateVersion > _guestLastSeenVersion) {
          _guestLastSeenVersion = state.stateVersion;
        }
        _guestAppliedVersion = state.stateVersion;
        _markGuestWsApplied(state.stateVersion);
        _log(
          'guest poll skip version-only room=$roomId v=${state.stateVersion} applied=$_guestAppliedVersion',
        );
      } else {
        await _applyGuestState(
          map,
          audio,
          generation: generation,
          forcePositionSync:
              forceApply ||
              controlAdvanced ||
              engineDrift ||
              playingChanged ||
              trackReload ||
              posDiffMs >= 900,
          forceTrackReload: trackReload || queueMismatch,
        );
      }
      if (_connectionGeneration != generation) return;
      _markGuestWsApplied(state.stateVersion);
    } catch (e) {
      _log('guest poll error room=$roomId error=$e');
    }
  }

  /// Хост не подстраивает play/pause/seek под WS `state` (эхо своих же апдейтов).
  /// С сервера подтягиваем только очередь, если гость её изменил.
  Future<void> _applyHostInboundRoomState(
    Map<String, dynamic> j,
    AudioPlayerService audio, {
    required int applyGeneration,
  }) async {
    if (_connectionGeneration != applyGeneration || !_isHost) return;
    final queueKeys = ((j['queueTrackKeys'] as List?) ?? const [])
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final queueIds = ((j['queueTrackIds'] as List?) ?? const [])
        .map((e) => (e as num?)?.toInt())
        .whereType<int>()
        .where((e) => e > 0)
        .toList();
    final effectiveQueueKeys = queueKeys.isNotEmpty
        ? queueKeys
        : queueIds.map((id) => 'srv:$id').toList();
    if (effectiveQueueKeys.isEmpty) return;
    final currentQueueKeys = audio.activeQueue
        .map(
          (t) => TracksApi().trackKeyForPaths(
            assetPath: t.assetPath,
            audioFilePath: t.audioFilePath,
          ),
        )
        .toList();
    if (_sameStringList(currentQueueKeys, effectiveQueueKeys)) return;
    // While the host's own REST push is in flight, ignore queue updates that
    // would downgrade the local queue. The WS may deliver a stale server state
    // (before the push was processed), and accepting it would overwrite the
    // host's locally-authoritative queue with an older, shorter one.
    if (_hostRestSyncInFlight &&
        effectiveQueueKeys.length < currentQueueKeys.length) {
      _log(
        'host inbound skip queue regress (rest in flight) server=${effectiveQueueKeys.length} local=${currentQueueKeys.length}',
      );
      return;
    }
    final roomQueue = await _buildQueueFromTrackKeys(effectiveQueueKeys);
    if (roomQueue.isEmpty) return;
    _log(
      'host inbound queue-only room=$_roomId keys=${effectiveQueueKeys.length}',
    );
    ListeningRoomSession.instance.replaceQueue(roomQueue);
    await audio.syncQueuePreservingPlayback(roomQueue);
  }

  Future<void> _applyRoomPlaybackPayload(
    Map<String, dynamic> j,
    AudioPlayerService audio, {
    required int applyGeneration,
    bool forceTrackReload = false,
    bool forcePositionSync = false,
    required bool guestTimelineHints,
  }) async {
    if (_connectionGeneration != applyGeneration) return;
    if (!ListeningRoomSession.instance.active) return;

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
    final playing = j['playing'] as bool? ?? false;
    final pos = _guestSyncPositionSeconds(j);
    final shuffleEnabled = j['shuffleEnabled'] as bool?;
    final repeatMode = (j['repeatMode'] as String?)?.trim().toLowerCase();
    final roleTag = guestTimelineHints ? 'guest' : 'host';
    _log(
      '$roleTag playback room=$_roomId trackId=$tid key=$trackKey pos=${pos.toStringAsFixed(3)} playing=$playing forceReload=$forceTrackReload',
    );
    final wallClockMs = (j['wallClockMs'] as num?)?.toInt() ?? 0;
    final anchorLocalMs = wallClockMs > 0
        ? wallClockMs
        : DateTime.now().millisecondsSinceEpoch;
    if (guestTimelineHints) {
      _guestTargetPositionSeconds = pos;
      _guestTargetPlaying = playing;
      _guestTargetAnchorLocalMs = anchorLocalMs;
    }
    final effectiveQueueKeys = queueKeys.isNotEmpty
        ? queueKeys
        : queueIds.map((id) => 'srv:$id').toList();
    final effectiveTrackKey = () {
      if (trackKey != null && trackKey.isNotEmpty) return trackKey;
      if (tid != null) return 'srv:$tid';
      return null;
    }();
    final currentTrackKey = TracksApi().trackKeyForPaths(
      assetPath: audio.currentTrack?.assetPath ?? '',
      audioFilePath: audio.currentTrack?.audioFilePath,
    );
    final currentQueueKeys = audio.activeQueue
        .map(
          (t) => TracksApi().trackKeyForPaths(
            assetPath: t.assetPath,
            audioFilePath: t.audioFilePath,
          ),
        )
        .toList();
    final queueMismatch =
        effectiveQueueKeys.isNotEmpty &&
        !_sameStringList(currentQueueKeys, effectiveQueueKeys);
    final trackKeyMatches =
        effectiveTrackKey != null && effectiveTrackKey == currentTrackKey;
    if (trackKeyMatches && !queueMismatch && !forceTrackReload) {
      final metadataOnly = !forcePositionSync &&
          _guestLightweightStateChanged(j) &&
          !_guestTransportFieldsChanged(j, audio);
      if (metadataOnly) {
        await audio.applyRoomPlaybackModes(
          shuffleEnabled: shuffleEnabled,
          repeatMode: repeatMode,
        );
        if (shuffleEnabled != null) {
          _guestLastKnownShuffleEnabled = shuffleEnabled;
        }
        if (repeatMode != null && repeatMode.isNotEmpty) {
          _guestLastKnownRepeatMode = repeatMode;
        }
        if (_connectionGeneration != applyGeneration) return;
        _log('$roleTag metadata-only apply room=$_roomId');
        return;
      }
      await audio.applyRoomPlaybackModes(
        shuffleEnabled: shuffleEnabled,
        repeatMode: repeatMode,
      );
      final targetMs = (pos * 1000).round();
      final transportDiffMs =
          (targetMs - audio.position.inMilliseconds).abs();
      final needsSeek =
          forcePositionSync ||
          transportDiffMs >= 700 ||
          (guestTimelineHints && _guestNeedsInitialHardSync);
      // Пауза до seek: иначе seek в той же позиции на части Android снова запускает play.
      if (!playing) {
        await _applyGuestServerPlaying(audio, serverPlaying: false);
        if (_connectionGeneration != applyGeneration) return;
        if (needsSeek && transportDiffMs >= 180) {
          await audio.seekFromRoomSync(Duration(milliseconds: targetMs));
        }
      } else {
        if (needsSeek) {
          await audio.seekFromRoomSync(Duration(milliseconds: targetMs));
          if (guestTimelineHints) {
            _guestNeedsInitialHardSync = false;
          }
        }
        await _applyGuestServerPlaying(audio, serverPlaying: true);
        if (guestTimelineHints && !needsSeek && transportDiffMs < 1500) {
          _guestTargetPositionSeconds = pos;
          _guestTargetPlaying = true;
          _guestTargetAnchorLocalMs = anchorLocalMs;
        }
      }
      if (_connectionGeneration != applyGeneration) return;
      _log('$roleTag transport-only apply room=$_roomId playing=$playing');
      return;
    }
    List<Track> roomQueue = const [];
    if (effectiveQueueKeys.isNotEmpty) {
      roomQueue = await _buildQueueFromTrackKeys(effectiveQueueKeys);
      if (roomQueue.isNotEmpty) {
        ListeningRoomSession.instance.replaceQueue(roomQueue);
      }
    }
    if (trackKeyMatches &&
        queueMismatch &&
        !forceTrackReload &&
        !forcePositionSync &&
        roomQueue.isNotEmpty) {
      final queueOnlyDiffMs =
          ((pos * 1000).round() - audio.position.inMilliseconds).abs();
      await audio.syncQueuePreservingPlayback(roomQueue);
      if (_connectionGeneration != applyGeneration) return;
      if (queueOnlyDiffMs < 900) {
        _log('$roleTag queue-only apply room=$_roomId keys=${effectiveQueueKeys.length}');
        return;
      }
      _log(
        '$roleTag queue-only + seek room=$_roomId keys=${effectiveQueueKeys.length} diffMs=$queueOnlyDiffMs',
      );
    }
    var trackWasReloaded = false;
    if (effectiveTrackKey != null) {
      final tr = await _trackFromTrackKey(effectiveTrackKey);
      if (_connectionGeneration != applyGeneration) return;
      final roomQueueKeys = effectiveQueueKeys;
      final needTrackReload =
          forceTrackReload ||
          TracksApi().trackKeyForPaths(
                assetPath: audio.currentTrack?.assetPath ?? '',
                audioFilePath: audio.currentTrack?.audioFilePath,
              ) !=
              effectiveTrackKey ||
          queueMismatch;
      _log(
        '$roleTag track decision key=$effectiveTrackKey reload=$needTrackReload queueMismatch=$queueMismatch currentKey=${TracksApi().trackKeyForPaths(assetPath: audio.currentTrack?.assetPath ?? '', audioFilePath: audio.currentTrack?.audioFilePath)}',
      );
      if (needTrackReload) {
        final queue = roomQueueKeys.isEmpty ? [tr] : roomQueue;
        await audio.playTrack(
          tr,
          queue: queue.isEmpty ? [tr] : queue,
          leaveListeningRoomSession: false,
          autoPlay: false,
        );
        if (_connectionGeneration != applyGeneration) return;
        trackWasReloaded = true;
      } else if (queueMismatch && roomQueue.isNotEmpty) {
        await audio.syncQueuePreservingPlayback(roomQueue);
      }
    }
    final seekPos = Duration(milliseconds: (pos * 1000).round());
    final currentMs = audio.position.inMilliseconds;
    final targetMs = seekPos.inMilliseconds;
    final signedDiffMs = targetMs - currentMs;
    final hardSyncNow = guestTimelineHints && _guestNeedsInitialHardSync;
    final needForwardHardSeek = signedDiffMs >= 900;
    final needBackwardHardSeek = signedDiffMs <= -1800;
    final shouldSeek = playing
        ? forcePositionSync ||
              hardSyncNow ||
              trackWasReloaded ||
              needForwardHardSeek ||
              needBackwardHardSeek
        : forcePositionSync || hardSyncNow || trackWasReloaded;
    _log(
      '$roleTag seek decision targetMs=$targetMs currentMs=$currentMs signedDiffMs=$signedDiffMs shouldSeek=$shouldSeek reloaded=$trackWasReloaded',
    );
    if (shouldSeek) {
      await _seekGuestToTarget(
        audio: audio,
        target: seekPos,
        trackWasReloaded: trackWasReloaded,
        generation: applyGeneration,
        playing: playing,
      );
      if (_connectionGeneration != applyGeneration) return;
      if (guestTimelineHints) {
        _guestNeedsInitialHardSync = false;
      }
    }
    await audio.applyRoomPlaybackModes(
      shuffleEnabled: shuffleEnabled,
      repeatMode: repeatMode,
    );
    // Если транспортная цепочка применила более новую версию пока мы загружали трек,
    // используем уже известное состояние воспроизведения, а не из устаревшего payload.
    final payloadVersion = (j['stateVersion'] as num?)?.toInt() ?? 0;
    final effectivePlaying = (guestTimelineHints &&
            payloadVersion > 0 &&
            payloadVersion < _guestAppliedVersion)
        ? (_guestLastKnownPlaying ?? playing)
        : playing;
    await _applyGuestServerPlaying(audio, serverPlaying: effectivePlaying);
    final needsPostSettleSeek =
        guestTimelineHints &&
        effectivePlaying &&
        (forcePositionSync || hardSyncNow || trackWasReloaded);
    if (needsPostSettleSeek) {
      await _postSettleGuestSeek(
        audio: audio,
        target: seekPos,
        generation: applyGeneration,
      );
    }
  }

  Future<void> _applyGuestState(
    Map<String, dynamic> j,
    AudioPlayerService audio, {
    int? generation,
    bool forceTrackReload = false,
    bool forcePositionSync = false,
  }) async {
    final applyGeneration = generation ?? _connectionGeneration;
    if (_connectionGeneration != applyGeneration) return;
    if (!ListeningRoomSession.instance.active) return;
    if (_guestIncomingStateIsObsolete(j)) {
      _applySessionState(j);
      return;
    }
    final version = _stateVersionFromJson(j);
    final incomingTrackKey = () {
      final key = (j['trackKey'] as String?)?.trim();
      if (key != null && key.isNotEmpty) return key;
      final tid = (j['trackId'] as num?)?.toInt();
      if (tid != null && tid > 0) return 'srv:$tid';
      return null;
    }();
    final currentTrackKey = TracksApi().trackKeyForPaths(
      assetPath: audio.currentTrack?.assetPath ?? '',
      audioFilePath: audio.currentTrack?.audioFilePath,
    );
    final trackChanged = incomingTrackKey != null &&
        incomingTrackKey != currentTrackKey;
    final playing = j['playing'] as bool? ?? false;
    final playingChanged = _guestServerPlayingChanged(playing);
    final enginePlayingDrift = _guestOutOfSyncWithServer(playing, audio);
    final controlAdvanced = _guestControlSeqAdvanced(j);
    // Если транспортная цепочка уже применила более свежую версию —
    // возвращаемся сразу, кроме случаев когда нужно перезагрузить трек.
    if (version > 0 && version < _guestAppliedVersion && !forceTrackReload && !forcePositionSync) {
      _log(
        'guest apply skip stale v=$version applied=$_guestAppliedVersion forceTrack=$forceTrackReload',
      );
      return;
    }
    if (version > 0 &&
        version <= _guestAppliedVersion &&
        !forceTrackReload &&
        !forcePositionSync &&
        !trackChanged &&
        !playingChanged &&
        !enginePlayingDrift &&
        !controlAdvanced &&
        !_guestLightweightStateChanged(j)) {
      return;
    }
    final playbackSig = _roomPlaybackSignature(j);
    if (!controlAdvanced &&
        !forceTrackReload &&
        !forcePositionSync &&
        !trackChanged &&
        !playingChanged &&
        !enginePlayingDrift &&
        !_guestLightweightStateChanged(j) &&
        version <= _guestAppliedVersion &&
        playbackSig == _guestLastAppliedPlaybackSig) {
      _applySessionState(j);
      return;
    }
    if (audio.currentTrack != null &&
        !forceTrackReload &&
        !forcePositionSync &&
        !trackChanged &&
        !playingChanged &&
        !enginePlayingDrift &&
        _guestLightweightStateChanged(j) &&
        !_guestTransportFieldsChanged(j, audio)) {
      await _applyGuestMetadataOnly(j, audio, applyGeneration, version);
      return;
    }
    var applyForcePositionSync = forcePositionSync;
    var applyForceTrackReload = forceTrackReload || (controlAdvanced && trackChanged);
    _applySessionState(j);
    // Как только получили и применили состояние комнаты, убираем "Connecting...":
    // дальнейшие доп.снапшоты могут идти в фоне, но пользователь уже синхронизируется.
    ListeningRoomSession.instance.setJoining(false);
    await _applyRoomPlaybackPayload(
      j,
      audio,
      applyGeneration: applyGeneration,
      forceTrackReload: applyForceTrackReload,
      forcePositionSync: applyForcePositionSync,
      guestTimelineHints: true,
    );
    if (_connectionGeneration != applyGeneration) return;
    if (version > _guestAppliedVersion &&
        (forceTrackReload ||
            forcePositionSync ||
            trackChanged ||
            playingChanged ||
            enginePlayingDrift ||
            _guestEngineMatchesServer(playing, audio))) {
      _guestAppliedVersion = version;
      _markGuestWsApplied(version);
    }
    if (version > _guestLastSeenVersion) {
      _guestLastSeenVersion = version;
    }
    final controlSeq = _guestControlSeqFrom(j);
    if (controlSeq > _guestLastControlSeq) {
      _guestLastControlSeq = controlSeq;
    }
    _guestLastAppliedPlaybackSig = playbackSig;
    if (_guestEngineMatchesServer(playing, audio)) {
      _guestLastKnownPlaying = playing;
    }
    final pendingPlaying = _guestPendingPlayPausePlaying;
    if (pendingPlaying != null && j['playing'] == pendingPlaying) {
      _guestPendingPlayPausePlaying = null;
      _guestPendingPlayPauseUntilMs = 0;
    }
  }

  Future<void> _seekGuestToTarget({
    required AudioPlayerService audio,
    required Duration target,
    required bool trackWasReloaded,
    required int generation,
    required bool playing,
  }) async {
    if (trackWasReloaded) {
      // После замены источника некоторые устройства принимают seek только со второй попытки.
      await Future<void>.delayed(const Duration(milliseconds: 220));
      if (_connectionGeneration != generation) return;
    }
    await audio.seekFromRoomSync(target);
    final targetMs = target.inMilliseconds;
    if (!playing || targetMs < 1200) return;
    final attempts = trackWasReloaded ? 4 : 2;
    for (var i = 0; i < attempts; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (_connectionGeneration != generation) return;
      final actualMs = audio.position.inMilliseconds;
      final diffMs = (targetMs - actualMs).abs();
      if (diffMs <= 350) return;
      await audio.seekFromRoomSync(target);
    }
  }

  Future<void> _postSettleGuestSeek({
    required AudioPlayerService audio,
    required Duration target,
    required int generation,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (_connectionGeneration != generation) return;
    if (!_guestTargetPlaying) return;
    final targetMs = target.inMilliseconds;
    final actualMs = audio.position.inMilliseconds;
    final diffMs = (targetMs - actualMs).abs();
    if (diffMs <= 260) return;
    _log(
      'guest post-settle seek targetMs=$targetMs actualMs=$actualMs diffMs=$diffMs',
    );
    await audio.seekFromRoomSync(target);
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
    _localTrackCacheByAssetPath = {for (final t in list) t.assetPath: t};
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

  /// Позиция для гостя: без агрессивной экстраполяции вперёд (иначе +1–2с к хосту).
  double _guestSyncPositionSeconds(Map<String, dynamic> j) {
    final pos =
        ((j['positionSeconds'] as num?) ?? (j['position'] as num?))
            ?.toDouble() ??
        0;
    final playing = j['playing'] as bool? ?? false;
    if (!playing) return pos;
    final wallClock = (j['wallClockMs'] as num?)?.toInt() ?? 0;
    if (wallClock <= 0) return pos;
    final elapsedMs = DateTime.now().millisecondsSinceEpoch - wallClock;
    final leadMs = (elapsedMs - _guestNetworkLatencyMs).clamp(0, _guestMaxLeadMs);
    return pos + (leadMs / 1000.0);
  }

  String _roomPlaybackSignature(Map<String, dynamic> j) {
    final version = (j['stateVersion'] as num?)?.toInt() ?? 0;
    final playing = j['playing'] as bool? ?? false;
    final trackId = j['trackId'];
    final trackKey = j['trackKey'];
    final pos =
        ((j['positionSeconds'] as num?) ?? (j['position'] as num?))
            ?.toDouble() ??
        0;
    final queueKeys = ((j['queueTrackKeys'] as List?) ?? const [])
        .map((e) => e.toString())
        .join(',');
    final posBucket = playing ? (pos * 2).round() : (pos * 4).round();
    return '$version|$playing|$trackId|$trackKey|$posBucket|$queueKeys';
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
    final participantIds = ((j['participantIds'] as List?) ?? const [])
        .map((e) => (e as num?)?.toInt())
        .whereType<int>()
        .toList();
    unawaited(_ensureParticipantNames(participantIds));
    session.applyRealtimeState(
      listenersCount: participantIds.length,
      participantIds: participantIds,
      participantNames: _participantNameCache,
      privateRoom: !(j['isOpen'] as bool? ?? false),
      pauseHostOnly: j['controlPauseHostOnly'] as bool? ?? true,
      seekHostOnly: j['controlSeekHostOnly'] as bool? ?? true,
      shuffleHostOnly: j['controlShuffleHostOnly'] as bool? ?? true,
      repeatHostOnly: j['controlRepeatHostOnly'] as bool? ?? true,
      skipHostOnly: j['controlSkipHostOnly'] as bool? ?? true,
      playlistHostOnly: j['controlPlaylistHostOnly'] as bool? ?? true,
    );
  }

  void _noteHostRoomVersion(int version) {
    if (!_isHost || version <= 0) return;
    if (version > _hostAppliedRoomVersion) {
      _hostAppliedRoomVersion = version;
    }
  }

  void _applyRoomDtoToSession(ColistenRoomStateDto state) {
    final session = ListeningRoomSession.instance;
    if (!session.active) return;
    unawaited(_ensureParticipantNames(state.participantIds));
    session.applyRealtimeState(
      listenersCount: state.participantIds.length,
      participantIds: state.participantIds,
      participantNames: _participantNameCache,
      privateRoom: !state.isOpen,
      pauseHostOnly: state.controlPauseHostOnly,
      seekHostOnly: state.controlSeekHostOnly,
      shuffleHostOnly: state.controlShuffleHostOnly,
      repeatHostOnly: state.controlRepeatHostOnly,
      skipHostOnly: state.controlSkipHostOnly,
      playlistHostOnly: state.controlPlaylistHostOnly,
    );
  }

  Future<void> _ensureParticipantNames(List<int> participantIds) async {
    final missing = participantIds
        .where((id) => id > 0 && !_participantNameCache.containsKey(id))
        .toList();
    if (missing.isEmpty) return;
    final acc = await AuthSessionStore.readAccount();
    final currentUserId = acc?.userId;
    if (currentUserId != null) {
      _participantNameCache[currentUserId] = acc?.nickname ?? '';
    }
    try {
      final friends = await FriendsApi().fetchFriends();
      for (final friend in friends) {
        _participantNameCache[friend.id] = friend.username;
      }
    } catch (_) {}
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
    _sink(
      jsonEncode(<String, dynamic>{
        'type': 'update_settings',
        'privateRoom': privateRoom,
        'controlPauseHostOnly': pauseHostOnly,
        'controlSeekHostOnly': seekHostOnly,
        'controlShuffleHostOnly': shuffleHostOnly,
        'controlRepeatHostOnly': repeatHostOnly,
        'controlSkipHostOnly': skipHostOnly,
        'controlPlaylistHostOnly': playlistHostOnly,
      }),
    );
  }

  void kickParticipant(int targetUserId) {
    if (!_isHost || targetUserId <= 0) return;
    _sink(
      jsonEncode(<String, dynamic>{
        'type': 'kick',
        'targetUserId': targetUserId,
      }),
    );
  }

  void onGuestManualPlayPauseToggle(AudioPlayerService audio) {
    if (_isHost || !ListeningRoomSession.instance.active) return;
  }

  void sendGuestPlayPauseCommand(
    AudioPlayerService audio, {
    required bool playing,
  }) {
    if (_isHost || !ListeningRoomSession.instance.active) return;
    final payload = _hostStatePayload(audio);
    final positionSeconds = (payload['position'] as num?)?.toDouble() ?? 0;
    final positionMs = (positionSeconds * 1000).round();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final pendingPlaying = _guestPendingPlayPausePlaying;
    if (pendingPlaying != null &&
        pendingPlaying != playing &&
        nowMs < _guestPendingPlayPauseUntilMs) {
      _log(
        'guest command playpause dropped pending-opposite room=$_roomId playing=$playing pending=$pendingPlaying pos=${positionSeconds.toStringAsFixed(3)}',
      );
      return;
    }
    final isDuplicateBounce =
        _lastGuestPlayPauseCommandPlaying != null &&
        _lastGuestPlayPauseCommandPlaying != playing &&
        nowMs - _lastGuestPlayPauseCommandAtMs <= 1800 &&
        (positionMs - _lastGuestPlayPauseCommandPositionMs).abs() <= 1000;
    if (isDuplicateBounce) {
      _log(
        'guest command playpause dropped bounce room=$_roomId playing=$playing pos=${positionSeconds.toStringAsFixed(3)}',
      );
      return;
    }
    _lastGuestPlayPauseCommandAtMs = nowMs;
    _lastGuestPlayPauseCommandPositionMs = positionMs;
    _lastGuestPlayPauseCommandPlaying = playing;
    _guestPendingPlayPausePlaying = playing;
    _guestPendingPlayPauseUntilMs = nowMs + 2600;
    final cmd = <String, dynamic>{
      'type': 'command',
      'playing': playing,
      'position': positionSeconds,
      'trackId': payload['trackId'],
      'trackKey': payload['trackKey'],
    };
    _log(
      'guest command playpause room=$_roomId playing=$playing trackId=${cmd['trackId']} key=${cmd['trackKey']} pos=${(cmd['position'] as double).toStringAsFixed(3)}',
    );
    final roomId = _roomId;
    final generation = _connectionGeneration;
    final serial = ++_guestCommandSerial;
    _pushHostStateNow(
      audio,
      forceRest: true,
      forceWs: true,
      guestPayloadOverride: cmd,
    );
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 650), () {
        if (_isHost ||
            _connectionGeneration != generation ||
            _roomId != roomId ||
            !ListeningRoomSession.instance.active ||
            serial != _guestCommandSerial ||
            _guestPendingPlayPausePlaying != playing) {
          return;
        }
        _log(
          'guest command playpause rest fallback room=$roomId playing=$playing pos=${positionSeconds.toStringAsFixed(3)}',
        );
        _pushHostStateNow(
          audio,
          forceRest: true,
          forceWs: false,
          guestPayloadOverride: cmd,
        );
      }),
    );
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 1700), () {
        if (_isHost ||
            _connectionGeneration != generation ||
            _roomId != roomId ||
            !ListeningRoomSession.instance.active ||
            serial != _guestCommandSerial ||
            _guestPendingPlayPausePlaying != playing) {
          return;
        }
        _log(
          'guest command playpause rest retry room=$roomId playing=$playing pos=${positionSeconds.toStringAsFixed(3)}',
        );
        _pushHostStateNow(
          audio,
          forceRest: true,
          forceWs: true,
          guestPayloadOverride: cmd,
        );
      }),
    );
  }

  void pushHostPlayPauseState(
    AudioPlayerService audio, {
    required bool playing,
  }) {
    if (!_isHost) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (_hostLastPlayPausePushedPlaying == playing &&
        nowMs - _hostLastPlayPausePushAtMs < 200) {
      _log(
        'host playpause skip duplicate room=$_roomId playing=$playing',
      );
      return;
    }
    _hostLastPlayPausePushedPlaying = playing;
    _hostLastPlayPausePushAtMs = nowMs;
    _hostLocalActionSerial++;
    _hostListenerMutedUntilMs = nowMs + 400;
    _hostLastSentSignature = null;
    _log(
      'host playpause room=$_roomId playing=$playing pos=${(audio.position.inMilliseconds / 1000.0).toStringAsFixed(3)}',
    );
    final position = audio.enginePosition.inMilliseconds / 1000.0;
    _pushHostControlPacket(
      audio,
      overrides: <String, dynamic>{
        'playing': playing,
        'position': position,
      },
    );
  }

  /// Seek/skip: контрольный пакет `command` + REST-ack (см. _pushHostControlPacket).
  void pushHostTransportState(
    AudioPlayerService audio, {
    double? positionSeconds,
    bool? playing,
  }) {
    if (!_isHost) return;
    _hostLocalActionSerial++;
    _hostLastSentSignature = null;
    final resolved = _resolveHostTrackFields(audio);
    final overrides = <String, dynamic>{
      'position': positionSeconds ??
          audio.enginePosition.inMilliseconds / 1000.0,
      'playing': playing ?? audio.isPlaying,
    };
    if (resolved.trackId != null) overrides['trackId'] = resolved.trackId;
    if (resolved.trackKey != null) overrides['trackKey'] = resolved.trackKey;
    _pushHostControlPacket(audio, overrides: overrides);
  }

  /// После skip/previous ждём смены [currentPlayablePath], затем шлём control.
  Future<void> pushHostTransportStateAfterSkip(
    AudioPlayerService audio, {
    String? previousPlayablePath,
  }) async {
    if (!_isHost) return;
    for (var i = 0; i < 30; i++) {
      final path = audio.currentPlayablePath?.trim() ?? '';
      if (path.isNotEmpty && path != (previousPlayablePath?.trim() ?? '')) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
    if (!_isHost || !ListeningRoomSession.instance.active) return;
    pushHostTransportState(
      audio,
      positionSeconds: 0,
      playing: audio.engineIsPlaying,
    );
  }

  void pushHostState(
    AudioPlayerService audio, {
    bool includeQueueForGuest = false,
  }) {
    if (_isHost) {
      _hostLocalActionSerial++;
    }
    _pushHostStateNow(
      audio,
      forceRest: true,
      forceWs: true,
      includeQueueForGuest: includeQueueForGuest,
    );
  }
}
