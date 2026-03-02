import 'package:flutter/material.dart';

import 'core/audio/audio_player_service.dart';
import 'core/settings/app_settings.dart';
import 'core/settings/local_settings_repository.dart';
import 'core/settings/settings_repository.dart';
import 'core/theme/app_theme.dart';
import 'features/home/data/repositories/home_repository_impl.dart';
import 'features/home/domain/use_cases/get_home_section_use_case.dart';
import 'presentation/main_shell.dart';

void main() {
  runApp(const _SettingsLoader());
}

/// Загружает настройки локально, затем строит приложение. Позже источник можно заменить на сервер.
class _SettingsLoader extends StatefulWidget {
  const _SettingsLoader();

  @override
  State<_SettingsLoader> createState() => _SettingsLoaderState();
}

class _SettingsLoaderState extends State<_SettingsLoader> {
  late final Future<AppSettings> _settingsFuture =
      LocalSettingsRepository().getSettings();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppSettings>(
      future: _settingsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return MaterialApp(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: ThemeMode.system,
            debugShowCheckedModeBanner: false,
            home: const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        final settings = snapshot.data ?? const AppSettings();
        final repository = LocalSettingsRepository();
        return MiMusicApp(
          initialSettings: settings,
          settingsRepository: repository,
        );
      },
    );
  }
}

class MiMusicApp extends StatefulWidget {
  const MiMusicApp({
    super.key,
    required this.initialSettings,
    required this.settingsRepository,
  });

  final AppSettings initialSettings;
  final SettingsRepository settingsRepository;

  @override
  State<MiMusicApp> createState() => _MiMusicAppState();
}

class _MiMusicAppState extends State<MiMusicApp> {
  late ThemeMode _themeMode;
  late final AudioPlayerService _audioPlayerService;
  late final GetHomeSectionUseCase _getHomeSectionUseCase;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.initialSettings.themeMode;
    _audioPlayerService = AudioPlayerService(
      settingsRepository: widget.settingsRepository,
    );
    _getHomeSectionUseCase = GetHomeSectionUseCase(HomeRepositoryImpl());
  }

  @override
  void dispose() {
    _audioPlayerService.dispose();
    super.dispose();
  }

  Future<void> _onThemeChanged(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    final current = await widget.settingsRepository.getSettings();
    await widget.settingsRepository.saveSettings(current.copyWith(themeMode: mode));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MiMusic',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _themeMode,
      debugShowCheckedModeBanner: false,
      home: MainShell(
        getHomeSectionUseCase: _getHomeSectionUseCase,
        audioPlayerService: _audioPlayerService,
        themeMode: _themeMode,
        onThemeChanged: _onThemeChanged,
        settingsRepository: widget.settingsRepository,
        initialSettings: widget.initialSettings,
      ),
    );
  }
}
