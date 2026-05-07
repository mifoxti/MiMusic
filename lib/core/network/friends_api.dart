import 'authenticated_dio.dart';

class FriendRemoteDto {
  const FriendRemoteDto({
    required this.id,
    required this.username,
    required this.online,
    this.nowPlaying,
    this.activeColistenRoomId,
  });

  final int id;
  final String username;
  final bool online;
  final FriendNowPlayingDto? nowPlaying;
  final String? activeColistenRoomId;

  factory FriendRemoteDto.fromJson(Map<String, dynamic> j) {
    final np = j['nowPlaying'];
    return FriendRemoteDto(
      id: (j['id'] as num).toInt(),
      username: j['username'] as String? ?? '',
      online: j['online'] as bool? ?? false,
      nowPlaying: np is Map<String, dynamic> ? FriendNowPlayingDto.fromJson(np) : null,
      activeColistenRoomId: j['activeColistenRoomId'] as String?,
    );
  }
}

class FriendNowPlayingDto {
  const FriendNowPlayingDto({
    required this.trackId,
    required this.title,
    this.artist,
  });

  final int trackId;
  final String title;
  final String? artist;

  factory FriendNowPlayingDto.fromJson(Map<String, dynamic> j) {
    return FriendNowPlayingDto(
      trackId: (j['trackId'] as num).toInt(),
      title: j['title'] as String? ?? '',
      artist: j['artist'] as String?,
    );
  }
}

class FriendIncomingDto {
  const FriendIncomingDto({
    required this.fromUserId,
    required this.nickname,
    this.createdAt,
  });

  final int fromUserId;
  final String nickname;
  final String? createdAt;

  factory FriendIncomingDto.fromJson(Map<String, dynamic> j) {
    return FriendIncomingDto(
      fromUserId: (j['fromUserId'] as num).toInt(),
      nickname: j['nickname'] as String? ?? '',
      createdAt: j['createdAt'] as String?,
    );
  }
}

class FriendsApi {
  Future<List<FriendRemoteDto>> fetchFriends() async {
    final dio = await createAuthenticatedDio();
    final res = await dio.get<List<dynamic>>('/friends');
    final data = res.data;
    if (data == null) return [];
    return data
        .map((e) => FriendRemoteDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<FriendIncomingDto>> fetchIncomingRequests() async {
    final dio = await createAuthenticatedDio();
    final res = await dio.get<List<dynamic>>('/friends/requests/incoming');
    final data = res.data;
    if (data == null) return [];
    return data
        .map((e) => FriendIncomingDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> sendFriendRequest(int toUserId) async {
    final dio = await createAuthenticatedDio();
    await dio.post<void>(
      '/friends',
      data: <String, dynamic>{'friendId': toUserId},
    );
  }

  Future<void> acceptIncomingRequest(int fromUserId) async {
    final dio = await createAuthenticatedDio();
    await dio.post<void>('/friends/requests/$fromUserId/accept');
  }

  Future<void> declineIncomingRequest(int fromUserId) async {
    final dio = await createAuthenticatedDio();
    await dio.post<void>('/friends/requests/$fromUserId/decline');
  }

  Future<void> removeFriend(int friendId) async {
    final dio = await createAuthenticatedDio();
    await dio.delete<void>('/friends/$friendId');
  }
}
