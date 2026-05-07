import 'package:dio/dio.dart';

import 'api_config.dart';
import 'authenticated_dio.dart';

class ColistenRoomStateDto {
  const ColistenRoomStateDto({
    required this.roomId,
    required this.ownerId,
    this.isOpen = false,
    this.trackId,
    this.trackKey,
    this.queueTrackIds = const [],
    this.queueTrackKeys = const [],
    this.positionSeconds = 0,
    this.playing = false,
    this.controlPauseHostOnly = true,
    this.controlSeekHostOnly = true,
    this.controlShuffleHostOnly = true,
    this.controlRepeatHostOnly = true,
    this.controlSkipHostOnly = true,
    this.controlPlaylistHostOnly = true,
    this.participantIds = const [],
    this.stateVersion = 0,
    this.wallClockMs = 0,
  });

  final String roomId;
  final int ownerId;
  final bool isOpen;
  final int? trackId;
  final String? trackKey;
  final List<int> queueTrackIds;
  final List<String> queueTrackKeys;
  final double positionSeconds;
  final bool playing;
  final bool controlPauseHostOnly;
  final bool controlSeekHostOnly;
  final bool controlShuffleHostOnly;
  final bool controlRepeatHostOnly;
  final bool controlSkipHostOnly;
  final bool controlPlaylistHostOnly;
  final List<int> participantIds;
  final int stateVersion;
  final int wallClockMs;

  factory ColistenRoomStateDto.fromJson(Map<String, dynamic> j) {
    final p = j['participantIds'];
    final q = j['queueTrackIds'];
    return ColistenRoomStateDto(
      roomId: j['roomId'] as String? ?? '',
      ownerId: (j['ownerId'] as num).toInt(),
      isOpen: j['isOpen'] as bool? ?? false,
      trackId: (j['trackId'] as num?)?.toInt(),
      trackKey: j['trackKey'] as String?,
      queueTrackIds: q is List ? q.map((e) => (e as num).toInt()).toList() : const [],
      queueTrackKeys: (j['queueTrackKeys'] is List)
          ? (j['queueTrackKeys'] as List).map((e) => e.toString()).toList()
          : const [],
      positionSeconds: (j['positionSeconds'] as num?)?.toDouble() ?? 0,
      playing: j['playing'] as bool? ?? false,
      controlPauseHostOnly: j['controlPauseHostOnly'] as bool? ?? true,
      controlSeekHostOnly: j['controlSeekHostOnly'] as bool? ?? true,
      controlShuffleHostOnly: j['controlShuffleHostOnly'] as bool? ?? true,
      controlRepeatHostOnly: j['controlRepeatHostOnly'] as bool? ?? true,
      controlSkipHostOnly: j['controlSkipHostOnly'] as bool? ?? true,
      controlPlaylistHostOnly: j['controlPlaylistHostOnly'] as bool? ?? true,
      participantIds: p is List ? p.map((e) => (e as num).toInt()).toList() : const [],
      stateVersion: (j['stateVersion'] as num?)?.toInt() ?? 0,
      wallClockMs: (j['wallClockMs'] as num?)?.toInt() ?? 0,
    );
  }
}

class OpenColistenRoomDto {
  const OpenColistenRoomDto({
    required this.roomId,
    required this.ownerId,
    required this.ownerNickname,
    this.trackId,
    this.trackTitle,
    this.trackArtist,
    this.positionSeconds = 0,
    this.playing = false,
    this.listenersCount = 0,
    this.stateVersion = 0,
    this.wallClockMs = 0,
  });

  final String roomId;
  final int ownerId;
  final String ownerNickname;
  final int? trackId;
  final String? trackTitle;
  final String? trackArtist;
  final double positionSeconds;
  final bool playing;
  final int listenersCount;
  final int stateVersion;
  final int wallClockMs;

  factory OpenColistenRoomDto.fromJson(Map<String, dynamic> j) {
    return OpenColistenRoomDto(
      roomId: j['roomId'] as String? ?? '',
      ownerId: (j['ownerId'] as num).toInt(),
      ownerNickname: j['ownerNickname'] as String? ?? '',
      trackId: (j['trackId'] as num?)?.toInt(),
      trackTitle: j['trackTitle'] as String?,
      trackArtist: j['trackArtist'] as String?,
      positionSeconds: (j['positionSeconds'] as num?)?.toDouble() ?? 0,
      playing: j['playing'] as bool? ?? false,
      listenersCount: (j['listenersCount'] as num?)?.toInt() ?? 0,
      stateVersion: (j['stateVersion'] as num?)?.toInt() ?? 0,
      wallClockMs: (j['wallClockMs'] as num?)?.toInt() ?? 0,
    );
  }
}

class ColistenApi {
  Future<String> createRoom({
    required bool isOpen,
    int? trackId,
    String? trackKey,
    List<String> queueTrackKeys = const [],
    double positionSeconds = 0,
    bool playing = false,
    bool controlPauseHostOnly = true,
    bool controlSeekHostOnly = true,
    bool controlShuffleHostOnly = true,
    bool controlRepeatHostOnly = true,
    bool controlSkipHostOnly = true,
    bool controlPlaylistHostOnly = true,
  }) async {
    final dio = await createAuthenticatedDio();
    final res = await dio.post<Map<String, dynamic>>(
      '/colisten/room',
      data: <String, dynamic>{
        'isOpen': isOpen,
        if (trackId case final value?) 'trackId': value,
        if (trackKey case final value?) 'trackKey': value,
        'queueTrackKeys': queueTrackKeys,
        'positionSeconds': positionSeconds,
        'playing': playing,
        'controlPauseHostOnly': controlPauseHostOnly,
        'controlSeekHostOnly': controlSeekHostOnly,
        'controlShuffleHostOnly': controlShuffleHostOnly,
        'controlRepeatHostOnly': controlRepeatHostOnly,
        'controlSkipHostOnly': controlSkipHostOnly,
        'controlPlaylistHostOnly': controlPlaylistHostOnly,
      },
    );
    final id = res.data?['roomId'] as String?;
    if (id == null || id.isEmpty) {
      throw StateError('No roomId');
    }
    return id;
  }

  Future<ColistenRoomStateDto> getRoomState(String roomId) async {
    final dio = await createAuthenticatedDio();
    final res = await dio.get<Map<String, dynamic>>('/colisten/room/$roomId');
    final data = res.data;
    if (data == null) throw StateError('Empty room state');
    return ColistenRoomStateDto.fromJson(data);
  }

  Future<List<OpenColistenRoomDto>> fetchOpenRooms() async {
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl.replaceAll(RegExp(r'/+$'), ''),
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
      ),
    );
    final res = await dio.get<List<dynamic>>('/colisten/rooms/open');
    final data = res.data;
    if (data == null) return [];
    return data
        .map((e) => OpenColistenRoomDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<int> inviteUsers({
    required String roomId,
    required List<int> userIds,
  }) async {
    final dio = await createAuthenticatedDio();
    final res = await dio.post<Map<String, dynamic>>(
      '/colisten/room/$roomId/invite',
      data: <String, dynamic>{'userIds': userIds},
    );
    final v = res.data?['invited'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }
}
