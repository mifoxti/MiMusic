import 'dart:convert';

import 'authenticated_dio.dart';

class ServerNotificationDto {
  const ServerNotificationDto({
    required this.id,
    required this.type,
    this.actorUserId,
    this.actorNickname,
    required this.read,
    this.createdAt,
    this.entityRef,
    this.entityId,
    this.payloadJson,
  });

  final int id;
  final String type;
  final int? actorUserId;
  final String? actorNickname;
  final bool read;
  final String? createdAt;
  final String? entityRef;
  final int? entityId;
  final String? payloadJson;

  factory ServerNotificationDto.fromJson(Map<String, dynamic> j) {
    final eid = j['entityId'];
    return ServerNotificationDto(
      id: (j['id'] as num).toInt(),
      type: j['type'] as String? ?? 'unknown',
      actorUserId: (j['actorUserId'] as num?)?.toInt(),
      actorNickname: j['actorNickname'] as String?,
      read: j['read'] as bool? ?? false,
      createdAt: j['createdAt'] as String?,
      entityRef: j['entityRef'] as String?,
      entityId: eid is num ? eid.toInt() : null,
      payloadJson: j['payloadJson'] as String?,
    );
  }

  String? get colistenRoomId {
    final raw = payloadJson;
    if (raw != null && raw.isNotEmpty) {
      try {
        final map = jsonDecode(raw);
        if (map is! Map<String, dynamic>) return null;
        final id = map['roomId'] as String?;
        if (id == null || id.trim().isEmpty) return null;
        return id.trim();
      } catch (_) {}
    }
    final ref = entityRef;
    if (ref == null || ref.isEmpty) return null;
    const prefix = 'colisten_room_invite:';
    if (!ref.startsWith(prefix)) return null;
    final id = ref.substring(prefix.length).trim();
    if (id.isEmpty) return null;
    return id;
  }

  bool get isColistenInvite {
    if (type == 'colisten_invite') return true;
    final ref = entityRef;
    if (ref == null) return false;
    return ref.startsWith('colisten_room_invite:');
  }

  String get normalizedType {
    if (isColistenInvite) return 'colisten_invite';
    return type;
  }

  bool get isFriendRequest {
    return normalizedType == 'friend_request';
  }

  bool get isFriendAccepted {
    return normalizedType == 'friend_accepted';
  }

  bool get isAdminMessage {
    return normalizedType == 'admin_message';
  }

  String? get adminMessageTitle {
    if (!isAdminMessage) return null;
    final map = payloadMap;
    final t = map?['title'] as String?;
    if (t != null && t.trim().isNotEmpty) return t.trim();
    return null;
  }

  String? get adminMessageBody {
    if (!isAdminMessage) return null;
    final map = payloadMap;
    final b = map?['body'] as String?;
    if (b != null && b.trim().isNotEmpty) return b.trim();
    return null;
  }

  String? get adminMessageImageUrl {
    if (!isAdminMessage) return null;
    final map = payloadMap;
    final u = map?['imageUrl'] as String?;
    if (u != null && u.trim().isNotEmpty) return u.trim();
    return null;
  }

  int? get adminMessageTrackId {
    if (!isAdminMessage) return null;
    final map = payloadMap;
    final id = map?['trackId'];
    if (id is num && id > 0) return id.toInt();
    if (type == 'admin_message' && entityRef == 'track') return safeEntityId;
    return null;
  }

  int? get adminMessagePlaylistId {
    if (!isAdminMessage) return null;
    final map = payloadMap;
    final id = map?['playlistId'];
    if (id is num && id > 0) return id.toInt();
    if (type == 'admin_message' && entityRef == 'playlist') return safeEntityId;
    return null;
  }

  bool get isUnknown {
    return normalizedType.startsWith('unknown_');
  }

  String? get safeActorNickname {
    final nick = actorNickname?.trim();
    if (nick == null || nick.isEmpty) return null;
    return nick;
  }

  int? get safeActorUserId {
    final id = actorUserId;
    if (id == null || id <= 0) return null;
    return id;
  }

  int? get safeEntityId {
    final id = entityId;
    if (id == null || id <= 0) return null;
    return id;
  }

  String? get safeEntityRef {
    final ref = entityRef?.trim();
    if (ref == null || ref.isEmpty) return null;
    return ref;
  }

  bool get hasPayloadJson {
    final rawPayload = payloadJson;
    return rawPayload != null && rawPayload.trim().isNotEmpty;
  }

  Map<String, dynamic>? get payloadMap {
    final rawPayload = payloadJson;
    if (rawPayload == null || rawPayload.trim().isEmpty) return null;
    try {
      final parsed = jsonDecode(rawPayload);
      if (parsed is! Map<String, dynamic>) return null;
      return parsed;
    } catch (_) {
      return null;
    }
  }
}

class NotificationsApi {
  Future<List<ServerNotificationDto>> fetchNotifications({
    int limit = 50,
    bool unreadOnly = false,
  }) async {
    final dio = await createAuthenticatedDio();
    final res = await dio.get<List<dynamic>>(
      '/notifications',
      queryParameters: {
        'limit': limit,
        if (unreadOnly) 'unreadOnly': 'true',
      },
    );
    final data = res.data;
    if (data == null) return [];
    return data
        .map((e) => ServerNotificationDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<int> fetchUnreadCount() async {
    final dio = await createAuthenticatedDio();
    final res = await dio.get<Map<String, dynamic>>('/notifications/unread-count');
    final c = res.data?['count'];
    if (c is int) return c;
    if (c is num) return c.toInt();
    return 0;
  }

  Future<void> markRead(int id) async {
    final dio = await createAuthenticatedDio();
    await dio.post<void>('/notifications/$id/read');
  }

  Future<void> markAllRead() async {
    final dio = await createAuthenticatedDio();
    await dio.post<void>('/notifications/read-all');
  }

  Future<void> deleteNotification(int id) async {
    final dio = await createAuthenticatedDio();
    await dio.delete<void>('/notifications/$id');
  }

  Future<void> deleteAll() async {
    final dio = await createAuthenticatedDio();
    await dio.delete<void>('/notifications/all');
  }
}
