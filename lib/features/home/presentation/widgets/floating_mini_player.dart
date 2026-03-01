import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/cover_image.dart';
import '../../../../core/constants/app_constants.dart';

/// «Летающий» мини-плеер над боттом-баром: подложка с прогрессом, название трека, обложка справа.
class FloatingMiniPlayer extends StatelessWidget {
  const FloatingMiniPlayer({
    super.key,
    required this.trackTitle,
    this.coverAssetPath,
    this.trackProgress = 0.5,
    this.isPlaying = true,
    this.onTap,
  });

  final String trackTitle;
  /// Путь к обложке в assets (например assets/images/cover.png).
  final String? coverAssetPath;
  /// Прогресс трека 0.0..1.0.
  final double trackProgress;
  final bool isPlaying;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const radius = AppConstants.radiusLarge;
    const coverRadius = AppConstants.radiusMedium;
    const height = 64.0;
    const coverSize = 48.0;
    // Ярче в тёмной теме: выше alpha и более насыщенные цвета
    final progressColor = isDark
        ? palette.accent.withValues(alpha: 0.75)
        : palette.accent.withValues(alpha: 0.55);
    final progressRemainColor = isDark
        ? palette.primary.withValues(alpha: 0.5)
        : palette.primaryDark.withValues(alpha: 0.4);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: height,
            child: Stack(
              clipBehavior: Clip.antiAlias,
              children: [
                // Подложка: прогресс трека (скругления по краям для чистого левого края)
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final progress = trackProgress.clamp(0.0, 1.0);
                      return Row(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(radius),
                              bottomLeft: Radius.circular(radius),
                            ),
                            child: SizedBox(
                              width: constraints.maxWidth * progress,
                              child: Container(color: progressColor),
                            ),
                          ),
                          Expanded(
                            child: Container(color: progressRemainColor),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                // Контент: play, название, квадратная обложка справа
                // Positioned с left: -2 — перекрывает артефакт на левом крае
                Positioned(
                  left: -2,
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: palette.cardBackground.withValues(alpha: 0.98),
                      borderRadius: BorderRadius.circular(radius),
                    ),
                  child: Row(
                    children: [
                      Icon(
                        isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        size: 28,
                        color: palette.textPrimary,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          trackTitle,
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
                      // Обложка: null = заглушка; позже с сервера — URL в coverAssetPath.
                      buildCoverImage(
                        imageUrl: coverAssetPath,
                        width: coverSize,
                        height: coverSize,
                        borderRadius: BorderRadius.circular(coverRadius),
                        placeholder: Container(
                          color: palette.accent.withValues(alpha: 0.75),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.music_note_rounded,
                            color: Colors.white.withValues(alpha: 0.95),
                            size: 26,
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
    );
  }
}
