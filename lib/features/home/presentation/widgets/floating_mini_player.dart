import 'package:flutter/material.dart';

import '../../../../core/audio/track.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/track_cover.dart';

/// «Летающий» мини-плеер над боттом-баром: подложка с прогрессом, название трека, обложка справа.
class FloatingMiniPlayer extends StatelessWidget {
  const FloatingMiniPlayer({
    super.key,
    required this.track,
    this.trackProgress = 0.5,
    this.isPlaying = true,
    this.onTap,
    this.onPlayPause,
  });

  final Track track;
  /// Прогресс трека 0.0..1.0.
  final double trackProgress;
  final bool isPlaying;
  final VoidCallback? onTap;
  final VoidCallback? onPlayPause;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const radius = AppConstants.radiusLarge;
    const coverRadius = AppConstants.radiusMedium;
    const height = 64.0;
    const coverSize = 48.0;
    // Фон плеера и прогрессия: в светлой теме — светлые пастельные розовые без серого
    final progressColor = isDark
        ? palette.accent.withValues(alpha: 0.65)
        : palette.accent;
    final progressRemainColor = isDark
        ? const Color(0xFF5C3A48)
        : const Color(0xFFE8D4DE); // светлый пастельно-розовый (светлая тема, без серого)
    final cardColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.82); // светлее, без серого оттенка
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: isDark
                  ? palette.textMuted.withValues(alpha: 0.45)
                  : palette.primaryDark.withValues(alpha: 0.7),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              height: height,
              child: Stack(
                clipBehavior: Clip.antiAlias,
                children: [
                  // Подложка: сначала фон целиком, поверх — проигранная часть со скруглением справа (без стыка двух клипов)
                  Positioned.fill(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final progress = trackProgress.clamp(0.0, 1.0);
                        final progressWidth = constraints.maxWidth * progress;
                        return Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            Container(color: progressRemainColor),
                            if (progressWidth > 0)
                              Container(
                                width: progressWidth,
                                height: double.infinity,
                                decoration: BoxDecoration(
                                  color: progressColor,
                                  borderRadius: BorderRadius.horizontal(
                                    left: const Radius.circular(radius),
                                    right: const Radius.circular(radius),
                                  ),
                                  border: Border.all(
                                    color: isDark
                                        ? palette.textMuted.withValues(alpha: 0.5)
                                        : palette.primaryDark.withValues(alpha: 0.85),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                  // Контент: play, название, квадратная обложка справа
                  Positioned(
                    left: -2,
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(radius),
                      ),
                      child: Row(
                        children: [
                          InkResponse(
                            onTap: onPlayPause ?? onTap,
                            customBorder: const CircleBorder(),
                            radius: 24,
                            child: Icon(
                              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              size: 28,
                              color: palette.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              track.title,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: palette.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Hero(
                            tag: 'mimusic_player_cover',
                            child: buildTrackCover(
                              coverSource: track.coverBytes ?? track.coverFallbackPath,
                              width: coverSize,
                              height: coverSize,
                              borderRadius: BorderRadius.circular(coverRadius),
                              placeholder: Container(
                                color: palette.accent.withValues(alpha: 0.8),
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.music_note_rounded,
                                  color: Colors.white.withValues(alpha: 0.95),
                                  size: 26,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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
