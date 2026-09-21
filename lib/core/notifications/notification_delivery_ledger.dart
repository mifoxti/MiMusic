import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

/// Shared identity for push and polling delivery, bounded across app restarts.
class NotificationDeliveryLedger {
  static const _key = 'mimusic_delivered_notification_ids_v1';
  static Future<void> _tail = Future<void>.value();

  static Future<bool> claim(String id) {
    final result = Completer<bool>();
    _tail = _tail.catchError((_) {}).then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.reload();
        final ids = prefs.getStringList(_key) ?? <String>[];
        if (ids.contains(id)) {
          result.complete(false);
          return;
        }
        ids.add(id);
        if (ids.length > 256) ids.removeRange(0, ids.length - 256);
        await prefs.setStringList(_key, ids);
        result.complete(true);
      } catch (error, stack) {
        result.completeError(error, stack);
      }
    });
    return result.future;
  }

  static Future<void> release(String id) {
    final result = Completer<void>();
    _tail = _tail.catchError((_) {}).then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.reload();
        final ids = prefs.getStringList(_key) ?? <String>[];
        ids.remove(id);
        await prefs.setStringList(_key, ids);
        result.complete();
      } catch (error, stack) {
        result.completeError(error, stack);
      }
    });
    return result.future;
  }

  static String inviteKey({required String roomId, int? notificationId}) =>
      notificationId == null
      ? 'invite:$roomId'
      : 'notification:$notificationId';

  /// A stable positive Android notification id (String.hashCode is not persisted).
  static int platformId(String key) {
    var hash = 2166136261;
    for (final byte in key.codeUnits) {
      hash = ((hash ^ byte) * 16777619) & 0x7fffffff;
    }
    return hash;
  }
}
