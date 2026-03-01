/// Друг, который сейчас слушает музыку.
class ListeningFriend {
  const ListeningFriend({
    required this.username,
    this.avatarUrl,
  });

  final String username;
  final String? avatarUrl;
}
