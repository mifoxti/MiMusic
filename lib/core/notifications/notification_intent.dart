import 'dart:convert';

enum NotificationTarget { friendProfile, release, colistenInvite }

class NotificationIntent {
  const NotificationIntent({
    required this.target,
    this.username,
    this.avatarUrl,
    this.releaseTitle,
    this.releaseCoverUrl,
    this.roomId,
  });

  final NotificationTarget target;
  final String? username;
  final String? avatarUrl;
  final String? releaseTitle;
  final String? releaseCoverUrl;
  final String? roomId;

  String toPayload() {
    return jsonEncode({
      'target': switch (target) {
        NotificationTarget.friendProfile => 'friend_profile',
        NotificationTarget.release => 'release',
        NotificationTarget.colistenInvite => 'colisten_invite',
      },
      'username': username,
      'avatarUrl': avatarUrl,
      'releaseTitle': releaseTitle,
      'releaseCoverUrl': releaseCoverUrl,
      'roomId': roomId,
    });
  }

  static NotificationIntent? fromPayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final map = jsonDecode(payload);
      if (map is! Map<String, dynamic>) return null;
      final targetRaw = map['target'] as String?;
      final target = switch (targetRaw) {
        'friend_profile' => NotificationTarget.friendProfile,
        'release' => NotificationTarget.release,
        'colisten_invite' => NotificationTarget.colistenInvite,
        _ => null,
      };
      if (target == null) return null;
      return NotificationIntent(
        target: target,
        username: map['username'] as String?,
        avatarUrl: map['avatarUrl'] as String?,
        releaseTitle: map['releaseTitle'] as String?,
        releaseCoverUrl: map['releaseCoverUrl'] as String?,
        roomId: map['roomId'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}
