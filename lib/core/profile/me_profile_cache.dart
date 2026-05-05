import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../network/profile_api.dart';

const _kPrefsKey = 'mimusic_me_profile_cache_v1';

/// Снимок [GET /me] для быстрого показа профиля и сравнения с ответом сервера.
class MeProfileSnapshot {
  const MeProfileSnapshot({
    required this.userId,
    required this.nickname,
    this.avatarStorageKey,
    this.bio,
  });

  final int userId;
  final String nickname;
  final String? avatarStorageKey;
  final String? bio;

  bool get hasServerAvatar =>
      avatarStorageKey != null && avatarStorageKey!.trim().isNotEmpty;

  factory MeProfileSnapshot.fromRemote(int userId, MeProfileRemote me) {
    return MeProfileSnapshot(
      userId: userId,
      nickname: me.nickname,
      avatarStorageKey: me.avatarStorageKey,
      bio: me.bio,
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'nickname': nickname,
        if (avatarStorageKey != null) 'avatarStorageKey': avatarStorageKey,
        if (bio != null) 'bio': bio,
      };

  static MeProfileSnapshot? fromJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    final uid = (j['userId'] as num?)?.toInt();
    if (uid == null) return null;
    return MeProfileSnapshot(
      userId: uid,
      nickname: j['nickname'] as String? ?? '',
      avatarStorageKey: j['avatarStorageKey'] as String?,
      bio: j['bio'] as String?,
    );
  }

  /// Те же поля, что влияют на шапку профиля и превью.
  bool matches(MeProfileRemote me) {
    return nickname == me.nickname &&
        (avatarStorageKey ?? '') == (me.avatarStorageKey ?? '') &&
        (bio ?? '') == (me.bio ?? '');
  }
}

/// Кэш профиля текущего пользователя: память + [SharedPreferences].
abstract final class MeProfileCache {
  static MeProfileSnapshot? _mem;

  static Future<MeProfileSnapshot?> loadForUser(int userId) async {
    if (_mem != null && _mem!.userId == userId) {
      return _mem;
    }
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kPrefsKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final s = MeProfileSnapshot.fromJson(j);
      if (s == null || s.userId != userId) return null;
      _mem = s;
      return s;
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(int userId, MeProfileRemote me) async {
    final next = MeProfileSnapshot.fromRemote(userId, me);
    _mem = next;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kPrefsKey, jsonEncode(next.toJson()));
  }

  static void clear() {
    _mem = null;
    SharedPreferences.getInstance().then((p) => p.remove(_kPrefsKey));
  }
}
