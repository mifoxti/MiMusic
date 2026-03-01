/// Трек, который сейчас слушает друг.
class FriendPlayback {
  const FriendPlayback({
    required this.title,
    required this.artistName,
    this.coverUrl,
  });

  final String title;
  final String artistName;
  final String? coverUrl;
}
