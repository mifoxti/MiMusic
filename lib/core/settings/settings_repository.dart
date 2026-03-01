import 'app_settings.dart';

/// Репозиторий настроек. Локальная реализация — SharedPreferences;
/// позже можно заменить на сохранение на сервере/в БД.
abstract interface class SettingsRepository {
  Future<AppSettings> getSettings();
  Future<void> saveSettings(AppSettings settings);
}
