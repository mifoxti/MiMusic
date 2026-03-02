import 'package:flutter/material.dart';

import '../../core/audio/audio_player_service.dart';
import '../../core/constants/app_constants.dart';
import '../../core/settings/app_settings.dart';
import '../../core/settings/settings_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'settings_page.dart';

/// Страница профиля: фон-обложка сверху, контент в панели с закруглённым верхом (как боттом-шит, но часть страницы).
class ProfilePage extends StatelessWidget {
  const ProfilePage({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
    required this.settingsRepository,
    required this.initialSettings,
    required this.audioPlayerService,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;
  final SettingsRepository settingsRepository;
  final AppSettings initialSettings;
  final AudioPlayerService audioPlayerService;

  static const String _avatarAsset = 'assets/images/identity.png';
  static const String _profileName = 'mifoxti';

  /// Пропорция фона: высота = ширина * коэффициент (обложка не растягивается).
  static const double _coverAspectRatio = 1.25;

  /// С какой доли экрана начинается панель (накладывается на фон).
  static const double _sheetStartFraction = 0.42;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    final size = MediaQuery.sizeOf(context);
    final topPadding = MediaQuery.paddingOf(context).top;
    // Высота фона по пропорции, но не больше ~55% экрана — картинка сохраняет соотношение сторон
    final coverHeight = (size.width * _coverAspectRatio).clamp(0.0, size.height * 0.58);
    final sheetTop = size.height * _sheetStartFraction;

    return Stack(
      children: [
        // 1. Фон — полноширинная обложка
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: coverHeight,
          child: _buildCoverBackground(context, palette, size.width, coverHeight),
        ),
        // 2. Градиент внизу фона для плавного перехода в панель
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: coverHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  palette.primaryLight.withValues(alpha: 0.3),
                  palette.cardBackground.withValues(alpha: 0.98),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),
        // 3. Имя и кнопка «Мысли» поверх фона (над панелью)
        Positioned(
          left: 24,
          right: 24,
          bottom: size.height - sheetTop + 12,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _profileName,
                style: TextStyle(
                  fontSize: 28,
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
              const SizedBox(height: 12),
              Material(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  onTap: () {},
                  borderRadius: BorderRadius.circular(24),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Text(
                      'Мысли',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // 4. Кнопка настроек в правом верхнем углу
        Positioned(
          top: topPadding + 8,
          right: 8,
          child: IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => SettingsPage(
                    themeMode: themeMode,
                    onThemeChanged: onThemeChanged,
                    settingsRepository: settingsRepository,
                    initialSettings: initialSettings,
                    audioPlayerService: audioPlayerService,
                  ),
                ),
              );
            },
            icon: Icon(Icons.settings_rounded, color: Colors.white),
            style: IconButton.styleFrom(
              backgroundColor: Colors.black.withValues(alpha: 0.25),
            ),
          ),
        ),
        // 5. Панель контента (как боттом-шит, но часть страницы)
        Positioned(
          left: 0,
          right: 0,
          top: sheetTop,
          bottom: 0,
          child: Container(
            decoration: BoxDecoration(
              color: palette.cardBackground,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppConstants.radiusXLarge)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppConstants.radiusXLarge)),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildActionRow(context, palette),
                    const SizedBox(height: 24),
                    _buildStatsSection(palette),
                    const SizedBox(height: 20),
                    _buildSectionCard(
                      palette,
                      title: 'Популярные треки',
                      subtitle: 'Треки, которые вы слушаете чаще всего',
                      icon: Icons.music_note_rounded,
                      onTap: () {},
                    ),
                    const SizedBox(height: 12),
                    _buildSectionCard(
                      palette,
                      title: 'Любимые жанры',
                      subtitle: 'Electronic, Ambient, Lo-Fi',
                      icon: Icons.library_music_rounded,
                      onTap: () {},
                    ),
                  ],
                ),
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
          errorBuilder: (_, __, ___) => Container(
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
            label: 'Плейлисты',
            onTap: () {},
            palette: palette,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionCard(
            icon: Icons.people_rounded,
            label: 'Друзья',
            onTap: () {},
            palette: palette,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionCard(
            icon: Icons.favorite_rounded,
            label: 'Избранное',
            onTap: () {},
            palette: palette,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsSection(AppColorPalette palette) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: palette.primaryLight.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(value: '128', label: 'треков', palette: palette),
          Container(
            width: 1,
            height: 32,
            color: palette.textMuted.withValues(alpha: 0.4),
          ),
          _StatItem(value: '12', label: 'плейлистов', palette: palette),
          Container(
            width: 1,
            height: 32,
            color: palette.textMuted.withValues(alpha: 0.4),
          ),
          _StatItem(value: '8', label: 'друзей', palette: palette),
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
