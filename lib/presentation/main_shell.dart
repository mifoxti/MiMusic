import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/audio/audio_player_service.dart';
import '../core/player/full_player_visibility.dart';
import '../core/settings/app_settings.dart';
import '../core/settings/settings_repository.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../features/home/domain/use_cases/get_home_section_use_case.dart';
import '../features/home/presentation/pages/home_page.dart';
import '../features/home/presentation/widgets/floating_mini_player.dart';
import '../features/player/presentation/pages/full_player_page.dart';
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
  });

  final GetHomeSectionUseCase getHomeSectionUseCase;
  final AudioPlayerService audioPlayerService;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;
  final SettingsRepository settingsRepository;
  final AppSettings initialSettings;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final _fullPlayerRouteObserver = _FullPlayerRouteObserver();

  void _openFullPlayer(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        settings: const RouteSettings(name: FullPlayerPage.routeName),
        pageBuilder: (context, animation, secondaryAnimation) => FullPlayerPage(
          audioPlayerService: widget.audioPlayerService,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.1),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 380),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    final nav = _navigatorKey.currentState;
    if (nav != null && nav.canPop()) {
      nav.pop();
      return false;
    }
    return true;
  }

  void _onBottomNavTap(int index) {
    final nav = _navigatorKey.currentState;
    if (nav != null) {
      nav.popUntil(
        (route) =>
            route.settings.name == _ShellRoutes.tabs || route.isFirst,
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
        body: WillPopScope(
          onWillPop: _onWillPop,
          child: SafeArea(
            top: false,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned.fill(
                  child: Column(
                    children: [
                      Expanded(
                        child: Navigator(
                          key: _navigatorKey,
                          observers: [_fullPlayerRouteObserver],
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
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ClipRect(
                    clipBehavior: Clip.hardEdge,
                    child: ValueListenableBuilder<bool>(
                      valueListenable: FullPlayerVisibility.open,
                      builder: (context, fullPlayerOpen, _) {
                        return AnimatedSlide(
                          duration: _kFullPlayerChromeDuration,
                          curve: Curves.easeOutCubic,
                          offset: fullPlayerOpen
                              ? const Offset(0, 1)
                              : Offset.zero,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ListenableBuilder(
                                listenable: widget.audioPlayerService,
                                builder: (context, _) {
                                  final track =
                                      widget.audioPlayerService.currentTrack;
                                  if (track == null) {
                                    return const SizedBox.shrink();
                                  }
                                  final dur = widget.audioPlayerService.duration;
                                  final pos = widget.audioPlayerService.position;
                                  final progress =
                                      dur != null && dur.inMilliseconds > 0
                                          ? pos.inMilliseconds /
                                              dur.inMilliseconds
                                          : 0.0;
                                  return Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      12,
                                      0,
                                      12,
                                      12,
                                    ),
                                    child: FloatingMiniPlayer(
                                      track: track,
                                      trackProgress: progress,
                                      isPlaying:
                                          widget.audioPlayerService.isPlaying,
                                      onTap: () => _openFullPlayer(context),
                                      onPlayPause: () {
                                        widget.audioPlayerService
                                            .togglePlayPause();
                                      },
                                    ),
                                  );
                                },
                              ),
                              _BottomNavBar(
                                selectedIndex: _selectedIndex,
                                onTap: _onBottomNavTap,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
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

/// Как у [PageRouteBuilder] для [FullPlayerPage] — сдвиг chrome ([AnimatedSlide]) без сжатия детей и без overflow.
const Duration _kFullPlayerChromeDuration = Duration(milliseconds: 380);

/// Синхронизирует [FullPlayerVisibility] с маршрутом полного плеера (после push/pop, не во время build).
class _FullPlayerRouteObserver extends NavigatorObserver {
  bool _isFullPlayer(Route<dynamic>? route) {
    return route?.settings.name == FullPlayerPage.routeName;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_isFullPlayer(route)) {
      FullPlayerVisibility.open.value = true;
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_isFullPlayer(route)) {
      FullPlayerVisibility.open.value = false;
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_isFullPlayer(route)) {
      FullPlayerVisibility.open.value = false;
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final wasFull = _isFullPlayer(oldRoute);
    final isFull = _isFullPlayer(newRoute);
    if (wasFull || isFull) {
      FullPlayerVisibility.open.value = isFull;
    }
  }
}

class _TabsView extends StatelessWidget {
  const _TabsView({
    required this.selectedIndex,
    required this.onTabTap,
    required this.getHomeSectionUseCase,
    required this.audioPlayerService,
    required this.themeMode,
    required this.onThemeChanged,
    required this.settingsRepository,
    required this.initialSettings,
  });

  final int selectedIndex;
  final ValueChanged<int> onTabTap;
  final GetHomeSectionUseCase getHomeSectionUseCase;
  final AudioPlayerService audioPlayerService;
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
  const _BottomNavBar({
    required this.selectedIndex,
    required this.onTap,
  });

  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const barRadius = 36.0;
    // Полупрозрачное «стекло»: размытие + лёгкий тинт (как на референсе, без плотной подложки).
    final glassTint = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.34);
    final borderGlass = Colors.white.withValues(alpha: isDark ? 0.22 : 0.45);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(barRadius),
          clipBehavior: Clip.antiAlias,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(barRadius),
                border: Border.all(color: borderGlass, width: 1),
                color: glassTint,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
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
