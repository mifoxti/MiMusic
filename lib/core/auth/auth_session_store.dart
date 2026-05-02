import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

const _kOnboarding = 'mimusic_onboarding_completed_v1';
const _kAccount = 'mimusic_local_account_v1';

/// Локальная учётная запись (без сервера): хэш пароля + токен сессии в SharedPreferences.
class LocalAccount {
  const LocalAccount({
    required this.email,
    required this.passwordHash,
    required this.nickname,
    required this.sessionToken,
  });

  final String email;
  final String passwordHash;
  final String nickname;
  final String sessionToken;

  bool get isLoggedIn => sessionToken.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'email': email,
        'passwordHash': passwordHash,
        'nickname': nickname,
        'sessionToken': sessionToken,
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
    );
  }

  LocalAccount copyWith({
    String? email,
    String? passwordHash,
    String? nickname,
    String? sessionToken,
  }) {
    return LocalAccount(
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      nickname: nickname ?? this.nickname,
      sessionToken: sessionToken ?? this.sessionToken,
    );
  }
}

abstract final class AuthSessionStore {
  static Future<SharedPreferences> _p() => SharedPreferences.getInstance();

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
