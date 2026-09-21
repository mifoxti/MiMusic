import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'invite_key_format.dart';

const _kOnboarding = 'mimusic_onboarding_completed_v1';
const _kAccount = 'mimusic_account_v2';
const _kIssuedInviteKeys = 'mimusic_issued_invite_keys_v1';
const _kSecureSessionToken = 'mimusic_session_token_v1';

const _secureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
  iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
);

/// Учётная запись: после входа через API — [userId] и [sessionToken] с сервера; [passwordHash] не хранится.
class LocalAccount {
  const LocalAccount({
    required this.email,
    required this.passwordHash,
    required this.nickname,
    required this.sessionToken,
    this.userId,
    this.myInviteKey,
  });

  final String email;

  /// Локальный хэш пароля (устаревший режим). Для серверной авторизации — пустая строка.
  final String passwordHash;
  final String nickname;
  final String sessionToken;
  final int? userId;

  /// Один сгенерированный пригласительный ключ, если уже создан.
  final String? myInviteKey;

  bool get isLoggedIn =>
      sessionToken.isNotEmpty && (userId != null || passwordHash.isNotEmpty);

  bool get hasMyInviteKey =>
      myInviteKey != null && myInviteKey!.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
    'email': email,
    'passwordHash': passwordHash,
    'nickname': nickname,
    'sessionToken': sessionToken,
    if (userId != null) 'userId': userId,
    if (myInviteKey != null && myInviteKey!.trim().isNotEmpty)
      'myInviteKey': myInviteKey,
  };

  static LocalAccount? fromJson(Map<String, dynamic>? map) {
    if (map == null) return null;
    final email = map['email'] as String? ?? '';
    final passwordHash = map['passwordHash'] as String? ?? '';
    final sessionToken = map['sessionToken'] as String? ?? '';
    final userId = (map['userId'] as num?)?.toInt();
    if (email.isEmpty && userId == null && passwordHash.isEmpty) return null;
    return LocalAccount(
      email: email,
      passwordHash: passwordHash,
      nickname:
          map['nickname'] as String? ??
          (email.isNotEmpty ? email.split('@').first : 'user'),
      sessionToken: sessionToken,
      userId: userId,
      myInviteKey: map['myInviteKey'] as String?,
    );
  }

  LocalAccount copyWith({
    String? email,
    String? passwordHash,
    String? nickname,
    String? sessionToken,
    int? userId,
    String? myInviteKey,
  }) {
    return LocalAccount(
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      nickname: nickname ?? this.nickname,
      sessionToken: sessionToken ?? this.sessionToken,
      userId: userId ?? this.userId,
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
          _issuedInviteKeysCache.add(InviteKeyFormat.normalize(e));
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
    final k = InviteKeyFormat.normalize(key);
    if (!InviteKeyFormat.matchesFormat(k)) return;
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
    final k = InviteKeyFormat.normalize(key);
    if (!InviteKeyFormat.matchesFormat(k)) return;
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
      final account = LocalAccount.fromJson(map);
      if (account == null) return null;
      var token = await _secureStorage.read(key: _kSecureSessionToken);
      // Migrate tokens written by older versions out of plain preferences.
      if ((token == null || token.isEmpty) && account.sessionToken.isNotEmpty) {
        token = account.sessionToken;
        await _secureStorage.write(key: _kSecureSessionToken, value: token);
        map.remove('sessionToken');
        await p.setString(_kAccount, jsonEncode(map));
      }
      if (token == null || token.isEmpty) return null;
      return account.copyWith(sessionToken: token);
    } catch (_) {
      return null;
    }
  }

  static Future<void> writeAccount(LocalAccount account) async {
    final p = await _p();
    if (account.sessionToken.isNotEmpty) {
      await _secureStorage.write(
        key: _kSecureSessionToken,
        value: account.sessionToken,
      );
    } else {
      await _secureStorage.delete(key: _kSecureSessionToken);
    }
    final data = account.toJson()..remove('sessionToken');
    await p.setString(_kAccount, jsonEncode(data));
  }

  static Future<void> clearSessionToken() async {
    final acc = await readAccount();
    await _secureStorage.delete(key: _kSecureSessionToken);
    if (acc == null) return;
    final p = await _p();
    final data = acc.toJson()..remove('sessionToken');
    await p.setString(_kAccount, jsonEncode(data));
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
