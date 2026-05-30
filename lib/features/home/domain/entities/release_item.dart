/// Элемент блока «Последние релизы».
class ReleaseItem {
  const ReleaseItem({
    required this.title,
    this.coverUrl,
    this.trackId,
    this.artist,
  });

  final String title;
  final String? coverUrl;
  /// Серверный id для воспроизведения релиза из каталога.
  final int? trackId;
  final String? artist;
}
