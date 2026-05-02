import 'dart:math';

/// Генерация и проверка пригласительного ключа: три группы по 5 символов (A–Z, 0–9), через дефис.
abstract final class InviteKeyFormat {
  static const _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

  static String _segment(Random r) {
    return List.generate(5, (_) => _alphabet[r.nextInt(_alphabet.length)]).join();
  }

  /// Новый случайный ключ (верхний регистр).
  static String generate() {
    final r = Random.secure();
    return '${_segment(r)}-${_segment(r)}-${_segment(r)}';
  }

  static String normalize(String raw) {
    return raw.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
  }

  /// Уже нормализованная строка без пробелов.
  static bool matchesFormat(String normalized) {
    return RegExp(r'^[A-Z0-9]{5}-[A-Z0-9]{5}-[A-Z0-9]{5}$').hasMatch(normalized);
  }

  static String randomChar(Random r) => _alphabet[r.nextInt(_alphabet.length)];
}
