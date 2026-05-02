import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'steam_invite_key.dart';

const _kOnboarding = 'mimusic_onboarding_completed_v1';
const _kAccount = 'mimusic_local_account_v1';
const _kIssuedInviteKeys = 'mimusic_issued_invite_keys_v1';

/// Локальная учётная запись (без сервера): хэш пароля + токен сессии в SharedPreferences.
class LocalAccount {
  const LocalAccount({
    required this.email,
    required this.passwordHash,
    required this.nickname,
    required this.sessionToken,
    this.myInviteKey,
  });

  final String email;
  final String passwordHash;
  final String nickname;
  final String sessionToken;

  /// Один сгенерированный пригласительный ключ (Steam-формат), если уже создан.
  final String? myInviteKey;

  bool get isLoggedIn => sessionToken.isNotEmpty;

  bool get hasMyInviteKey =>
      myInviteKey != null && myInviteKey!.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'email': email,
        'passwordHash': passwordHash,
        'nickname': nickname,
        'sessionToken': sessionToken,
        if (myInviteKey != null && myInviteKey!.trim().isNotEmpty)
          'myInviteKey': myInviteKey,
      };

  static LocalAccount? fromJson(Map<String, dynamic>? map) {
    if (map == null) return null;
    final email = map['email'] as String? ?? '';
    final passwordHash = map['passwordHash'] as String? ?? '';
    if (email.isEmpty || passwordHash.isEmpty) return null;
    return LocalAccount(
      email: email,
      passwordHash: passwordHash,
      nickname: map['nickname'] as String? ?? email.split('@').first,
      sessionToken: map['sessionToken'] as String? ?? '',
      myInviteKey: map['myInviteKey'] as String?,
    );
  }

  LocalAccount copyWith({
    String? email,
    String? passwordHash,
    String? nickname,
    String? sessionToken,
    String? myInviteKey,
  }) {
    return LocalAccount(
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      nickname: nickname ?? this.nickname,
      sessionToken: sessionToken ?? this.sessionToken,
      myInviteKey: myInviteKey ?? this.myInviteKey,
    );
  }
}

abstract final class AuthSessionStore {
  static Future<SharedPreferences> _p() => SharedPreferences.getInstance();

  /// Ключи, выданные на этом устройстве (для проверки при регистрации другого локального аккаунта).
  static final Set<String> _issuedInviteKeysCache = {};

  static Set<String> get issuedInviteKeysSnapshot =>
      Set<String>.from(_issuedInviteKeysCache);

  static Future<void> refreshIssuedInviteKeysCache() async {
    final p = await _p();
    final raw = p.getString(_kIssuedInviteKeys);
    _issuedInviteKeysCache.clear();
    if (raw == null || raw.isEmpty) return;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      for (final e in list) {
        if (e is String && e.isNotEmpty) {
          _issuedInviteKeysCache.add(SteamInviteKey.normalize(e));
        }
      }
    } catch (_) {}
  }

  static Future<void> _persistIssuedInviteKeys() async {
    final p = await _p();
    await p.setString(
      _kIssuedInviteKeys,
      jsonEncode(_issuedInviteKeysCache.toList()),
    );
  }

  static Future<void> registerIssuedInviteKey(String key) async {
    final k = SteamInviteKey.normalize(key);
    if (!SteamInviteKey.matchesFormat(k)) return;
    await refreshIssuedInviteKeysCache();
    _issuedInviteKeysCache.add(k);
    await _persistIssuedInviteKeys();
  }

  static bool isKnownIssuedInviteKey(String normalizedUpper) =>
      _issuedInviteKeysCache.contains(normalizedUpper);

  /// Сохраняет ключ в аккаунт и в реестр выданных (один раз на пользователя).
  static Future<void> saveGeneratedInviteKey(String key) async {
    final acc = await readAccount();
    if (acc == null || acc.hasMyInviteKey) return;
    final k = SteamInviteKey.normalize(key);
    if (!SteamInviteKey.matchesFormat(k)) return;
    await registerIssuedInviteKey(k);
    await writeAccount(acc.copyWith(myInviteKey: k));
  }

  static Future<bool> isOnboardingCompleted() async {
    final p = await _p();
    return p.getBool(_kOnboarding) ?? false;
  }

  static Future<void> setOnboardingCompleted() async {
    final p = await _p();
    await p.setBool(_kOnboarding, true);
  }

  static Future<LocalAccount?> readAccount() async {
    final p = await _p();
    final raw = p.getString(_kAccount);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return LocalAccount.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  static Future<void> writeAccount(LocalAccount account) async {
    final p = await _p();
    await p.setString(_kAccount, jsonEncode(account.toJson()));
  }

  static Future<void> clearSessionToken() async {
    final acc = await readAccount();
    if (acc == null) return;
    await writeAccount(acc.copyWith(sessionToken: ''));
  }

  static Future<bool> isLoggedIn() async {
    final acc = await readAccount();
    return acc != null && acc.isLoggedIn;
  }

  static String generateSessionToken() {
    final b = List<int>.generate(48, (_) => Random.secure().nextInt(256));
    return base64UrlEncode(b);
  }
}
