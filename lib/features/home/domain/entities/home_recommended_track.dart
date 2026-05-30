/// Рекомендованный трек с сервера для главной и «Для вас».
class HomeRecommendedTrack {
  const HomeRecommendedTrack({
    required this.id,
    required this.title,
    this.artist,
    required this.coverUrl,
    this.score = 0,
  });

  final int id;
  final String title;
  final String? artist;
  final String coverUrl;
  final double score;
}
