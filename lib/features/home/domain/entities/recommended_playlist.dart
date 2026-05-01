class RecommendedPlaylist {
  const RecommendedPlaylist({
    required this.id,
    required this.title,
    this.coverUrl,
  });

  final String id;
  final String title;
  final String? coverUrl;
}
