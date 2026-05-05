import 'package:flutter/material.dart';

/// Модель настроек приложения. Сериализуема для локального хранения и будущей отправки на сервер.
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.email = '',
    this.password = '',
    this.nickname = 'mifoxti',
    this.bio = '',
    this.avatarPath,
    this.equalizerGains = const [0.0, 0.0, 0.0, 0.0, 0.0],
    this.equalizerPreamp = 0.0,
    this.notificationsEnabled = true,
    this.languageCode = 'ru',
    this.cacheLimitBytes = defaultCacheLimitBytes,
  });

  /// Лимит кэша по умолчанию: 1 ГБ (сохраняется в локальных настройках).
  static const int defaultCacheLimitBytes = 1024 * 1024 * 1024;

  /// Нет лимита (∞). Раньше для этого же смысла в JSON могло быть `0` — см. [fromJson].
  static const int cacheLimitUnlimited = -1;

  final ThemeMode themeMode;
  final String email;
  /// Только для **локального** режима без серверного аккаунта (проверка пароля в профиле).
  /// При входе через API не используется для хранения секрета — сессия в [AuthSessionStore], смена пароля через [PUT /me/password].
  final String password;
  final String nickname;
  /// О себе; при входе на сервер синхронизируется с [PUT /me].
  final String bio;
  final String? avatarPath;
  final List<double> equalizerGains;
  final double equalizerPreamp;
  final bool notificationsEnabled;
  final String languageCode;

  /// Максимальный допустимый объём кэша (для отображения и будущего контроля).
  final int cacheLimitBytes;

  AppSettings copyWith({
    ThemeMode? themeMode,
    String? email,
    String? password,
    String? nickname,
    String? bio,
    String? avatarPath,
    List<double>? equalizerGains,
    double? equalizerPreamp,
    bool? notificationsEnabled,
    String? languageCode,
    int? cacheLimitBytes,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      email: email ?? this.email,
      password: password ?? this.password,
      nickname: nickname ?? this.nickname,
      bio: bio ?? this.bio,
      avatarPath: avatarPath ?? this.avatarPath,
      equalizerGains: equalizerGains ?? List.from(this.equalizerGains),
      equalizerPreamp: equalizerPreamp ?? this.equalizerPreamp,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      languageCode: languageCode ?? this.languageCode,
      cacheLimitBytes: cacheLimitBytes ?? this.cacheLimitBytes,
    );
  }

  /// Для будущей отправки на сервер / сохранения в БД.
  Map<String, dynamic> toJson() {
    return {
      'themeMode': themeMode.index,
      'email': email,
      'password': password,
      'nickname': nickname,
      'bio': bio,
      'avatarPath': avatarPath,
      'equalizerGains': equalizerGains,
      'equalizerPreamp': equalizerPreamp,
      'notificationsEnabled': notificationsEnabled,
      'languageCode': languageCode,
      'cacheLimitBytes': cacheLimitBytes,
    };
  }

  static AppSettings fromJson(Map<String, dynamic> json) {
    final gains = json['equalizerGains'];
    return AppSettings(
      themeMode: ThemeMode.values[json['themeMode'] as int? ?? ThemeMode.system.index],
      email: json['email'] as String? ?? '',
      password: json['password'] as String? ?? '',
      nickname: json['nickname'] as String? ?? 'mifoxti',
      bio: json['bio'] as String? ?? '',
      avatarPath: json['avatarPath'] as String?,
      equalizerGains: gains is List ? List<double>.from(gains.map((e) => (e as num).toDouble())) : const [0.0, 0.0, 0.0, 0.0, 0.0],
      equalizerPreamp: (json['equalizerPreamp'] as num?)?.toDouble() ?? 0.0,
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
      languageCode: json['languageCode'] as String? ?? 'ru',
      cacheLimitBytes: _cacheLimitFromJson(json['cacheLimitBytes']),
    );
  }

  static int _cacheLimitFromJson(Object? v) {
    if (v == null) return defaultCacheLimitBytes;
    return (v as num).toInt();
  }
}
