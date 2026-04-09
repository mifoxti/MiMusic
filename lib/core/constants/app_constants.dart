/// Глобальные константы приложения.
abstract final class AppConstants {
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 24.0;

  /// Нижний отступ контента для страниц внутри `MainShell`,
  /// когда видна только нижняя навигация.
  static const double shellBottomInset = 108.0;

  /// Нижний отступ контента для страниц внутри `MainShell`,
  /// когда поверх контента видны мини-плеер и нижняя навигация.
  static const double shellBottomInsetWithMiniPlayer = 184.0;
}
