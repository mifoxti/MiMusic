import 'invite_key_format.dart';

/// Ключи закрытой беты. Статические коды + пользовательские `XXXXX-XXXXX-XXXXX` (проверка в БД на сервере).
abstract final class BetaInviteConfig {
  /// Закрытая бета: ключ обязателен при регистрации (сервер: `REQUIRE_INVITE_KEY=true`).
  static const bool requireInviteKey = true;

  static const Set<String> validKeys = {
    'MIMUSIC-BETA-CLOSED-2026',
    'MIMUSIC-BETA-DEV',
    'TESTK-EYDEV-BUILD',
  };

  /// Формат и статические коды на клиенте; существование пользовательского ключа — на сервере.
  static bool isValid(String raw) {
    if (!requireInviteKey) return true;
    final k = InviteKeyFormat.normalize(raw);
    if (k.isEmpty) return false;
    if (validKeys.contains(k)) return true;
    return InviteKeyFormat.matchesFormat(k);
  }
}
