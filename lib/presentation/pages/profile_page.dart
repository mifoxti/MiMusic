import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/audio/audio_player_service.dart';
import '../../core/auth/auth_session_store.dart';
import '../../core/constants/server_avatar_constants.dart';
import '../../core/network/profile_api.dart';
import '../../core/network/server_connectivity.dart';
import '../../core/profile/me_profile_avatar_disk.dart';
import '../../core/profile/me_profile_cache.dart';
import '../../features/playlists/domain/repositories/playlists_repository.dart';
import '../../core/l10n/app_localization.dart';
import '../../core/settings/app_settings.dart';
import '../../core/settings/settings_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/notifications_api.dart';
import '../../core/platform/platform.dart';
import '../../core/player/shell_route_back_guard.dart';
import '../widgets/collapsing_profile_shell.dart';
import '../widgets/glass_panel.dart';
import '../widgets/server_me_avatar.dart';
import '../widgets/user_avatar.dart';
import 'genre_preferences_page.dart';
import 'favorites_page.dart';
import 'friends_page.dart';
import 'notifications_page.dart';
import 'playlists_page.dart';
import 'settings_page.dart';
import 'my_albums_page.dart';
import 'studio_page.dart';
import 'thoughts_page.dart';
import 'open_rooms_page.dart';
import 'saved_page.dart';

