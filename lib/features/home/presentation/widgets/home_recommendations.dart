import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_glass.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/cover_image.dart';

/// Горизонтальная секция рекомендаций с заголовком.
class HomeRecommendationSection extends StatelessWidget {
  const HomeRecommendationSection({
    super.key,
    required this.title,
    required this.height,
    required this.itemCount,
    required this.itemBuilder,
    this.emptyHint,
  });

  final String title;
  final double height;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final String? emptyHint;

  @override
  Widget build(BuildContext context) {
    if (itemCount == 0 && emptyHint == null) return const SizedBox.shrink();
    final palette = AppPaletteExtension.of(context).palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        const SizedBox(height: 12),
        if (itemCount == 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              emptyHint!,
              style: TextStyle(color: palette.textMuted, fontSize: 13),
            ),
          )
        else
          SizedBox(
            height: height,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: itemCount,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: itemBuilder,
            ),
          ),
      ],
    );
  }
}

/// Трек: горизонтальная «строка» в стеклянной кapsule — обложка + текст.
class RecommendedTrackCard extends StatelessWidget {
  const RecommendedTrackCard({
    super.key,
    required this.title,
    required this.artist,
    required this.coverUrl,
    required this.onTap,
  });

  final String title;
  final String artist;
  final String? coverUrl;
  final VoidCallback onTap;

  static const _coverSize = 54.0;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _GlassTapShell(
      isDark: isDark,
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
      child: SizedBox(
        width: 220,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius:
                    BorderRadius.circular(AppConstants.radiusMedium),
                child: buildCoverImage(
                  imageUrl: coverUrl,
                  width: _coverSize,
                  height: _coverSize,
                  borderRadius:
                      BorderRadius.circular(AppConstants.radiusMedium),
                  placeholder: _coverPlaceholder(
                    palette,
                    Icons.music_note_rounded,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (artist.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.play_circle_fill_rounded,
                color: palette.accent.withValues(alpha: 0.85),
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Плейлист: квадратная обложка, название снизу.
class RecommendedPlaylistCard extends StatelessWidget {
  const RecommendedPlaylistCard({
    super.key,
    required this.title,
    required this.coverUrl,
    required this.onTap,
  });

  final String title;
  final String? coverUrl;
  final VoidCallback onTap;

  static const _size = 118.0;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: _size,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius:
                    BorderRadius.circular(AppConstants.radiusLarge),
                child: AppGlass.blurredTintLayer(
                  isDark: isDark,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppGlass.tint(isDark),
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusLarge,
                      ),
                      border: Border.all(color: AppGlass.border(isDark)),
                      boxShadow: AppGlass.cardShadows(isDark),
                    ),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          buildCoverImage(
                            imageUrl: coverUrl,
                            width: _size,
                            height: _size,
                            borderRadius: BorderRadius.circular(
                              AppConstants.radiusLarge,
                            ),
                            placeholder: _coverPlaceholder(
                              palette,
                              Icons.queue_music_rounded,
                              size: 36,
                            ),
                          ),
                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Автор: круглый аватар с кольцом, имя по центру.
class RecommendedArtistCard extends StatelessWidget {
  const RecommendedArtistCard({
    super.key,
    required this.name,
    required this.avatarUrl,
    required this.onTap,
  });

  final String name;
  final String? avatarUrl;
  final VoidCallback onTap;

  static const _avatarSize = 96.0;
  static const _cardWidth = 112.0;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: _cardWidth,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      palette.accent.withValues(alpha: 0.75),
                      palette.accent.withValues(alpha: 0.25),
                    ],
                  ),
                  boxShadow: AppGlass.cardShadows(isDark),
                ),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppGlass.tint(isDark),
                  ),
                  child: ClipOval(
                    child: buildCoverImage(
                      imageUrl: avatarUrl,
                      width: _avatarSize,
                      height: _avatarSize,
                      borderRadius: BorderRadius.circular(_avatarSize / 2),
                      placeholder: _coverPlaceholder(
                        palette,
                        Icons.person_rounded,
                        size: 40,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassTapShell extends StatelessWidget {
  const _GlassTapShell({
    required this.isDark,
    required this.onTap,
    required this.borderRadius,
    required this.child,
  });

  final bool isDark;
  final VoidCallback onTap;
  final BorderRadius borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: AppGlass.blurredTintLayer(
        isDark: isDark,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: borderRadius,
            child: Container(
              decoration: BoxDecoration(
                color: AppGlass.tint(isDark),
                borderRadius: borderRadius,
                border: Border.all(color: AppGlass.border(isDark)),
                boxShadow: AppGlass.cardShadows(isDark),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

Widget _coverPlaceholder(
  AppColorPalette palette,
  IconData icon, {
  double size = 24,
}) {
  return Container(
    color: palette.primaryDark.withValues(alpha: 0.5),
    alignment: Alignment.center,
    child: Icon(icon, color: palette.textMuted, size: size),
  );
}
