import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/settings/local_settings_repository.dart';

import '../core/audio/audio_player_service.dart';
import '../core/auth/auth_session_store.dart';
import '../core/audio/local_tracks.dart';
import '../core/history/listening_history_repository.dart';
import '../core/l10n/app_localization.dart';
import '../core/network/notifications_api.dart';
import '../core/network/playlists_api.dart';
import '../core/notifications/local_notifications_service.dart';
import '../core/notifications/notification_intent.dart';
import '../core/player/full_player_visibility.dart';
import '../core/player/player_cover_palette_service.dart';
import '../core/player/player_dock_host.dart';
import '../core/player/shell_chrome_visibility.dart';
import '../core/player/shell_route_back_guard.dart';
import '../core/player/shell_navigator_host.dart';
import '../core/social/colisten_controller.dart';
import '../core/social/listening_room_session.dart';
import '../core/settings/app_settings.dart';
import '../core/settings/settings_repository.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_glass.dart';
import '../core/theme/app_theme.dart';
import '../features/home/domain/use_cases/get_home_section_use_case.dart';
import '../features/home/presentation/pages/home_page.dart';
import '../features/playlists/domain/repositories/playlists_repository.dart';
import '../features/home/presentation/widgets/floating_mini_player.dart';
import '../features/player/presentation/widgets/expandable_player_dock.dart';
import 'pages/favorites_page.dart';
import 'pages/artist_page.dart';
import 'pages/profile_page.dart';
import 'pages/release_page.dart';
import 'pages/search_page.dart';