/// Страница профиля: коллапсирующий header с обложкой и аватаром + "поднимающийся" bottom-sheet.
class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
    required this.onLanguageChanged,
    required this.onShellSettingsReload,
    required this.settingsRepository,
    required this.initialSettings,
    required this.settingsDisplayGeneration,
    required this.audioPlayerService,
    required this.playlistsRepository,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;
  final ValueChanged<String> onLanguageChanged;
  final Future<void> Function() onShellSettingsReload;
  final SettingsRepository settingsRepository;
  final AppSettings initialSettings;
  /// Синхронизирован с [MiMusicApp] после сохранения настроек; сбрасывает кэш картинок.
  final int settingsDisplayGeneration;
  final AudioPlayerService audioPlayerService;
  final PlaylistsRepository playlistsRepository;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? _serverNickname;
  String? _avatarPathOverride;
  int? _tracksStat;
  int? _playlistsStat;
  int? _friendsStat;
  bool _statsLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_primeFromCacheAndSync());
      unawaited(_loadStats());
    });
  }

  /// Сначала кэш (быстрый UI), затем сеть; [setState] только если данные изменились.
  Future<void> _refreshProfileFromUser() async {
    if (!mounted) return;
    if (!await ServerConnectivity.instance.guardUserNetworkAction(context)) {
      return;
    }
    await _primeFromCacheAndSync(showOfflineSheet: true);
    await _loadStats(showOfflineSheet: true);
  }

  Future<void> _primeFromCacheAndSync({bool showOfflineSheet = false}) async {
    final acc = await AuthSessionStore.readAccount();
    if (acc == null || acc.sessionToken.trim().isEmpty || acc.userId == null) return;
    final uid = acc.userId!;

    final cached = await MeProfileCache.loadForUser(uid);
    if (cached != null && mounted) {
      setState(() {
        if (cached.nickname.trim().isNotEmpty) {
          _serverNickname = cached.nickname;
        }
        _avatarPathOverride =
            cached.hasServerAvatar ? kServerMeAvatarMarker : null;
      });
    }

    if (!mounted) return;
    final me = await ServerConnectivity.instance.runOnline(
      context,
      () => ProfileApi().fetchMe(),
      showOfflineSheet: showOfflineSheet,
    );
    if (me == null || !mounted) return;
    final unchanged = cached != null && cached.matches(me);
    await MeProfileCache.save(uid, me);
    if (unchanged) return;
    setState(() {
      if (me.nickname.trim().isNotEmpty) {
        _serverNickname = me.nickname;
      }
      if (me.avatarStorageKey != null && me.avatarStorageKey!.trim().isNotEmpty) {
        _avatarPathOverride = kServerMeAvatarMarker;
      } else {
        _avatarPathOverride = null;
        unawaited(MeProfileAvatarDisk.clear());
      }
    });
  }

  Future<void> _loadStats({bool showOfflineSheet = false}) async {
    final acc = await AuthSessionStore.readAccount();
    if (acc == null || acc.sessionToken.trim().isEmpty) {
      if (mounted) setState(() => _statsLoading = false);
      return;
    }
    if (!mounted) return;
    final stats = await ServerConnectivity.instance.runOnline(
      context,
      () => ProfileApi().fetchMeStats(),
      showOfflineSheet: showOfflineSheet,
    );
    if (!mounted) return;
    if (stats != null) {
      setState(() {
        _tracksStat = stats.tracksCount;
        _playlistsStat = stats.playlistsCount;
        _friendsStat = stats.friendsCount;
        _statsLoading = false;
      });
    } else {
      setState(() => _statsLoading = false);
    }
  }

  String get _profileNickname =>
      (_serverNickname != null && _serverNickname!.trim().isNotEmpty)
          ? _serverNickname!
          : widget.initialSettings.nickname;

  String? get _profileAvatarPath => _avatarPathOverride ?? widget.initialSettings.avatarPath;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    final isEn = Localizations.localeOf(context).languageCode == 'en';

    return CollapsingProfileShell(
      title: _profileNickname,
      audioPlayerService: widget.audioPlayerService,
      onRefresh: _refreshProfileFromUser,
      cover: LayoutBuilder(
        builder: (context, constraints) => _buildCoverBackground(
          context,
          palette,
          constraints.maxWidth,
          constraints.maxHeight,
        ),
      ),
      avatar: LayoutBuilder(
        builder: (context, constraints) {
          final side = constraints.biggest.shortestSide;
          return UserAvatar(
            key: ValueKey(
              'profile-avatar-${_profileAvatarPath ?? ''}-${widget.settingsDisplayGeneration}',
            ),
            avatarPath: _profileAvatarPath,
            size: side,
            palette: palette,
            serverAvatarCacheRevision: widget.settingsDisplayGeneration,
          );
        },
      ),
      trailingActions: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ProfileNotificationBell(
            audioPlayerService: widget.audioPlayerService,
            profileNickname: _profileNickname,
          ),
          const SizedBox(width: 4),
          GlassIconButton(
            icon: Icons.settings_rounded,
            onPressed: () async {
              await Navigator.of(context).push<void>(
                ShellMaterialPageRoute<void>(
                  builder: (context) => SettingsPage(
                    themeMode: widget.themeMode,
                    onThemeChanged: widget.onThemeChanged,
                    onLanguageChanged: widget.onLanguageChanged,
                    settingsRepository: widget.settingsRepository,
                    initialSettings: widget.initialSettings,
                    audioPlayerService: widget.audioPlayerService,
                  ),
                ),
              );
              if (!context.mounted) return;
              await widget.onShellSettingsReload();
            },
          ),
        ],
      ),
      headerActions: GlassPillButton(
        label: context.t('profile.thoughts'),
        onTap: () {
          Navigator.of(context).push(
            ShellMaterialPageRoute<void>(
              builder: (_) => ThoughtsPage(
                currentUsername: _profileNickname,
                audioPlayerService: widget.audioPlayerService,
              ),
            ),
          );
        },
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildActionRow(context, palette),
          const SizedBox(height: 24),
          _buildStatsSection(context, palette),
          const SizedBox(height: 20),
          GlassTapCard(
            title: isEn ? 'Open rooms' : 'Открытые комнаты',
            subtitle: isEn
                ? 'Browse rooms and connect to live sessions'
                : 'Список комнат и быстрое подключение',
            icon: Icons.groups_rounded,
            onTap: () {
              Navigator.of(context).push(
                ShellMaterialPageRoute<void>(
                  builder: (_) => OpenRoomsPage(
                    currentUsername: _profileNickname,
                    audioPlayerService: widget.audioPlayerService,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          GlassTapCard(
            title: context.t('albums.myTitle'),
            subtitle: isEn ? 'Albums on the server' : 'Альбомы на сервере',
            icon: Icons.library_music_rounded,
            onTap: () {
              Navigator.of(context).push(
                ShellMaterialPageRoute<void>(
                  builder: (_) => MyAlbumsPage(
                    audioPlayerService: widget.audioPlayerService,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          GlassTapCard(
            title: isEn ? 'Studio' : 'Студия',
            subtitle: isEn
                ? 'Create and edit albums and tracks'
                : 'Создание и редактирование альбомов и треков',
            icon: Icons.album_rounded,
            onTap: () {
              Navigator.of(context).push(
                ShellMaterialPageRoute<void>(
                  builder: (context) => StudioPage(
                    currentUserNickname: _profileNickname,
                    audioPlayerService: widget.audioPlayerService,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          GlassTapCard(
            title: context.t('profile.genrePrefs'),
            subtitle: context.t('profile.genrePrefsSub'),
            icon: Icons.tune_rounded,
            onTap: () {
              Navigator.of(context).push(
                ShellMaterialPageRoute<void>(
                  builder: (_) => const GenrePreferencesPage(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCoverBackground(BuildContext context, AppColorPalette palette, double width, double height) {
    final raw = _profileAvatarPath?.trim();
    final resolved = (raw != null && raw.isNotEmpty) ? raw : kDefaultUserAvatarAsset;
    final placeholder = Container(
      width: width,
      height: height,
      color: palette.accent.withValues(alpha: 0.5),
      alignment: Alignment.center,
      child: const Icon(Icons.person_rounded, color: Colors.white, size: 64),
    );

    if (resolved == kServerMeAvatarMarker) {
      return ClipRect(
        key: ValueKey('profile-cover-server-${widget.settingsDisplayGeneration}'),
        child: SizedBox(
          width: width,
          height: height,
          child: ServerMeAvatar(
            clipCircle: false,
            size: width,
            boxWidth: width,
            boxHeight: height,
            palette: palette,
            cacheRevision: widget.settingsDisplayGeneration,
          ),
        ),
      );
    }

    final Widget image;
    if (resolved.startsWith('assets/')) {
      image = Image.asset(
        resolved,
        fit: BoxFit.cover,
        width: width,
        height: height,
        errorBuilder: (_, _, _) => placeholder,
      );
    } else {
      image = buildCoverImageFromFile(
        resolved,
        width,
        height,
        BorderRadius.zero,
        placeholder,
        BoxFit.cover,
      );
    }

    return ClipRect(
      key: ValueKey(
        'profile-cover-${resolved.hashCode}-${widget.settingsDisplayGeneration}',
      ),
      child: SizedBox(width: width, height: height, child: image),
    );
  }

  Widget _buildActionRow(BuildContext context, AppColorPalette palette) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassHeroAction(
          title: isEn ? 'Favorites' : 'Избранное',
          subtitle: context.t('favorites.header'),
          icon: Icons.favorite_rounded,
          iconColor: palette.accent,
          onTap: () {
            Navigator.of(context).push(
              ShellMaterialPageRoute<void>(
                builder: (context) => FavoritesPage(
                  audioPlayerService: widget.audioPlayerService,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: GlassCompactAction(
                icon: Icons.playlist_play_rounded,
                label: isEn ? 'Playlists' : 'Плейлисты',
                onTap: () {
                  Navigator.of(context).push(
                    ShellMaterialPageRoute<void>(
                      builder: (context) => PlaylistsPage(
                        audioPlayerService: widget.audioPlayerService,
                        repository: widget.playlistsRepository,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GlassCompactAction(
                icon: Icons.people_rounded,
                label: isEn ? 'Friends' : 'Друзья',
                onTap: () {
                  Navigator.of(context).push(
                    ShellMaterialPageRoute<void>(
                      builder: (_) => FriendsPage(
                        currentUsername: _profileNickname,
                        audioPlayerService: widget.audioPlayerService,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GlassCompactAction(
          icon: Icons.download_rounded,
          label: context.t('profile.saved'),
          onTap: () {
            Navigator.of(context).push(
              ShellMaterialPageRoute<void>(
                builder: (_) => SavedPage(
                  audioPlayerService: widget.audioPlayerService,
                  offlineDownloads: widget.audioPlayerService.offlineDownloads,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatsSection(BuildContext context, AppColorPalette palette) {
    String fmt(int? v) {
      if (_statsLoading) return '…';
      return '${v ?? 0}';
    }
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            value: fmt(_tracksStat),
            label: isEn ? 'tracks' : 'треков',
            palette: palette,
          ),
          Container(
            width: 1,
            height: 32,
            color: palette.textMuted.withValues(alpha: 0.4),
          ),
          _StatItem(
            value: fmt(_playlistsStat),
            label: isEn ? 'playlists' : 'плейлистов',
            palette: palette,
          ),
          Container(
            width: 1,
            height: 32,
            color: palette.textMuted.withValues(alpha: 0.4),
          ),
          _StatItem(
            value: fmt(_friendsStat),
            label: isEn ? 'friends' : 'друзей',
            palette: palette,
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.value,
    required this.label,
    required this.palette,
  });

  final String value;
  final String label;
  final AppColorPalette palette;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: palette.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: palette.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _ProfileNotificationBell extends StatefulWidget {
  const _ProfileNotificationBell({
    required this.audioPlayerService,
    required this.profileNickname,
  });

  final AudioPlayerService audioPlayerService;
  final String profileNickname;

  @override
  State<_ProfileNotificationBell> createState() => _ProfileNotificationBellState();
}

class _ProfileNotificationBellState extends State<_ProfileNotificationBell> {
  int _unread = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
    _timer = Timer.periodic(const Duration(seconds: 35), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    final acc = await AuthSessionStore.readAccount();
    if (acc == null || acc.sessionToken.trim().isEmpty) {
      if (mounted) setState(() => _unread = 0);
      return;
    }
    try {
      final c = await NotificationsApi().fetchUnreadCount();
      if (mounted) setState(() => _unread = c);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return GlassIconButton(
      icon: Icons.notifications_rounded,
      onPressed: () async {
        await Navigator.of(context).push<void>(
          ShellMaterialPageRoute<void>(
            builder: (context) => NotificationsPage(
              currentUsername: widget.profileNickname,
              audioPlayerService: widget.audioPlayerService,
              onUnreadChanged: _refresh,
            ),
          ),
        );
        if (mounted) await _refresh();
      },
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          const Icon(Icons.notifications_rounded, color: Colors.white, size: 22),
          if (_unread > 0)
            Positioned(
              right: -6,
              top: -6,
              child: Container(
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  _unread > 99 ? '99+' : '$_unread',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
