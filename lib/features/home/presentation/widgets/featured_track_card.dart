import 'package:flutter/material.dart';

import '../../../../core/audio/track.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/track_cover.dart';

/// Карточка featured-трека на главной: обложка, название, автор, кнопка воспроизведения.
class FeaturedTrackCard extends StatelessWidget {
  const FeaturedTrackCard({
    super.key,
    required this.track,
    required this.isPlaying,
    required this.progress,
    required this.onTap,
  });

  final Track track;
  final bool isPlaying;
  final double progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    const coverSize = 140.0;
    const radius = AppConstants.radiusLarge;

    final coverSource = track.coverBytes ?? track.coverFallbackPath;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: palette.cardBackground.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
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
                          color: palette.accent.withValues(alpha: 0.3),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.music_note_rounded,
                            size: 48,
                            color: palette.accent,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(AppConstants.radiusMedium),
                      ),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        backgroundColor: Colors.black.withValues(alpha: 0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(palette.accent),
                        minHeight: 4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      track.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: palette.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (track.artistDisplay.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        track.artistDisplay,
                        style: TextStyle(
                          fontSize: 14,
                          color: palette.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _PlayPauseChip(
                          isPlaying: isPlaying,
                          onTap: onTap,
                          palette: palette,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayPauseChip extends StatelessWidget {
  const _PlayPauseChip({
    required this.isPlaying,
    required this.onTap,
    required this.palette,
  });

  final bool isPlaying;
  final VoidCallback onTap;
  final AppColorPalette palette;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: palette.accent.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 22,
                color: palette.accent,
              ),
              const SizedBox(width: 6),
              Text(
                isPlaying ? 'Пауза' : 'Слушать',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: palette.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
