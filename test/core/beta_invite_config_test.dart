import 'package:flutter_test/flutter_test.dart';

import 'package:mimusic/core/auth/beta_invite_config.dart';
import 'package:mimusic/core/auth/invite_key_format.dart';

void main() {
  test('requireInviteKey включён', () {
    expect(BetaInviteConfig.requireInviteKey, isTrue);
  });

  test('статические и пользовательские ключи проходят клиентскую проверку формата', () {
    expect(BetaInviteConfig.isValid('MIMUSIC-BETA-DEV'), isTrue);
    expect(BetaInviteConfig.isValid('TESTK-EYDEV-BUILD'), isTrue);
    expect(BetaInviteConfig.isValid(InviteKeyFormat.generate()), isTrue);
    expect(BetaInviteConfig.isValid(''), isFalse);
    expect(BetaInviteConfig.isValid('not-a-key'), isFalse);
  });
}
