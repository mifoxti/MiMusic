import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/audio/audio_player_service.dart';
import '../core/history/listening_history_repository.dart';
import '../core/player/full_player_visibility.dart';
import '../core/player/player_dock_host.dart';
import '../core/settings/app_settings.dart';
import '../core/settings/settings_repository.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_glass.dart';
import '../core/theme/app_theme.dart';
import '../features/home/domain/use_cases/get_home_section_use_case.dart';
import '../features/home/presentation/pages/home_page.dart';
import '../features/home/presentation/widgets/floating_mini_player.dart';
import '../features/player/presentation/widgets/expandable_player_dock.dart';
import 'pages/favorites_page.dart';
import 'pages/profile_page.dart';
import 'pages/search_page.dart';

/// Главный shell приложения: одна активность — много фрагментов.
/// Мини-плеер и боттом-бар остаются на месте при переключении вкладок.
class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.getHomeSectionUseCase,
    required this.audioPlayerService,
    required this.themeMode,
    required this.onThemeChanged,
    required this.settingsRepository,
    required this.initialSettings,
    required this.listeningHistoryRepository,
  });

  final GetHomeSectionUseCase getHomeSectionUseCase;
  final AudioPlayerService audioPlayerService;
  final ListeningHistoryRepository listeningHistoryRepository;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;
  final SettingsRepository settingsRepository;
  final AppSettings initialSettings;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  int _selectedIndex = 0;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  late final AnimationController _playerDockController;

  /// Для setState только при смене трека / наличия трека (не при каждом тике позиции).
  bool _lastHadTrack = false;
  String _lastTrackId = '';

  /// Насколько уезжает вниз блок мини + нижняя навигация при развороте плеера.
  static const double _bottomChromeSlideDistance = 188;

  void _syncFullPlayerVisibility() {
    FullPlayerVisibility.open.value = !_playerDockController.isDismissed;
    // Вложенный Navigator без второго маршрута шлёт canHandlePop: false; тогда Android
    // может не передать назад во Flutter (predictive back / OnBackInvokedDispatcher).
    // Пока открыт полный плеер, явно просим доставлять событие в фреймворк.
    if (!_playerDockController.isDismissed) {
      SystemNavigator.setFrameworkHandlesBack(true);
    }
  }

  void _expandPlayerDock() {
    if (widget.audioPlayerService.currentTrack == null) return;
    if (_playerDockController.isCompleted) return;
    if (_playerDockController.isAnimating) return;
    _playerDockController.forward();
  }

  void _collapsePlayerDock() {
    _playerDockController.reverse();
  }

  @override
  void initState() {
    super.initState();
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
    PlayerDockHost.register(
      expand: _expandPlayerDock,
      collapse: _collapsePlayerDock,
    );
    _syncFullPlayerVisibility();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.audioPlayerService.removeListener(_onAudioServiceChanged);
    _playerDockController.removeListener(_syncFullPlayerVisibility);
    _playerDockController.dispose();
    PlayerDockHost.unregister();
    super.dispose();
  }

  /// [BackButtonListener] нельзя: нужен предок [Router] ([MaterialApp.router] и т.п.).
  /// С [MaterialApp(home:)] используем [PopScope] + [SystemNavigator.pop] при выходе.
  /// Сначала сворачивание полного плеера (оверлей поверх вложенных маршрутов), затем стек
  /// [Navigator], затем выход из приложения.
  Future<void> _handleBackSequence() async {
    if (!_playerDockController.isDismissed) {
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
                            _navigatorKey.currentState?.maybePop();
                          },
                          child: Navigator(
                            key: _navigatorKey,
                            initialRoute: _ShellRoutes.tabs,
                            onGenerateRoute: (settings) {
                            if (settings.name == _ShellRoutes.tabs) {
                              return MaterialPageRoute<void>(
                                builder: (_) => _TabsView(
                                  selectedIndex: _selectedIndex,
                                  onTabTap: (i) =>
                                      setState(() => _selectedIndex = i),
                                  getHomeSectionUseCase:
                                      widget.getHomeSectionUseCase,
                                  audioPlayerService: widget.audioPlayerService,
                                  listeningHistoryRepository:
                                      widget.listeningHistoryRepository,
                                  themeMode: widget.themeMode,
                                  onThemeChanged: widget.onThemeChanged,
                                  settingsRepository: widget.settingsRepository,
                                  initialSettings: widget.initialSettings,
                                ),
                                settings: const RouteSettings(
                                  name: _ShellRoutes.tabs,
                                ),
                              );
                            }
                            if (settings.name == _ShellRoutes.favorites) {
                              return MaterialPageRoute<void>(
                                builder: (_) => FavoritesPage(
                                  audioPlayerService: widget.audioPlayerService,
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
                              child: _BottomNavBar(
                                selectedIndex: _selectedIndex,
                                onTap: _onBottomNavTap,
                              ),
                            ),
                          ],
                        );
                      }

                      final dockShown = !_playerDockController.isDismissed;
                      final slide =
                          _dockProgressCurved() * _bottomChromeSlideDistance;
                      return Stack(
                        fit: StackFit.expand,
                        clipBehavior: Clip.none,
                        children: [
                          if (dockShown)
                            Positioned.fill(
                              child: ExpandablePlayerDock(
                                expandController: _playerDockController,
                                audioPlayerService: widget.audioPlayerService,
                                onCollapse: _collapsePlayerDock,
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
                                          listenable: widget.audioPlayerService,
                                          builder: (context, _) {
                                            final t = widget
                                                .audioPlayerService
                                                .currentTrack;
                                            if (t == null) {
                                              return const SizedBox.shrink();
                                            }
                                            final dur = widget
                                                .audioPlayerService.duration;
                                            final pos = widget
                                                .audioPlayerService.position;
                                            final progress =
                                                dur != null &&
                                                    dur.inMilliseconds > 0
                                                ? pos.inMilliseconds /
                                                      dur.inMilliseconds
                                                : 0.0;
                                            return FloatingMiniPlayer(
                                              track: t,
                                              trackProgress: progress,
                                              isPlaying: widget
                                                  .audioPlayerService
                                                  .isPlaying,
                                              onTap: _expandPlayerDock,
                                              onPlayPause: () {
                                                widget.audioPlayerService
                                                    .togglePlayPause();
                                              },
                                            );
                                          },
                                        ),
                                      ),
                                    _BottomNavBar(
                                      selectedIndex: _selectedIndex,
                                      onTap: _onBottomNavTap,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
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
    required this.getHomeSectionUseCase,
    required this.audioPlayerService,
    required this.listeningHistoryRepository,
    required this.themeMode,
    required this.onThemeChanged,
    required this.settingsRepository,
    required this.initialSettings,
  });

  final int selectedIndex;
  final ValueChanged<int> onTabTap;
  final GetHomeSectionUseCase getHomeSectionUseCase;
  final AudioPlayerService audioPlayerService;
  final ListeningHistoryRepository listeningHistoryRepository;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;
  final SettingsRepository settingsRepository;
  final AppSettings initialSettings;

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: selectedIndex,
      children: [
        HomePage(
          getHomeSectionUseCase: getHomeSectionUseCase,
          audioPlayerService: audioPlayerService,
          listeningHistoryRepository: listeningHistoryRepository,
        ),
        SearchPage(
          audioPlayerService: audioPlayerService,
          getHomeSectionUseCase: getHomeSectionUseCase,
        ),
        ProfilePage(
          themeMode: themeMode,
          onThemeChanged: onThemeChanged,
          settingsRepository: settingsRepository,
          initialSettings: initialSettings,
          audioPlayerService: audioPlayerService,
        ),
      ],
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({required this.selectedIndex, required this.onTap});

  final int selectedIndex;
  final ValueChanged<int> onTap;

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
        child: AppGlass.blurredTintLayer(
          isDark: isDark,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(barRadius),
              border: Border.all(color: borderGlass, width: 1),
              color: glassTint,
              boxShadow: AppGlass.cardShadows(isDark),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 12,
                horizontal: 20,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                    _NavItem(
                      icon: Icons.music_note_rounded,
                      label: 'Music',
                      isSelected: selectedIndex == 0,
                      palette: palette,
                      onTap: () => onTap(0),
                    ),
                    _NavItem(
                      icon: Icons.search_rounded,
                      label: 'Search',
                      isSelected: selectedIndex == 1,
                      palette: palette,
                      onTap: () => onTap(1),
                    ),
                    _NavItem(
                      icon: Icons.person_rounded,
                      label: 'Profile',
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
