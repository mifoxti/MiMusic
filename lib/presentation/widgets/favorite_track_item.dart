import 'package:flutter/material.dart';

import '../../core/audio/track.dart';
import '../../core/constants/app_constants.dart';
import '../../core/l10n/app_localization.dart';
import '../../core/theme/app_glass.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/track_cover.dart';

/// Строка избранного: стеклянная карточка в стиле блока «треки на сервере» на главной.
class FavoriteTrackItem extends StatelessWidget {
  const FavoriteTrackItem({
    super.key,
    required this.track,
    required this.onTap,
    required this.onRemoveFavorite,
    this.isDownloaded = false,
    this.onMore,
  });

  final Track track;
  final VoidCallback onTap;
  final VoidCallback onRemoveFavorite;
  final bool isDownloaded;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    const coverSize = 44.0;
    final palette = AppPaletteExtension.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final coverSource = track.coverBytes ?? track.coverFallbackPath;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        child: AppGlass.blurredTintLayer(
          isDark: isDark,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppGlass.tint(isDark),
                  borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
                  border: Border.all(color: AppGlass.border(isDark)),
                  boxShadow: AppGlass.cardShadows(isDark),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                      child: SizedBox(
                        width: coverSize,
                        height: coverSize,
                        child: buildTrackCover(
                          coverSource: coverSource,
                          width: coverSize,
                          height: coverSize,
                          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                          placeholder: Container(
                            color: palette.primaryDark.withValues(alpha: 0.45),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.music_note_rounded,
                              color: palette.textMuted,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: palette.textPrimary,
                            ),
                          ),
                          Text(
                            track.artistDisplay.isEmpty
                                ? context.t('common.unknownArtist')
                                : track.artistDisplay,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: palette.textSecondary,
                            ),
                          ),
                          if (isDownloaded)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Icon(
                                Icons.download_done_rounded,
                                size: 14,
                                color: palette.accent,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.play_circle_outline_rounded,
                      color: palette.accent,
                      size: 28,
                    ),
                    IconButton(
                      onPressed: onRemoveFavorite,
                      icon: Icon(
                        Icons.favorite_rounded,
                        color: palette.accent,
                        size: 22,
                      ),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(40, 40),
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    IconButton(
                      onPressed: onMore ?? () {},
                      icon: Icon(
                        Icons.more_vert_rounded,
                        color: palette.textMuted,
                        size: 22,
                      ),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(40, 40),
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
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
