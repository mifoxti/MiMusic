import 'package:flutter_test/flutter_test.dart';

import 'package:mimusic/core/auth/invite_key_format.dart';

void main() {
  group('проверка формата инвайт-ключа', () {
    test('сгенерированный ключ соответствует шаблону', () {
      final key = InviteKeyFormat.generate();
      expect(InviteKeyFormat.matchesFormat(key), isTrue);
    });

    test('normalize приводит ключ к верхнему регистру', () {
      expect(
        InviteKeyFormat.normalize('  abcd1-23456-78901  '),
        'ABCD1-23456-78901',
      );
    });

    test('неверный формат отклоняется', () {
      expect(InviteKeyFormat.matchesFormat('SHORT'), isFalse);
      expect(InviteKeyFormat.matchesFormat('AAAAA-BBBBB-CCCCC-DDDDD'), isFalse);
    });
  });
}
