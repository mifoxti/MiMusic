import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/audio/audio_player_service.dart';
import '../../core/constants/app_constants.dart';
import '../../core/l10n/app_localization.dart';
import '../../core/settings/app_settings.dart';
import '../../core/settings/settings_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/social/friend_request_notifications.dart';
import 'favorites_page.dart';
import 'friends_page.dart';
import 'notifications_page.dart';
import 'playlists_page.dart';
import 'settings_page.dart';
import 'studio_page.dart';
import 'thoughts_page.dart';
import 'open_rooms_page.dart';

/// Страница профиля: коллапсирующий header с обложкой и аватаром + "поднимающийся" bottom-sheet.
class ProfilePage extends StatelessWidget {
  const ProfilePage({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
    required this.onLanguageChanged,
    required this.settingsRepository,
    required this.initialSettings,
    required this.audioPlayerService,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;
  final ValueChanged<String> onLanguageChanged;
  final SettingsRepository settingsRepository;
  final AppSettings initialSettings;
  final AudioPlayerService audioPlayerService;

  static const String _avatarAsset = 'assets/images/identity.png';
  static const String _profileName = 'mifoxti';

  /// Пропорция фона: высота = ширина * коэффициент (обложка не растягивается).
  static const double _coverAspectRatio = 1.25;
  static const double _avatarMaxSize = 84;
  static const double _avatarMinSize = 40;

  @override
  Widget build(BuildContext context) {
    FriendRequestNotifications.instance.seedDemoIfNeeded(initialSettings.nickname);
    final palette = AppPaletteExtension.of(context).palette;
    final size = MediaQuery.sizeOf(context);
    final topPadding = MediaQuery.paddingOf(context).top;
    // Высота обложки по пропорции, но не больше ~58% экрана.
    final coverHeight = (size.width * _coverAspectRatio).clamp(260.0, size.height * 0.58);
    final expandedHeight = coverHeight + 96;
    final collapsedHeight = kToolbarHeight + topPadding + 12;
    final hasMiniPlayer = audioPlayerService.currentTrack != null;
    final bottomContentInset = hasMiniPlayer
        ? AppConstants.shellBottomInsetWithMiniPlayer
        : AppConstants.shellBottomInset;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        SliverAppBar(
          pinned: true,
          automaticallyImplyLeading: false,
          expandedHeight: expandedHeight,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          forceMaterialTransparency: true,
          flexibleSpace: LayoutBuilder(
            builder: (context, constraints) {
              final currentHeight = constraints.maxHeight;
              final t = ((currentHeight - collapsedHeight) / (expandedHeight - collapsedHeight))
                  .clamp(0.0, 1.0);
              final easedT = Curves.easeInOut.transform(t);
              final avatarSize = lerpDouble(_avatarMinSize, _avatarMaxSize, t)!;
              final titleSize = lerpDouble(18, 28, t)!;
              final alignment = Alignment.lerp(
                const Alignment(-0.9, -0.2),
                const Alignment(0, 0.7),
                t,
              )!;
              // Плавное смещение ника и скрытие кнопки \"Мысли\" при прокрутке.
              final nicknameOffsetY = lerpDouble(
                0,
                -10,
                easedT,
              )!;
              final buttonVisibility = easedT;

              return Stack(
                fit: StackFit.expand,
                children: [
                  // Обложка
                  _buildCoverBackground(context, palette, size.width, coverHeight),
                  // Градиент для плавного перехода к панели
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.35),
                          Colors.transparent,
                          palette.cardBackground.withValues(alpha: 0.98),
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                  // Кнопка настроек
                  Positioned(
                    top: topPadding + 8,
                    right: 8,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListenableBuilder(
                          listenable: FriendRequestNotifications.instance,
                          builder: (context, _) {
                            final notifications =
                                FriendRequestNotifications.instance.allFor(
                              initialSettings.nickname,
                            );
                            final pending = notifications
                                .where(
                                  (n) =>
                                      n.status == FriendRequestStatus.pending,
                                )
                                .length;
                            return IconButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (context) => NotificationsPage(
                                      currentUsername: initialSettings.nickname,
                                      audioPlayerService: audioPlayerService,
                                    ),
                                  ),
                                );
                              },
                              icon: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  const Icon(
                                    Icons.notifications_rounded,
                                    color: Colors.white,
                                  ),
                                  if (pending > 0)
                                    Positioned(
                                      right: -6,
                                      top: -6,
                                      child: Container(
                                        constraints: const BoxConstraints(
                                          minWidth: 16,
                                          minHeight: 16,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.redAccent,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          '$pending',
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
                              style: IconButton.styleFrom(
                                backgroundColor:
                                    Colors.black.withValues(alpha: 0.25),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (context) => SettingsPage(
                                  themeMode: themeMode,
                                  onThemeChanged: onThemeChanged,
                                  onLanguageChanged: onLanguageChanged,
                                  settingsRepository: settingsRepository,
                                  initialSettings: initialSettings,
                                  audioPlayerService: audioPlayerService,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.settings_rounded,
                            color: Colors.white,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black.withValues(alpha: 0.25),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Аватар + ник + кнопка "Мысли" — плавно переходят из центра вниз в левый верхний угол.
                  Align(
                    alignment: alignment,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: lerpDouble(16, 24, t)!,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          ClipOval(
                            child: SizedBox(
                              width: avatarSize,
                              height: avatarSize,
                              child: Image.asset(
                                _avatarAsset,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  color: palette.accent.withValues(alpha: 0.6),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.person_rounded,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Transform.translate(
                            offset: Offset(0, nicknameOffsetY),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _profileName,
                                  style: TextStyle(
                                    fontSize: titleSize,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: -0.3,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black.withValues(alpha: 0.4),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 8 * buttonVisibility),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  heightFactor:
                                      buttonVisibility == 0 ? 0.001 : buttonVisibility,
                                  child: Opacity(
                                    opacity: buttonVisibility,
                                    child: Material(
                                      color: Colors.white.withValues(alpha: 0.25),
                                      borderRadius: BorderRadius.circular(24),
                                      child: InkWell(
                                        onTap: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute<void>(
                                              builder: (_) => ThoughtsPage(
                                                currentUsername:
                                                    initialSettings.nickname,
                                                audioPlayerService:
                                                    audioPlayerService,
                                              ),
                                            ),
                                          );
                                        },
                                        borderRadius: BorderRadius.circular(24),
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: 8,
                                          ),
                                          child: Text(
                                            context.t('profile.thoughts'),
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        // Поднимающийся "bottom-sheet": сама панель скроллится вместе с контентом.
        SliverToBoxAdapter(
          child: Container(
            decoration: BoxDecoration(
              color: palette.cardBackground,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppConstants.radiusXLarge),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 20, 24, bottomContentInset),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildActionRow(context, palette),
                  const SizedBox(height: 24),
                  _buildStatsSection(context, palette),
                  const SizedBox(height: 20),
                  _buildSectionCard(
                    palette,
                    title: Localizations.localeOf(context).languageCode == 'en'
                        ? 'Open rooms'
                        : 'Открытые комнаты',
                    subtitle: Localizations.localeOf(context).languageCode == 'en'
                        ? 'Browse rooms and connect to live sessions'
                        : 'Список комнат и быстрое подключение',
                    icon: Icons.groups_rounded,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => OpenRoomsPage(
                            currentUsername: initialSettings.nickname,
                            audioPlayerService: audioPlayerService,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildSectionCard(
                    palette,
                    title: Localizations.localeOf(context).languageCode == 'en' ? 'Studio' : 'Студия',
                    subtitle: Localizations.localeOf(context).languageCode == 'en'
                        ? 'Create and edit albums and tracks'
                        : 'Создание и редактирование альбомов и треков',
                    icon: Icons.album_rounded,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (context) => StudioPage(currentUserNickname: initialSettings.nickname),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCoverBackground(BuildContext context, AppColorPalette palette, double width, double height) {
    return ClipRect(
      child: SizedBox(
        width: width,
        height: height,
        child: Image.asset(
          _avatarAsset,
          fit: BoxFit.cover,
          width: width,
          height: height,
          errorBuilder: (_, _, _) => Container(
            color: palette.accent.withValues(alpha: 0.5),
            alignment: Alignment.center,
            child: Icon(Icons.person_rounded, color: Colors.white, size: 64),
          ),
        ),
      ),
    );
  }

  Widget _buildActionRow(BuildContext context, AppColorPalette palette) {
    return Row(
      children: [
        Expanded(
          child: _ActionCard(
            icon: Icons.playlist_play_rounded,
            label: Localizations.localeOf(context).languageCode == 'en' ? 'Playlists' : 'Плейлисты',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => const PlaylistsPage(),
                ),
              );
            },
            palette: palette,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionCard(
            icon: Icons.people_rounded,
            label: Localizations.localeOf(context).languageCode == 'en' ? 'Friends' : 'Друзья',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => FriendsPage(
                    currentUsername: initialSettings.nickname,
                    audioPlayerService: audioPlayerService,
                  ),
                ),
              );
            },
            palette: palette,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionCard(
            icon: Icons.favorite_rounded,
            label: Localizations.localeOf(context).languageCode == 'en' ? 'Favorites' : 'Избранное',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => FavoritesPage(
                    audioPlayerService: audioPlayerService,
                  ),
                ),
              );
            },
            palette: palette,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsSection(BuildContext context, AppColorPalette palette) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: palette.primaryLight.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(value: '128', label: Localizations.localeOf(context).languageCode == 'en' ? 'tracks' : 'треков', palette: palette),
          Container(
            width: 1,
            height: 32,
            color: palette.textMuted.withValues(alpha: 0.4),
          ),
          _StatItem(value: '12', label: Localizations.localeOf(context).languageCode == 'en' ? 'playlists' : 'плейлистов', palette: palette),
          Container(
            width: 1,
            height: 32,
            color: palette.textMuted.withValues(alpha: 0.4),
          ),
          _StatItem(value: '8', label: Localizations.localeOf(context).languageCode == 'en' ? 'friends' : 'друзей', palette: palette),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
    AppColorPalette palette, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: palette.primaryLight.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: palette.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                ),
                child: Icon(icon, color: palette.accent, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: palette.textMuted, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.palette,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final AppColorPalette palette;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: palette.primaryLight.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 28, color: palette.accent),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: palette.textPrimary,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
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
