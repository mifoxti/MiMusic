import 'dart:convert';

enum NotificationTarget { friendProfile, release }

class NotificationIntent {
  const NotificationIntent({
    required this.target,
    this.username,
    this.avatarUrl,
    this.releaseTitle,
    this.releaseCoverUrl,
  });

  final NotificationTarget target;
  final String? username;
  final String? avatarUrl;
  final String? releaseTitle;
  final String? releaseCoverUrl;

  String toPayload() {
    return jsonEncode({
      'target': switch (target) {
        NotificationTarget.friendProfile => 'friend_profile',
        NotificationTarget.release => 'release',
      },
      'username': username,
      'avatarUrl': avatarUrl,
      'releaseTitle': releaseTitle,
      'releaseCoverUrl': releaseCoverUrl,
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
        _ => null,
      };
      if (target == null) return null;
      return NotificationIntent(
        target: target,
        username: map['username'] as String?,
        avatarUrl: map['avatarUrl'] as String?,
        releaseTitle: map['releaseTitle'] as String?,
        releaseCoverUrl: map['releaseCoverUrl'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}
