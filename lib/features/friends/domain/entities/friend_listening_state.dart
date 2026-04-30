class FriendListeningState {
  const FriendListeningState({
    required this.username,
    required this.avatarUrl,
    required this.trackTitle,
    required this.trackArtist,
    this.trackCoverUrl,
  });

  final String username;
  final String avatarUrl;
  final String trackTitle;
  final String trackArtist;
  final String? trackCoverUrl;
}
