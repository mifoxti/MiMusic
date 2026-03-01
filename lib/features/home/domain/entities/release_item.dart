/// Элемент блока «Последние релизы».
class ReleaseItem {
  const ReleaseItem({
    required this.title,
    this.coverUrl,
  });

  final String title;
  final String? coverUrl;
}
