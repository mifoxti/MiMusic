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

  /// Дополнительный отступ, когда открыт полноэкранный плеер поверх shell.
  static const double shellExtraInsetWithFullPlayer = 280.0;

  /// CloudTips — поддержка проекта (кнопка в настройках).
  static const String supportProjectUrl = 'https://pay.cloudtips.ru/p/201f5bfd';

  /// Telegram-канал: обновления приложения и инструкции.
  static const String telegramUpdatesChannelUrl = 'https://t.me/evtumi';
}
