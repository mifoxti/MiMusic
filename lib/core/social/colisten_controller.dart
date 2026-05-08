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
  Timer? _guestTimer;
  Timer? _guestSnapshotTimer;
  void Function()? _hostListener;
  AudioPlayerService? _hostAudio;
  bool _hostRestSyncInFlight = false;
  bool _hostPendingRestSync = false;
  Map<String, dynamic>? _guestPendingCommandPayload;
  int _hostLastRestSyncAtMs = 0;
  int _hostLastWsSyncAtMs = 0;
  String? _hostLastSentSignature;
  int _connectionGeneration = 0;
  int _hostAppliedRoomVersion = 0;
  int _hostOutboundBlockers = 0;
  int _hostSuppressOutboundUntilMs = 0;
  Future<void> _hostWsApplyChain = Future<void>.value();
  Future<void> _hostRemoteCommandChain = Future<void>.value();
  int _hostRemoteCommandSerial = 0;
  int _hostLocalActionSerial = 0;
  Map<String, dynamic>? _hostRemoteAuthoritativeOverride;
  int _hostRemoteAuthoritativeOverrideUntilMs = 0;

  bool _isHost = false;
  int _guestLastVersion = 0;
  int _guestAppliedVersion = 0;
  Future<void> _guestApplyChain = Future<void>.value();
  double _guestTargetPositionSeconds = 0;
  bool _guestTargetPlaying = false;
  int _guestTargetAnchorLocalMs = 0;
  int _guestLastTightSeekAtMs = 0;
  bool _guestNeedsInitialHardSync = false;
  bool _guestNeedsFirstRealtimeHardSync = false;
  bool _guestSnapshotInFlight = false;
  Completer<void>? _guestFirstRealtimeStateCompleter;
  int _lastGuestPlayPauseCommandAtMs = 0;
  int _lastGuestPlayPauseCommandPositionMs = 0;
  bool? _lastGuestPlayPauseCommandPlaying;
  bool? _guestPendingPlayPausePlaying;
  int _guestPendingPlayPauseUntilMs = 0;
  int _guestCommandSerial = 0;
  String? _roomId;
  final Map<int, Track> _trackCache = <int, Track>{};
  final Map<int, String> _participantNameCache = <int, String>{};
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
    _hostSnapshotTimer?.cancel();
    _hostSnapshotTimer = null;
    _guestTimer?.cancel();
    _guestTimer = null;
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
    _hostWsApplyChain = Future<void>.value();
    _hostRemoteCommandChain = Future<void>.value();
    _hostRemoteCommandSerial = 0;
    _hostLocalActionSerial = 0;
    _hostRemoteAuthoritativeOverride = null;
    _hostRemoteAuthoritativeOverrideUntilMs = 0;
    _connectionGeneration++;
    await _sub?.cancel();
    _sub = null;
    await _channel?.sink.close();
    _channel = null;
    _isHost = false;
    _guestLastVersion = 0;
    _guestAppliedVersion = 0;
    _guestApplyChain = Future<void>.value();
    _guestTargetPositionSeconds = 0;
    _guestTargetPlaying = false;
    _guestTargetAnchorLocalMs = 0;
    _guestLastTightSeekAtMs = 0;
    _guestNeedsInitialHardSync = false;
    _guestNeedsFirstRealtimeHardSync = false;
    _guestSnapshotInFlight = false;
    _guestFirstRealtimeStateCompleter = null;
    _lastGuestPlayPauseCommandAtMs = 0;
    _lastGuestPlayPauseCommandPositionMs = 0;
    _lastGuestPlayPauseCommandPlaying = null;
    _guestPendingPlayPausePlaying = null;
    _guestPendingPlayPauseUntilMs = 0;
    _guestCommandSerial = 0;
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
    await disconnect();
    final generation = ++_connectionGeneration;
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
    final uri = Uri.parse(wsUrl(roomId, token));
    _channel = WebSocketChannel.connect(uri);
    _sub = _channel!.stream.listen(
      (raw) {
        if (raw is! String) return;
        _onGuestMessage(raw, audio);
      },
      onError: (Object e, StackTrace st) {
        _log('guest ws error room=$roomId error=$e');
      },
      onDone: () {
        _log('guest ws done room=$roomId');
      },
    );
    _guestTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      unawaited(_guestTightSync(audio));
    });
    _guestSnapshotTimer = Timer.periodic(const Duration(milliseconds: 700), (
      _,
    ) {
      if (_isHost ||
          _roomId != roomId ||
          !ListeningRoomSession.instance.active) {
        return;
      }
      if (_guestSnapshotInFlight) return;
      _guestSnapshotInFlight = true;
      unawaited(
        _refreshGuestSnapshot(
              roomId,
              audio,
              generation: generation,
              delayMs: 0,
              forceTrackReload: false,
              forcePositionSync: false,
            )
            .timeout(const Duration(seconds: 3))
            .catchError(
              (e) => _log('guest snapshot error room=$roomId error=$e'),
            )
            .whenComplete(() => _guestSnapshotInFlight = false),
      );
    });
    try {
      try {
        final initial = await ColistenApi().getRoomState(roomId);
        _log(
          'guest initial state room=$roomId v=${initial.stateVersion} trackId=${initial.trackId} key=${initial.trackKey} pos=${initial.positionSeconds.toStringAsFixed(3)} playing=${initial.playing} queue=${initial.queueTrackKeys.length}/${initial.queueTrackIds.length}',
        );
        if (initial.stateVersion > _guestAppliedVersion) {
          await _applyGuestState(
            <String, dynamic>{
              'stateVersion': initial.stateVersion,
              'isOpen': initial.isOpen,
              'trackId': initial.trackId,
              'trackKey': initial.trackKey,
              'queueTrackIds': initial.queueTrackIds,
              'queueTrackKeys': initial.queueTrackKeys,
              'positionSeconds': initial.positionSeconds,
              'playing': initial.playing,
              'shuffleEnabled': initial.shuffleEnabled,
              'repeatMode': initial.repeatMode,
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
            generation: generation,
            forceTrackReload: true,
            forcePositionSync: true,
          );
          initialBootstrapOk = true;
        }
      } catch (_) {}
      if (!initialBootstrapOk) {
        await forceGuestSnapshotSync(
          audio,
          forceTrackReload: true,
          forcePositionSync: true,
        );
        await _refreshGuestSnapshot(
          roomId,
          audio,
          generation: generation,
          delayMs: 150,
          forceTrackReload: true,
          forcePositionSync: true,
        );
        _scheduleGuestPostConnectSnapshots(roomId, audio, generation);
      } else {
        _scheduleGuestPostConnectSnapshots(
          roomId,
          audio,
          generation,
          forcePositionSync: false,
        );
      }
      final firstRealtime = _guestFirstRealtimeStateCompleter;
      if (firstRealtime != null && !firstRealtime.isCompleted) {
        try {
          await firstRealtime.future.timeout(
            const Duration(milliseconds: 1200),
          );
        } catch (_) {}
      }
    } finally {
      ListeningRoomSession.instance.setJoining(false);
    }
  }

  void _scheduleGuestPostConnectSnapshots(
    String roomId,
    AudioPlayerService audio,
    int generation, {
    bool forcePositionSync = true,
  }) {
    // На слабой сети / девайсах первый join/state может быть устаревшим.
    // Берём несколько контрольных снимков, чтобы гарантированно дойти
    // до актуального тайминга хоста в первый заход.
    const delaysMs = <int>[450, 1200, 2300];
    for (final delay in delaysMs) {
      unawaited(
        _refreshGuestSnapshot(
          roomId,
          audio,
          generation: generation,
          delayMs: delay,
          forceTrackReload: false,
          forcePositionSync: forcePositionSync,
        ),
      );
    }
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
    try {
      final state = await ColistenApi().getRoomState(roomId);
      _log(
        'guest snapshot room=$roomId v=${state.stateVersion} trackId=${state.trackId} key=${state.trackKey} pos=${state.positionSeconds.toStringAsFixed(3)} playing=${state.playing}',
      );
      if (state.stateVersion <= _guestAppliedVersion) return;
      await _applyGuestState(
        <String, dynamic>{
          'stateVersion': state.stateVersion,
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
        },
        audio,
        generation: generation,
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
      if (state.stateVersion <= _guestAppliedVersion &&
          !forceTrackReload &&
          !forcePositionSync) {
        return;
      }
      await _applyGuestState(
        <String, dynamic>{
          'stateVersion': state.stateVersion,
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
        },
        audio,
        generation: generation,
        forceTrackReload: forceTrackReload,
        forcePositionSync: forcePositionSync,
      );
    } catch (_) {}
  }

  Map<String, dynamic> _hostStatePayload(AudioPlayerService audio) {
    final current = audio.currentTrack;
    final tid = current == null
        ? null
        : TracksApi().resolveServerTrackId(
            assetPath: current.assetPath,
            audioFilePath: current.audioFilePath,
          );
    final trackKey = current == null
        ? null
        : TracksApi().trackKeyForPaths(
            assetPath: current.assetPath,
            audioFilePath: current.audioFilePath,
          );
    final payload = <String, dynamic>{
      'type': 'host_state',
      'queueTrackIds': _queueTrackIdsFromAudio(audio),
      'queueTrackKeys': _queueTrackKeysFromAudio(audio),
      'position': audio.position.inMilliseconds / 1000.0,
      'playing': audio.isPlaying,
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
      }
      return;
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (!force && nowMs - _hostLastRestSyncAtMs < 1500) return;
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
              _syncHostStateViaRest(audio, force: true);
            }
          }),
    );
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
      if (!forceWs && nowMs - _hostLastWsSyncAtMs < 350) return;
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
                if (state != null) _applyRoomDtoToSession(state);
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
    if (_hostOutboundBlockers > 0) {
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
    final shouldSendWs = forceWs || nowMs - _hostLastWsSyncAtMs >= 700;
    var sent = false;
    if ((hasTrack || hasQueue) && shouldSendWs) {
      _hostLastWsSyncAtMs = nowMs;
      _sink(jsonEncode(payload));
      sent = true;
    }
    if (forceRest || nowMs - _hostLastRestSyncAtMs >= 1500) {
      _syncHostStateViaRest(audio, force: forceRest, payloadOverride: payload);
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
    await disconnect();
    ++_connectionGeneration;
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
    );

    void listener() {
      if (!_isHost) return;
      _pushHostStateNow(audio);
    }

    _hostListener = listener;
    audio.addListener(listener);
    listener();

    _hostTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!_isHost) return;
      listener();
    });
    _hostSnapshotTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_refreshHostSessionSnapshot(roomId));
    });
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
      if (j['type'] != 'state') return;
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
          await _applyRoomPlaybackPayload(
            j,
            audio,
            applyGeneration: generation,
            forceTrackReload: false,
            forcePositionSync: true,
            guestTimelineHints: false,
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

  void _onGuestMessage(String raw, AudioPlayerService audio) {
    final generation = _connectionGeneration;
    if (!ListeningRoomSession.instance.active) {
      unawaited(disconnect());
      return;
    }
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      if (j['type'] == 'kicked') {
        unawaited(_handleKickedFromRoom(audio));
        return;
      }
      if (j['type'] != 'state') return;
      final ver = (j['stateVersion'] as num?)?.toInt() ?? 0;
      if (ver <= _guestLastVersion) return;
      _guestLastVersion = ver;
      _log(
        'guest ws state room=$_roomId v=$ver trackId=${j['trackId']} key=${j['trackKey']} pos=${j['positionSeconds'] ?? j['position']} playing=${j['playing']}',
      );
      _guestApplyChain = _guestApplyChain.then((_) async {
        if (_connectionGeneration != generation) return;
        if (ver <= _guestAppliedVersion) return;
        final forceRealtimePositionSync = _guestNeedsFirstRealtimeHardSync;
        await _applyGuestState(
          j,
          audio,
          generation: generation,
          forcePositionSync: forceRealtimePositionSync,
        );
        if (_connectionGeneration != generation) return;
        _guestNeedsFirstRealtimeHardSync = false;
        final firstRealtime = _guestFirstRealtimeStateCompleter;
        if (firstRealtime != null && !firstRealtime.isCompleted) {
          firstRealtime.complete();
        }
        _guestAppliedVersion = ver;
      });
    } catch (_) {}
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
    final pos =
        ((j['positionSeconds'] as num?) ?? (j['position'] as num?))
            ?.toDouble() ??
        0;
    final playing = j['playing'] as bool? ?? false;
    final shuffleEnabled = j['shuffleEnabled'] as bool?;
    final repeatMode = (j['repeatMode'] as String?)?.trim().toLowerCase();
    final roleTag = guestTimelineHints ? 'guest' : 'host';
    _log(
      '$roleTag playback room=$_roomId trackId=$tid key=$trackKey pos=${pos.toStringAsFixed(3)} playing=$playing forceReload=$forceTrackReload',
    );
    final anchorLocalMs = DateTime.now().millisecondsSinceEpoch;
    if (guestTimelineHints) {
      _guestTargetPositionSeconds = pos;
      _guestTargetPlaying = playing;
      _guestTargetAnchorLocalMs = anchorLocalMs;
    }
    final effectiveQueueKeys = queueKeys.isNotEmpty
        ? queueKeys
        : queueIds.map((id) => 'srv:$id').toList();
    List<Track> roomQueue = const [];
    if (effectiveQueueKeys.isNotEmpty) {
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
          .map(
            (t) => TracksApi().trackKeyForPaths(
              assetPath: t.assetPath,
              audioFilePath: t.audioFilePath,
            ),
          )
          .toList();
      final tr = await _trackFromTrackKey(effectiveTrackKey);
      if (_connectionGeneration != applyGeneration) return;
      final roomQueueKeys = effectiveQueueKeys;
      final queueMismatch =
          roomQueueKeys.isNotEmpty &&
          !_sameStringList(currentQueueKeys, roomQueueKeys);
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
        await audio.replaceQueueFromRoomSync(roomQueue);
      }
    }
    final seekTargetSeconds = () {
      if (!playing || anchorLocalMs <= 0) return pos;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final elapsedMs = (nowMs - anchorLocalMs).clamp(0, 15000);
      return pos + (elapsedMs / 1000.0);
    }();
    final seekPos = Duration(milliseconds: (seekTargetSeconds * 1000).round());
    final currentMs = audio.position.inMilliseconds;
    final targetMs = seekPos.inMilliseconds;
    final signedDiffMs = targetMs - currentMs;
    final hardSyncNow = guestTimelineHints && _guestNeedsInitialHardSync;
    final needForwardHardSeek = signedDiffMs >= 1400;
    final needBackwardHardSeek = signedDiffMs <= -3000;
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
    if (playing) {
      await audio.playFromRoomSync();
      if (guestTimelineHints) {
        await _guestTightSync(audio);
      }
    } else {
      await audio.pauseFromRoomSync();
    }
    final needsPostSettleSeek =
        guestTimelineHints &&
        playing &&
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
    final version = (j['stateVersion'] as num?)?.toInt() ?? 0;
    if (version > 0 &&
        version <= _guestAppliedVersion &&
        !forceTrackReload &&
        !forcePositionSync) {
      return;
    }
    _applySessionState(j);
    // Как только получили и применили состояние комнаты, убираем "Connecting...":
    // дальнейшие доп.снапшоты могут идти в фоне, но пользователь уже синхронизируется.
    ListeningRoomSession.instance.setJoining(false);
    await _applyRoomPlaybackPayload(
      j,
      audio,
      applyGeneration: applyGeneration,
      forceTrackReload: forceTrackReload,
      forcePositionSync: forcePositionSync,
      guestTimelineHints: true,
    );
    if (_connectionGeneration != applyGeneration) return;
    if (version > _guestAppliedVersion) {
      _guestAppliedVersion = version;
    }
    if (version > _guestLastVersion) {
      _guestLastVersion = version;
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
    final attempts = trackWasReloaded ? 8 : 4;
    for (var i = 0; i < attempts; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 320));
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
    final needForwardCatchup = driftSec >= 1.0;
    // Лёгкое опережение не трогаем: иначе возможны заметные подёргивания.
    final needBackwardCorrection = driftSec <= -3.2;
    if ((needForwardCatchup || needBackwardCorrection) &&
        sinceLastSeekMs >= 2500) {
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
        'controlPauseHostOnly': true,
        'controlSeekHostOnly': true,
        'controlShuffleHostOnly': true,
        'controlRepeatHostOnly': true,
        'controlSkipHostOnly': true,
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
      forceRest: false,
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

  void _scheduleHostStateFollowUps(
    AudioPlayerService audio, {
    Map<String, dynamic>? hostPayloadOverride,
  }) {
    const delays = <Duration>[
      Duration(milliseconds: 180),
      Duration(milliseconds: 650),
      Duration(milliseconds: 1200),
    ];
    for (final delay in delays) {
      unawaited(
        Future<void>.delayed(delay, () {
          if (!_isHost || !ListeningRoomSession.instance.active) return;
          _pushHostStateNow(
            audio,
            forceRest: true,
            forceWs: true,
            hostPayloadOverride: hostPayloadOverride,
          );
        }),
      );
    }
  }

  void pushHostPlayPauseState(
    AudioPlayerService audio, {
    required bool playing,
  }) {
    if (!_isHost) return;
    _hostLocalActionSerial++;
    final payload = _hostStatePayload(audio);
    final override = <String, dynamic>{
      'playing': playing,
      'position': payload['position'],
    };
    _setHostAuthoritativeOverride(override);
    _pushHostStateNow(
      audio,
      forceRest: true,
      forceWs: true,
      hostPayloadOverride: override,
    );
    _scheduleHostStateFollowUps(audio, hostPayloadOverride: override);
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
    if (!_isHost) return;
    _scheduleHostStateFollowUps(audio);
  }
}
