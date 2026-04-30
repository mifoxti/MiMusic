import 'package:flutter/foundation.dart';

enum FriendRequestStatus { pending, accepted, declined }

class FriendRequestNotification {
  const FriendRequestNotification({
    required this.id,
    required this.fromUsername,
    this.fromAvatarUrl,
    required this.toUsername,
    required this.createdAt,
    required this.status,
  });

  final String id;
  final String fromUsername;
  final String? fromAvatarUrl;
  final String toUsername;
  final DateTime createdAt;
  final FriendRequestStatus status;

  FriendRequestNotification copyWith({
    FriendRequestStatus? status,
  }) {
    return FriendRequestNotification(
      id: id,
      fromUsername: fromUsername,
      fromAvatarUrl: fromAvatarUrl,
      toUsername: toUsername,
      createdAt: createdAt,
      status: status ?? this.status,
    );
  }
}

/// Локальный центр уведомлений заявок в друзья (без API).
class FriendRequestNotifications extends ChangeNotifier {
  FriendRequestNotifications._();

  static final FriendRequestNotifications instance =
      FriendRequestNotifications._();

  final List<FriendRequestNotification> _items = [];
  bool _seedAdded = false;

  List<FriendRequestNotification> allFor(String username) {
    final normalized = username.trim().toLowerCase();
    final out = _items
        .where((n) => n.toUsername.toLowerCase() == normalized)
        .toList();
    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }

  List<FriendRequestNotification> latestFor(
    String username, {
    int limit = 3,
  }) {
    final all = allFor(username);
    if (all.length <= limit) return all;
    return all.take(limit).toList();
  }

  FriendRequestNotification? pendingBetween({
    required String fromUsername,
    required String toUsername,
  }) {
    final from = fromUsername.trim().toLowerCase();
    final to = toUsername.trim().toLowerCase();
    for (final n in _items) {
      if (n.fromUsername.toLowerCase() == from &&
          n.toUsername.toLowerCase() == to &&
          n.status == FriendRequestStatus.pending) {
        return n;
      }
    }
    return null;
  }

  FriendRequestNotification sendRequest({
    required String fromUsername,
    String? fromAvatarUrl,
    required String toUsername,
  }) {
    final existing = pendingBetween(
      fromUsername: fromUsername,
      toUsername: toUsername,
    );
    if (existing != null) return existing;
    final now = DateTime.now();
    final n = FriendRequestNotification(
      id: '${now.microsecondsSinceEpoch}-${fromUsername}_$toUsername',
      fromUsername: fromUsername,
      fromAvatarUrl: fromAvatarUrl,
      toUsername: toUsername,
      createdAt: now,
      status: FriendRequestStatus.pending,
    );
    _items.add(n);
    notifyListeners();
    return n;
  }

  void setStatus({
    required String notificationId,
    required FriendRequestStatus status,
  }) {
    final index = _items.indexWhere((n) => n.id == notificationId);
    if (index < 0) return;
    _items[index] = _items[index].copyWith(status: status);
    notifyListeners();
  }

  void remove(String notificationId) {
    _items.removeWhere((n) => n.id == notificationId);
    notifyListeners();
  }

  /// Чтобы кнопка уведомлений в профиле была проверяема сразу.
  void seedDemoIfNeeded(String currentUsername) {
    if (_seedAdded) return;
    _seedAdded = true;
    sendRequest(fromUsername: 'synthfox', toUsername: currentUsername);
    sendRequest(fromUsername: 'nightcore_anna', toUsername: currentUsername);
  }
}
