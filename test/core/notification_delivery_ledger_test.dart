import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mimusic/core/notifications/notification_delivery_ledger.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test(
    'an invite is claimed once and can be released after a display failure',
    () async {
      const key = 'notification:42';

      expect(await NotificationDeliveryLedger.claim(key), isTrue);
      expect(await NotificationDeliveryLedger.claim(key), isFalse);

      await NotificationDeliveryLedger.release(key);
      expect(await NotificationDeliveryLedger.claim(key), isTrue);
    },
  );

  test('uses a stable positive platform notification id', () {
    const key = 'invite:room-123';

    expect(NotificationDeliveryLedger.platformId(key), greaterThan(0));
    expect(
      NotificationDeliveryLedger.platformId(key),
      NotificationDeliveryLedger.platformId(key),
    );
  });
}
