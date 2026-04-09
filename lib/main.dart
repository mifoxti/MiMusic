import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/audio/audio_player_service.dart';
import 'core/audio/mimusic_audio_handler.dart';
import 'core/history/in_memory_listening_history_repository.dart';
import 'core/history/listening_history_repository.dart';
import 'core/settings/app_settings.dart';
import 'core/settings/local_settings_repository.dart';
import 'core/settings/settings_repository.dart';
import 'core/theme/app_theme.dart';
import 'features/home/data/repositories/home_repository_impl.dart';
import 'features/home/domain/use_cases/get_home_section_use_case.dart';
import 'presentation/main_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const _SettingsLoader());
}

/// Загружает настройки и инициализирует AudioService, затем строит приложение.
class _SettingsLoader extends StatefulWidget {
  const _SettingsLoader();

  @override
  State<_SettingsLoader> createState() => _SettingsLoaderState();
}

class _InitResult {
  const _InitResult(
    this.settings,
    this.repository,
    this.audioHandler,
    this.listeningHistoryRepository,
  );

  final AppSettings settings;
  final SettingsRepository repository;
  final AudioHandler audioHandler;
  final ListeningHistoryRepository listeningHistoryRepository;
}

class _SettingsLoaderState extends State<_SettingsLoader> {
  late final Future<_InitResult> _initFuture = _init();

  Future<_InitResult> _init() async {
    try {
      final repository = LocalSettingsRepository();
      setMiMusicHandlerSettingsRepository(repository);
      final settings = await repository.getSettings();
      final listeningHistoryRepository = InMemoryListeningHistoryRepository();
      final handler = await AudioService.init(
        builder: () => MiMusicAudioHandler(),
      config: AudioServiceConfig(
        androidNotificationChannelId: 'com.example.mimusic.audio',
        androidNotificationChannelName: 'Воспроизведение',
        androidStopForegroundOnPause: false,
      ),
      );
      setListeningHistoryRepository(listeningHistoryRepository);
      return _InitResult(settings, repository, handler, listeningHistoryRepository);
    } catch (e, st) {
      debugPrint('Init error: $e');
      debugPrint('Stack trace: $st');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_InitResult>(
      future: _initFuture,
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
        final result = snapshot.data;
        final error = snapshot.error;
        if (result == null) {
          return MaterialApp(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            home: Scaffold(
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Ошибка инициализации',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          '$error',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        return MiMusicApp(
          initialSettings: result.settings,
          settingsRepository: result.repository,
          audioHandler: result.audioHandler,
          listeningHistoryRepository: result.listeningHistoryRepository,
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
    required this.audioHandler,
    required this.listeningHistoryRepository,
  });

  final AppSettings initialSettings;
  final SettingsRepository settingsRepository;
  final AudioHandler audioHandler;
  final ListeningHistoryRepository listeningHistoryRepository;

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
      audioHandler: widget.audioHandler,
      settingsRepository: widget.settingsRepository,
    );
    _getHomeSectionUseCase = GetHomeSectionUseCase(HomeRepositoryImpl());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_audioPlayerService.applyEqualizerFromSettings());
    });
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
        listeningHistoryRepository: widget.listeningHistoryRepository,
      ),
    );
  }
}