/// Главный shell приложения: одна активность — много фрагментов.
/// Мини-плеер и боттом-бар остаются на месте при переключении вкладок.
class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.getHomeSectionUseCase,
    required this.audioPlayerService,
    required this.playerCoverPalette,
    required this.themeMode,
    required this.onThemeChanged,
    required this.onLanguageChanged,
    required this.onShellSettingsReload,
    required this.settingsRepository,
    required this.initialSettings,
    required this.settingsDisplayGeneration,
    required this.listeningHistoryRepository,
    required this.playlistsRepository,
  });

  final GetHomeSectionUseCase getHomeSectionUseCase;
  final AudioPlayerService audioPlayerService;
  final PlayerCoverPaletteService playerCoverPalette;
  final ListeningHistoryRepository listeningHistoryRepository;
  final PlaylistsRepository playlistsRepository;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;
  final ValueChanged<String> onLanguageChanged;

  /// После сохранения настроек (профиль и т.д.) перечитать [AppSettings] в корне приложения.
  final Future<void> Function() onShellSettingsReload;
  final SettingsRepository settingsRepository;
  final AppSettings initialSettings;

  /// Меняется при перезагрузке настроек, чтобы сбросить кэш изображений с тем же путём.
  final int settingsDisplayGeneration;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  int _selectedIndex = 0;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  /// Увеличивается при переходе на вкладку «Главная», чтобы перечитать [GET /tracks].
  final ValueNotifier<int> _homeCatalogReloadToken = ValueNotifier<int>(0);

  late final AnimationController _playerDockController;
  final ShellSettingsRouteObserver _settingsRouteObserver =
      ShellSettingsRouteObserver();
  StreamSubscription<NotificationIntent>? _notificationIntentSub;
  Timer? _serverNotifPollTimer;

  /// Для setState только при смене трека / наличия трека (не при каждом тике позиции).
  bool _lastHadTrack = false;
  String _lastTrackId = '';

  /// Насколько уезжает вниз блок мини + нижняя навигация при развороте плеера.
  static const double _bottomChromeSlideDistance = 188;

  /// Становится `true` при развороте дока и сбрасывается только в [AnimationStatus.dismissed].
  /// Дополняет эвристику по [AnimationController]: до первого тика после [forward] статус
  /// может оставаться dismissed при value == 0 — без флага [FullPlayerVisibility] на кадр
  /// становится false и системный «назад» снимает маршрут под доком вместо сворачивания.
  bool _fullPlayerSessionActive = false;

  bool _isPlayerDockExpanded() {
    if (_fullPlayerSessionActive) return true;
    final c = _playerDockController;
    return c.isAnimating ||
        c.value > 0.001 ||
        c.status != AnimationStatus.dismissed;
  }

  void _onPlayerDockStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) {
      _fullPlayerSessionActive = false;
    }
    _syncFullPlayerVisibility();
  }

  void _syncFullPlayerVisibility() {
    final expanded = _isPlayerDockExpanded();
    FullPlayerVisibility.open.value = expanded;
    // Predictive back: пока оверлей развёрнут — фреймворк обрабатывает «назад»;
    // при свёрнутом мини-плеере возвращаем поведение по умолчанию.
    SystemNavigator.setFrameworkHandlesBack(expanded);
  }

  void _expandPlayerDock() {
    if (widget.audioPlayerService.currentTrack == null) return;
    if (_playerDockController.isCompleted) {
      _fullPlayerSessionActive = true;
      _syncFullPlayerVisibility();
      return;
    }
    if (_playerDockController.isAnimating) return;
    _fullPlayerSessionActive = true;
    _playerDockController.forward();
  }

  void _collapsePlayerDock() {
    _playerDockController.reverse();
  }

  @override
  void initState() {
    super.initState();
    widget.playerCoverPalette.attach(widget.audioPlayerService);
    WidgetsBinding.instance.addObserver(this);
    final initial = widget.audioPlayerService.currentTrack;
    _lastHadTrack = initial != null;
    _lastTrackId = initial?.assetPath ?? '';
    widget.audioPlayerService.addListener(_onAudioServiceChanged);
    _playerDockController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    );
    _playerDockController.addListener(_syncFullPlayerVisibility);
    _playerDockController.addStatusListener(_onPlayerDockStatus);
    PlayerDockHost.register(
      expand: _expandPlayerDock,
      collapse: _collapsePlayerDock,
    );
    ShellNavigatorHost.register(_navigatorKey);
    _notificationIntentSub = LocalNotificationsService.instance.intents.listen(
      _openNotificationIntent,
    );
    final pending = LocalNotificationsService.instance.takePendingIntent();
    if (pending != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _openNotificationIntent(pending);
      });
    }
    _syncFullPlayerVisibility();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_pollServerFriendNotifications());
      _serverNotifPollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        if (!mounted) return;
        unawaited(_pollServerFriendNotifications());
      });
    });
  }

  Future<void> _pollServerFriendNotifications() async {
    final acc = await AuthSessionStore.readAccount();
    if (acc == null || acc.sessionToken.trim().isEmpty) return;
    final userId = acc.userId;
    if (userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'mimusic_last_friend_push_notif_id_$userId';
      var lastShown = prefs.getInt(key) ?? 0;
      final list = await NotificationsApi().fetchNotifications(
        unreadOnly: true,
        limit: 30,
      );
      var maxId = lastShown;
      for (final n in list) {
        if (n.id > maxId) maxId = n.id;
      }
      for (final n in list) {
        if (n.normalizedType != 'friend_request' &&
            n.normalizedType != 'colisten_invite') {
          continue;
        }
        if (n.id <= lastShown) continue;
        final nick = n.actorNickname ?? 'MiMusic';
        final url = n.actorUserId != null
            ? userAvatarUrl(n.actorUserId!)
            : null;
        if (n.normalizedType == 'friend_request') {
          await LocalNotificationsService.instance
              .showFriendRequestNotification(
                fromUsername: nick,
                fromAvatarUrl: url,
              );
        } else if (n.normalizedType == 'colisten_invite') {
          final roomId = n.colistenRoomId;
          if (roomId == null || roomId.isEmpty) continue;
          await LocalNotificationsService.instance
              .showColistenInviteNotification(
                fromUsername: nick,
                fromAvatarUrl: url,
                roomId: roomId,
              );
        }
      }
      if (maxId > lastShown) {
        await prefs.setInt(key, maxId);
      }
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      unawaited(widget.audioPlayerService.notifyAppBackgrounded());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.audioPlayerService.removeListener(_onAudioServiceChanged);
    _playerDockController.removeListener(_syncFullPlayerVisibility);
    _playerDockController.removeStatusListener(_onPlayerDockStatus);
    _playerDockController.dispose();
    _notificationIntentSub?.cancel();
    _serverNotifPollTimer?.cancel();
    _homeCatalogReloadToken.dispose();
    PlayerDockHost.unregister();
    ShellNavigatorHost.unregister();
    ShellChromeVisibility.seeThroughOverlay.value = false;
    super.dispose();
  }

  void _openNotificationIntent(NotificationIntent intent) {
    if (_isPlayerDockExpanded()) {
      _playerDockController.reverse();
    }
    if (intent.target == NotificationTarget.release) {
      final navContext = _navigatorKey.currentContext;
      if (navContext != null) {
        Future<void> onListenTap() async {
          final tracks = await loadLocalTracks();
          if (tracks.isEmpty) return;
          final lookup = (intent.releaseTitle ?? '').toLowerCase().trim();
          final matched = tracks.where((t) {
            final title = t.title.toLowerCase();
            return title == lookup ||
                (lookup.isNotEmpty && title.contains(lookup)) ||
                (lookup.isNotEmpty && lookup.contains(title));
          }).toList();
          final queue = matched.isNotEmpty ? matched : tracks;
          await widget.audioPlayerService.playTrack(queue.first, queue: queue);
        }

        ReleasePage.show(
          navContext,
          title: intent.releaseTitle ?? 'Новый релиз',
          coverUrl: intent.releaseCoverUrl,
          artistName: intent.username,
          trackTitle: intent.releaseTitle,
          onListenTap: onListenTap,
        );
      }
      return;
    }
    if (intent.target == NotificationTarget.colistenInvite) {
      final roomId = intent.roomId?.trim();
      if (roomId == null || roomId.isEmpty) return;
      Future<void>.microtask(() async {
        try {
          final acc = await AuthSessionStore.readAccount();
          final me = (acc?.nickname.trim().isNotEmpty ?? false)
              ? acc!.nickname
              : 'me';
          ListeningRoomSession.instance.start(
            roomTitle: '@${intent.username ?? "room"}',
            listeners: [me, intent.username ?? 'host'],
            hostUsername: intent.username ?? '',
            currentUsername: me,
            privateRoom: false,
            pauseHostOnly: true,
            seekHostOnly: true,
            shuffleHostOnly: true,
            repeatHostOnly: true,
            skipHostOnly: true,
            playlistHostOnly: true,
            selectedPlaylists: const [],
            queue: const [],
          );
          await ColistenController.instance.connectGuest(
            roomId: roomId,
            audio: widget.audioPlayerService,
          );
          PlayerDockHost.expand();
        } catch (_) {}
      });
      return;
    }
    final route = switch (intent.target) {
      NotificationTarget.friendProfile => ShellMaterialPageRoute<void>(
        builder: (_) => ArtistPage(
          artistName: intent.username ?? 'Пользователь',
          coverImageUrl: intent.avatarUrl,
          audioPlayerService: widget.audioPlayerService,
        ),
      ),
      NotificationTarget.release => null,
      NotificationTarget.colistenInvite => null,
    };
    if (route == null) return;
    final pushed = ShellNavigatorHost.push(route);
    if (!pushed) {
      _navigatorKey.currentState?.push(route);
    }
  }

  /// [BackButtonListener] нельзя: нужен предок [Router] ([MaterialApp.router] и т.п.).
  /// С [MaterialApp(home:)] используем [PopScope] + [SystemNavigator.pop] при выходе.
  /// Сначала сворачивание полного плеера (оверлей поверх вложенных маршрутов), затем стек
  /// [Navigator], затем выход из приложения.
  Future<void> _handleBackSequence() async {
    if (_isPlayerDockExpanded()) {
      await _playerDockController.reverse();
      return;
    }
    final nav = _navigatorKey.currentState;
    if (nav != null && nav.canPop()) {
      nav.pop();
      return;
    }
    SystemNavigator.pop();
  }

  void _onAudioServiceChanged() {
    final track = widget.audioPlayerService.currentTrack;
    final hasTrack = track != null;
    final id = track?.assetPath ?? '';

    if (hasTrack != _lastHadTrack) {
      _lastHadTrack = hasTrack;
      _lastTrackId = id;
      if (!hasTrack && !_playerDockController.isDismissed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _playerDockController.reset();
          _syncFullPlayerVisibility();
        });
      }
      setState(() {});
      return;
    }
    if (hasTrack && id != _lastTrackId) {
      _lastTrackId = id;
      setState(() {});
    }
  }

  /// Если [WidgetsApp.didPopRoute] не обработал жест (редкий случай), дублируем логику здесь.
  @override
  Future<bool> didPopRoute() async {
    await _handleBackSequence();
    return true;
  }

  void _onPopInvokedWithResult(bool didPop, Object? result) {
    if (didPop) return;
    unawaited(_handleBackSequence());
  }

  double _dockProgressCurved() {
    final v = _playerDockController.value.clamp(0.0, 1.0);
    return Curves.easeInOutCubic.transform(v);
  }

  void _onBottomNavTap(int index) {
    final nav = _navigatorKey.currentState;
    if (nav != null) {
      nav.popUntil(
        (route) => route.settings.name == _ShellRoutes.tabs || route.isFirst,
      );
    }
    if (index == 0) {
      _homeCatalogReloadToken.value++;
    }
    if (index != _selectedIndex) {
      setState(() => _selectedIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            palette.gradientStart,
            palette.gradientMiddle,
            palette.gradientEnd,
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: PopScope(
          canPop: false,
          onPopInvokedWithResult: _onPopInvokedWithResult,
          child: SafeArea(
            top: false,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned.fill(
                  child: Column(
                    children: [
                      Expanded(
                        child: NavigatorPopHandler(
                          onPopWithResult: (_) {
                            // Единая последовательность back:
                            // 1) свернуть полный плеер, 2) pop вложенного Navigator, 3) выход.
                            unawaited(_handleBackSequence());
                          },
                          child: Navigator(
                            key: _navigatorKey,
                            observers: [_settingsRouteObserver],
                            initialRoute: _ShellRoutes.tabs,
                            onGenerateRoute: (settings) {
                              if (settings.name == _ShellRoutes.tabs) {
                                return ShellMaterialPageRoute<void>(
                                  builder: (_) => _TabsView(
                                    selectedIndex: _selectedIndex,
                                    onTabTap: (i) =>
                                        setState(() => _selectedIndex = i),
                                    homeCatalogReloadToken:
                                        _homeCatalogReloadToken,
                                    getHomeSectionUseCase:
                                        widget.getHomeSectionUseCase,
                                    audioPlayerService:
                                        widget.audioPlayerService,
                                    listeningHistoryRepository:
                                        widget.listeningHistoryRepository,
                                    playlistsRepository:
                                        widget.playlistsRepository,
                                    themeMode: widget.themeMode,
                                    onThemeChanged: widget.onThemeChanged,
                                    onLanguageChanged: widget.onLanguageChanged,
                                    onShellSettingsReload:
                                        widget.onShellSettingsReload,
                                    settingsRepository:
                                        widget.settingsRepository,
                                    initialSettings: widget.initialSettings,
                                    settingsDisplayGeneration:
                                        widget.settingsDisplayGeneration,
                                  ),
                                  settings: const RouteSettings(
                                    name: _ShellRoutes.tabs,
                                  ),
                                );
                              }
                              if (settings.name == _ShellRoutes.favorites) {
                                return ShellMaterialPageRoute<void>(
                                  builder: (_) => FavoritesPage(
                                    audioPlayerService:
                                        widget.audioPlayerService,
                                  ),
                                  settings: const RouteSettings(
                                    name: _ShellRoutes.favorites,
                                  ),
                                );
                              }
                              return null;
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned.fill(
                  child: ListenableBuilder(
                    listenable: _playerDockController,
                    builder: (context, _) {
                      final track = widget.audioPlayerService.currentTrack;
                      if (track == null) {
                        if (!_playerDockController.isDismissed) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted) return;
                            _playerDockController.reset();
                            _syncFullPlayerVisibility();
                          });
                        }
                        return Stack(
                          fit: StackFit.expand,
                          clipBehavior: Clip.none,
                          children: [
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: ValueListenableBuilder<bool>(
                                valueListenable:
                                    ShellChromeVisibility.seeThroughOverlay,
                                builder: (context, seeThrough, _) =>
                                    _BottomNavBar(
                                  seeThroughChrome: seeThrough,
                                  selectedIndex: _selectedIndex,
                                  onTap: _onBottomNavTap,
                                ),
                              ),
                            ),
                          ],
                        );
                      }

                      final dockShown = !_playerDockController.isDismissed;
                      final slide =
                          _dockProgressCurved() * _bottomChromeSlideDistance;
                      final expanded = _isPlayerDockExpanded();
                      return PopScope(
                        canPop: !expanded,
                        onPopInvokedWithResult: (didPop, _) {
                          if (didPop) return;
                          if (_isPlayerDockExpanded()) {
                            _collapsePlayerDock();
                          }
                        },
                        child: Stack(
                          fit: StackFit.expand,
                          clipBehavior: Clip.none,
                          children: [
                            if (dockShown)
                              Positioned.fill(
                                child: ExpandablePlayerDock(
                                  expandController: _playerDockController,
                                  audioPlayerService: widget.audioPlayerService,
                                  playerCoverPalette:
                                      widget.playerCoverPalette,
                                  onCollapse: _collapsePlayerDock,
                                  playlistsRepository:
                                      widget.playlistsRepository,
                                ),
                              ),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: ClipRect(
                                clipBehavior: Clip.hardEdge,
                                child: Transform.translate(
                                  offset: Offset(0, slide),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      if (_playerDockController.isDismissed)
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            12,
                                            0,
                                            12,
                                            12,
                                          ),
                                          child: ListenableBuilder(
                                            listenable: Listenable.merge([
                                              widget.audioPlayerService,
                                              ListeningRoomSession.instance,
                                            ]),
                                            builder: (context, _) {
                                              final t = widget
                                                  .audioPlayerService
                                                  .currentTrack;
                                              if (t == null) {
                                                return const SizedBox.shrink();
                                              }
                                              final dur = widget
                                                  .audioPlayerService
                                                  .duration;
                                              final pos = widget
                                                  .audioPlayerService
                                                  .position;
                                              final progress =
                                                  dur != null &&
                                                      dur.inMilliseconds > 0
                                                  ? pos.inMilliseconds /
                                                        dur.inMilliseconds
                                                  : 0.0;
                                              return ValueListenableBuilder<bool>(
                                                valueListenable:
                                                    ShellChromeVisibility
                                                        .seeThroughOverlay,
                                                builder: (context, seeThrough, _) {
                                                  return FloatingMiniPlayer(
                                                track: t,
                                                playerCoverPalette:
                                                    widget.playerCoverPalette,
                                                seeThroughChrome: seeThrough,
                                                trackProgress: progress,
                                                isPlaying: widget
                                                    .audioPlayerService
                                                    .isPlaying,
                                                collaborativeMode:
                                                    ListeningRoomSession
                                                        .instance
                                                        .active,
                                                collaborativeGuestMode:
                                                    ListeningRoomSession
                                                        .instance
                                                        .active &&
                                                    !ListeningRoomSession
                                                        .instance
                                                        .isHost,
                                                guestLocalPauseActive: widget
                                                    .audioPlayerService
                                                    .guestLocalPauseActive,
                                                onTap: _expandPlayerDock,
                                                onPlayPause:
                                                    ListeningRoomSession
                                                            .instance
                                                            .active &&
                                                        !ListeningRoomSession
                                                            .instance
                                                            .canControlPause
                                                    ? null
                                                    : () {
                                                        widget
                                                            .audioPlayerService
                                                            .togglePlayPause();
                                                      },
                                              );
                                                },
                                              );
                                            },
                                          ),
                                        ),
                                      ValueListenableBuilder<bool>(
                                        valueListenable:
                                            ShellChromeVisibility.seeThroughOverlay,
                                        builder: (context, seeThrough, _) =>
                                            _BottomNavBar(
                                          seeThroughChrome: seeThrough,
                                          selectedIndex: _selectedIndex,
                                          onTap: _onBottomNavTap,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

abstract final class _ShellRoutes {
  static const String tabs = 'tabs';
  static const String favorites = 'favorites';
}

class _TabsView extends StatelessWidget {
  const _TabsView({
    required this.selectedIndex,
    required this.onTabTap,
    required this.homeCatalogReloadToken,
    required this.getHomeSectionUseCase,
    required this.audioPlayerService,
    required this.listeningHistoryRepository,
    required this.playlistsRepository,
    required this.themeMode,
    required this.onThemeChanged,
    required this.onLanguageChanged,
    required this.onShellSettingsReload,
    required this.settingsRepository,
    required this.initialSettings,
    required this.settingsDisplayGeneration,
  });

  final int selectedIndex;
  final ValueChanged<int> onTabTap;
  final ValueNotifier<int> homeCatalogReloadToken;
  final GetHomeSectionUseCase getHomeSectionUseCase;
  final AudioPlayerService audioPlayerService;
  final ListeningHistoryRepository listeningHistoryRepository;
  final PlaylistsRepository playlistsRepository;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;
  final ValueChanged<String> onLanguageChanged;
  final Future<void> Function() onShellSettingsReload;
  final SettingsRepository settingsRepository;
  final AppSettings initialSettings;
  final int settingsDisplayGeneration;

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: selectedIndex,
      children: [
        HomePage(
          getHomeSectionUseCase: getHomeSectionUseCase,
          audioPlayerService: audioPlayerService,
          listeningHistoryRepository: listeningHistoryRepository,
          playlistsRepository: playlistsRepository,
          catalogReloadToken: homeCatalogReloadToken,
        ),
        SearchPage(
          audioPlayerService: audioPlayerService,
          playlistsRepository: playlistsRepository,
        ),
        ProfilePage(
          themeMode: themeMode,
          onThemeChanged: onThemeChanged,
          onLanguageChanged: onLanguageChanged,
          onShellSettingsReload: onShellSettingsReload,
          settingsRepository: settingsRepository,
          initialSettings: initialSettings,
          settingsDisplayGeneration: settingsDisplayGeneration,
          audioPlayerService: audioPlayerService,
          playlistsRepository: playlistsRepository,
        ),
      ],
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({
    required this.selectedIndex,
    required this.onTap,
    this.seeThroughChrome = false,
  });

  final int selectedIndex;
  final ValueChanged<int> onTap;
  final bool seeThroughChrome;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const barRadius = 36.0;
    final glassTint = AppGlass.tint(isDark);
    final borderGlass = AppGlass.border(isDark);

    // Нижний inset уже даёт внешний SafeArea у [MainShell]; второй SafeArea
    // удваивал отступ и ломал совпадение с [collapsedMiniRectInOverlay] в доке.
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(barRadius),
        clipBehavior: Clip.antiAlias,
        child: AppGlass.blurredTintLayerWithSigma(
          sigma: AppGlass.blurSigma,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(barRadius),
              border: Border.all(color: borderGlass, width: 1),
              color: seeThroughChrome ? Colors.transparent : glassTint,
              boxShadow: seeThroughChrome ? null : AppGlass.cardShadows(isDark),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _NavItem(
                    icon: Icons.music_note_rounded,
                    label: context.t('search.musicMode'),
                    isSelected: selectedIndex == 0,
                    palette: palette,
                    onTap: () => onTap(0),
                  ),
                  _NavItem(
                    icon: Icons.search_rounded,
                    label: context.t('common.search'),
                    isSelected: selectedIndex == 1,
                    palette: palette,
                    onTap: () => onTap(1),
                  ),
                  _NavItem(
                    icon: Icons.person_rounded,
                    label: context.t('settings.profile'),
                    isSelected: selectedIndex == 2,
                    palette: palette,
                    onTap: () => onTap(2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.palette,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final AppColorPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 26,
              color: isSelected ? palette.textPrimary : palette.textMuted,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? palette.textPrimary : palette.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
