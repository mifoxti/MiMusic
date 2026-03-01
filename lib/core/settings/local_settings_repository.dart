import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'app_settings.dart';
import 'settings_repository.dart';

const String _keySettings = 'mimusic_settings';

/// Локальное хранение настроек через SharedPreferences.
/// Для перехода на сервер/БД — реализовать другой [SettingsRepository],
/// сохраняющий/загружающий через API.
class LocalSettingsRepository implements SettingsRepository {
  LocalSettingsRepository([SharedPreferences? prefs]) : _prefs = prefs;

  SharedPreferences? _prefs;
  Future<SharedPreferences> get _instance async =>
      _prefs ??= await SharedPreferences.getInstance();

  @override
  Future<AppSettings> getSettings() async {
    final prefs = await _instance;
    final jsonStr = prefs.getString(_keySettings);
    if (jsonStr == null || jsonStr.isEmpty) return const AppSettings();
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return AppSettings.fromJson(map);
    } catch (_) {
      return const AppSettings();
    }
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    final prefs = await _instance;
    await prefs.setString(_keySettings, jsonEncode(settings.toJson()));
  }
}
