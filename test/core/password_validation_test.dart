import 'package:flutter_test/flutter_test.dart';

import 'package:mimusic/core/auth/password_hash.dart';

bool isPasswordAcceptable(String password) {
  if (password.length < 6) return false;
  if (password.length > 100) return false;
  return true;
}

void main() {
  group('проверка пароля при регистрации', () {
    test('валидный пароль: достаточная длина', () {
      expect(isPasswordAcceptable('secret12'), isTrue);
    });

    test('слишком короткий пароль', () {
      expect(isPasswordAcceptable('12345'), isFalse);
    });

    test('хэш пароля имеет фиксированную длину SHA-256', () {
      expect(hashPassword('MiMusic').length, 64);
    });

    test('verifyPassword совпадает для того же пароля', () {
      final h = hashPassword('test-pass');
      expect(verifyPassword('test-pass', h), isTrue);
      expect(verifyPassword('wrong', h), isFalse);
    });
  });
}
