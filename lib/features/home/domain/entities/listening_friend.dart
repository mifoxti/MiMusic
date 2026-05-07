/// Друг, который сейчас слушает музыку.
class ListeningFriend {
  const ListeningFriend({
    required this.username,
    this.avatarUrl,
    this.userId,
  });

  final String username;
  final String? avatarUrl;

  /// Если известен (поиск людей), открываем серверный профиль.
  final int? userId;
}
