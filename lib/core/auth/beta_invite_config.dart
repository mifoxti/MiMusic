/// Ключи закрытой беты. Замените/дополните список перед сборкой для тестеров.
abstract final class BetaInviteConfig {
  /// Временно `false` — регистрация без проверки ключа. Включи перед закрытой бетой.
  static const bool requireInviteKey = false;

  static const Set<String> validKeys = {
    'MIMUSIC-BETA-CLOSED-2026',
    'MIMUSIC-BETA-DEV',
  };

  static bool isValid(String raw) {
    if (!requireInviteKey) return true;
    final k = raw.trim();
    if (k.isEmpty) return false;
    return validKeys.contains(k);
  }
}
