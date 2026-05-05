import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/audio/audio_player_service.dart';
import 'core/audio/mimusic_audio_handler.dart';
import 'core/auth/auth_session_store.dart';
import 'core/profile/me_profile_cache.dart';
import 'core/network/api_config.dart';
import 'core/auth/session_scope.dart';
import 'core/history/in_memory_listening_history_repository.dart';
import 'core/history/listening_history_repository.dart';
import 'core/l10n/app_localization.dart';
import 'core/notifications/local_notifications_service.dart';
import 'core/settings/app_settings.dart';
import 'core/settings/local_settings_repository.dart';
import 'core/settings/settings_repository.dart';
import 'features/playlists/data/repositories/session_aware_playlists_repository.dart';
import 'features/playlists/domain/repositories/playlists_repository.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'features/home/data/repositories/home_repository_impl.dart';
import 'features/home/domain/use_cases/get_home_section_use_case.dart';
import 'features/onboarding/presentation/onboarding_flow.dart';
import 'presentation/main_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiConfig.ensureAndroidDevBaseUrl();
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
      await LocalNotificationsService.instance.initialize();
      final repository = LocalSettingsRepository();
      setMiMusicHandlerSettingsRepository(repository);
      final settings = await repository.getSettings();
      final listeningHistoryRepository = InMemoryListeningHistoryRepository();
      final handler = await AudioService.init(
        builder: () => MiMusicAudioHandler(),
        config: AudioServiceConfig(
          androidNotificationChannelId: 'com.example.mimusic.audio',
          androidNotificationChannelName: 'Playback',
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
                      Text(
                        AppLocalization(
                          WidgetsBinding.instance.platformDispatcher.locale,
                        ).t('init.error'),
                        style: const TextStyle(
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

enum _AppGate { loading, onboarding, auth, main }

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
  _AppGate _gate = _AppGate.loading;
  late ThemeMode _themeMode;
  late Locale _locale;
  late AppSettings _shellSettings;
  /// Сбрасывает кэш [Image] для аватара, если путь к файлу тот же, а содержимое изменилось.
  int _shellSettingsDisplayGeneration = 0;
  AudioPlayerService? _audioPlayerService;
  GetHomeSectionUseCase? _getHomeSectionUseCase;
  final PlaylistsRepository _playlistsRepository = SessionAwarePlaylistsRepository();

  @override
  void initState() {
    super.initState();
    _shellSettings = widget.initialSettings;
    _themeMode = widget.initialSettings.themeMode;
    _locale = Locale(widget.initialSettings.languageCode);
    unawaited(_bootstrapGate());
  }

  Future<void> _bootstrapGate() async {
    if (!await AuthSessionStore.isOnboardingCompleted()) {
      if (mounted) setState(() => _gate = _AppGate.onboarding);
      return;
    }
    if (!await AuthSessionStore.isLoggedIn()) {
      if (mounted) setState(() => _gate = _AppGate.auth);
      return;
    }
    await _enterMainFromPrefs();
  }

  Future<void> _enterMainFromPrefs() async {
    await AuthSessionStore.refreshIssuedInviteKeysCache();
    var s = await widget.settingsRepository.getSettings();
    final acc = await AuthSessionStore.readAccount();
    final serverSession = acc != null &&
        acc.sessionToken.trim().isNotEmpty &&
        acc.userId != null;
    if (serverSession && s.password.isNotEmpty) {
      s = s.copyWith(password: '');
      await widget.settingsRepository.saveSettings(s);
    }
    if (!mounted) return;
    setState(() {
      _shellSettings = s;
      _shellSettingsDisplayGeneration++;
      _themeMode = s.themeMode;
      _locale = Locale(s.languageCode);
    });
    _ensurePlayerServices();
    if (mounted) setState(() => _gate = _AppGate.main);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_audioPlayerService?.applyEqualizerFromSettings() ?? Future.value());
    });
  }

  void _ensurePlayerServices() {
    if (_audioPlayerService != null) return;
    _audioPlayerService = AudioPlayerService(
      audioHandler: widget.audioHandler,
      settingsRepository: widget.settingsRepository,
    );
    _getHomeSectionUseCase = GetHomeSectionUseCase(HomeRepositoryImpl());
  }

  Future<void> _onOnboardingDone() async {
    await AuthSessionStore.setOnboardingCompleted();
    if (!mounted) return;
    setState(() => _gate = _AppGate.auth);
  }

  Future<void> _onAuthenticated() async {
    await _enterMainFromPrefs();
  }

  Future<void> _onSignOut() async {
    MeProfileCache.clear();
    await AuthSessionStore.clearSessionToken();
    if (!mounted) return;
    // Сначала убираем MainShell с ListenableBuilder(audio), иначе один кадр с disposed ChangeNotifier — красный FlutterError.
    final player = _audioPlayerService;
    _audioPlayerService = null;
    _getHomeSectionUseCase = null;
    setState(() => _gate = _AppGate.auth);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      player?.dispose();
    });
  }

  @override
  void dispose() {
    _audioPlayerService?.dispose();
    super.dispose();
  }

  Future<void> _onThemeChanged(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    final current = await widget.settingsRepository.getSettings();
    await widget.settingsRepository.saveSettings(current.copyWith(themeMode: mode));
    final s = await widget.settingsRepository.getSettings();
    if (mounted) setState(() => _shellSettings = s);
  }

  Future<void> _onLanguageChanged(String languageCode) async {
    setState(() => _locale = Locale(languageCode));
    final current = await widget.settingsRepository.getSettings();
    await widget.settingsRepository.saveSettings(
      current.copyWith(languageCode: languageCode),
    );
    final s = await widget.settingsRepository.getSettings();
    if (mounted) setState(() => _shellSettings = s);
  }

  Future<void> _reloadShellSettingsFromRepository() async {
    final s = await widget.settingsRepository.getSettings();
    if (!mounted) return;
    setState(() {
      _shellSettings = s;
      _shellSettingsDisplayGeneration++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppLocalization(_locale).t('app.title'),
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _themeMode,
      locale: _locale,
      supportedLocales: AppLocalization.supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      debugShowCheckedModeBanner: false,
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    switch (_gate) {
      case _AppGate.loading:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      case _AppGate.onboarding:
        return OnboardingFlow(onCompleted: _onOnboardingDone);
      case _AppGate.auth:
        return AuthGate(
          settingsRepository: widget.settingsRepository,
          initialSettings: _shellSettings,
          onAuthenticated: _onAuthenticated,
        );
      case _AppGate.main:
        final audio = _audioPlayerService!;
        final homeCase = _getHomeSectionUseCase!;
        return SessionScope(
          onSignOut: _onSignOut,
          child: MainShell(
            getHomeSectionUseCase: homeCase,
            audioPlayerService: audio,
            themeMode: _themeMode,
            onThemeChanged: _onThemeChanged,
            onLanguageChanged: _onLanguageChanged,
            onShellSettingsReload: _reloadShellSettingsFromRepository,
            settingsRepository: widget.settingsRepository,
            initialSettings: _shellSettings,
            settingsDisplayGeneration: _shellSettingsDisplayGeneration,
            listeningHistoryRepository: widget.listeningHistoryRepository,
            playlistsRepository: _playlistsRepository,
          ),
        );
    }
  }
}
