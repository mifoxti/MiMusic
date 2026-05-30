import 'package:flutter_test/flutter_test.dart';

bool isValidEmail(String? raw) {
  if (raw == null) return false;
  final s = raw.trim();
  if (s.isEmpty) return false;
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);
}

void main() {
  group('проверка формата email при регистрации', () {
    test('возвращает true для валидных email', () {
      expect(isValidEmail('user@example.com'), isTrue);
      expect(isValidEmail('test.mail@domain.ru'), isTrue);
    });

    test('возвращает false для невалидных email', () {
      expect(isValidEmail(''), isFalse);
      expect(isValidEmail('not-an-email'), isFalse);
      expect(isValidEmail('@nodomain.com'), isFalse);
    });
  });
}
