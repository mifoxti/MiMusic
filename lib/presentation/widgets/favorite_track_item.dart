import 'package:flutter/material.dart';

import '../../core/audio/track.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/track_cover.dart';

/// Элемент списка: обложка, название, исполнитель, кнопки избранное и «ещё».
/// Подходит для длинных списков (избранное, плейлисты, поиск).
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
    const coverSize = 56.0;
    final palette = AppPaletteExtension.of(context).palette;
    final coverSource = track.coverBytes ?? track.coverFallbackPath;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: palette.cardBackground.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
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
                        color: palette.primaryDark.withValues(alpha: 0.5),
                        child: Icon(
                          Icons.music_note_rounded,
                          color: palette.textMuted,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        track.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: palette.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isDownloaded) ...[
                        const SizedBox(height: 2),
                        Icon(
                          Icons.download_done_rounded,
                          size: 14,
                          color: palette.accent,
                        ),
                      ],
                      const SizedBox(height: 2),
                      Text(
                        track.artistDisplay.isEmpty
                            ? 'Неизвестный исполнитель'
                            : track.artistDisplay,
                        style: TextStyle(
                          fontSize: 13,
                          color: palette.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onRemoveFavorite,
                  icon: Icon(
                    Icons.favorite_rounded,
                    color: palette.accent,
                    size: 24,
                  ),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    padding: EdgeInsets.zero,
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
                    minimumSize: const Size(44, 44),
                    padding: EdgeInsets.zero,
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
