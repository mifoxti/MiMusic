import 'package:flutter/material.dart';

import '../../../../core/audio/track.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/player/player_corner_gradient.dart';
import '../../../../core/player/player_cover_palette_service.dart';
import '../../../../core/player/player_glass_shell.dart';
import '../../../../core/theme/app_glass.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/track_cover.dart';

/// Внутренности мини-плеера (прогресс + ряд) без внешнего стекла — для морфинга в доке.
class MiniPlayerInterior extends StatelessWidget {
  const MiniPlayerInterior({
    super.key,
    required this.track,
    this.playerCoverPalette,
    this.trackProgress = 0.5,
    this.isPlaying = true,
    this.collaborativeMode = false,
    this.collaborativeGuestMode = false,
    this.guestLocalPauseActive = false,
    this.onTap,
    this.onPlayPause,
  });

  final Track track;
  final PlayerCoverPaletteService? playerCoverPalette;
  final double trackProgress;
  final bool isPlaying;
  final bool collaborativeMode;
  final bool collaborativeGuestMode;
  final bool guestLocalPauseActive;
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
    final useCoverPalette =
        !collaborativeMode && playerCoverPalette != null;
    final coverAccent = useCoverPalette
        ? playerCoverPalette!.colors.contrastAccent(isDark)
        : palette.textPrimary;
    final titleAccent = useCoverPalette
        ? playerCoverPalette!.colors.titleAccent(isDark)
        : palette.textPrimary;
    final sessionAccent = collaborativeGuestMode
        ? const Color(0xFFC084FC)
        : const Color(0xFF5FD1FF);
    final guestSurface = const Color(0xFF3B1A57).withValues(alpha: 0.72);

    Widget progressLayer() {
      final progressRemainGlass = isDark
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.white.withValues(alpha: 0.2);
      final glassTint = AppGlass.tint(isDark);
      final borderGlass = AppGlass.border(isDark);
      final progressPlayedGlass = collaborativeMode
          ? Color.alphaBlend(
              sessionAccent.withValues(
                alpha: collaborativeGuestMode ? 0.42 : (isDark ? 0.28 : 0.22),
              ),
              glassTint,
            )
          : null;

      return LayoutBuilder(
        builder: (context, constraints) {
          final progress = trackProgress.clamp(0.0, 1.0);
          final maxW = constraints.maxWidth;
          final progressWidth = (maxW * progress).clamp(0.0, maxW);
          final roundedLeft = Radius.circular(radius);
          final notAtEnd = progressWidth < maxW - 0.5;

          Widget remainFill() {
            if (!useCoverPalette) {
              return DecoratedBox(
                decoration: BoxDecoration(color: progressRemainGlass),
                child: const SizedBox.expand(),
              );
            }
            return Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.26)
                      : Colors.white.withValues(alpha: 0.36),
                ),
                PlayerCornerHazeLayer(
                  colors: playerCoverPalette!.colors
                      .softened(strength: 0.88)
                      .progressRemainCorners(isDark),
                  blurSigma: isDark ? 16 : 12,
                  radius: 1.15,
                ),
              ],
            );
          }

          Widget playedFill() {
            if (collaborativeMode) {
              return Container(
                width: progressWidth,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: progressPlayedGlass,
                  borderRadius: BorderRadius.horizontal(
                    left: roundedLeft,
                    right: notAtEnd ? Radius.zero : roundedLeft,
                  ),
                  border: notAtEnd
                      ? Border(
                          right: BorderSide(color: borderGlass, width: 1),
                        )
                      : null,
                ),
              );
            }
            final progressEdge = isDark
                ? Colors.white.withValues(alpha: 0.32)
                : Colors.white.withValues(alpha: 0.5);
            final corners = playerCoverPalette!.colors
                .softened(strength: 0.52)
                .progressPlayedCorners(isDark);
            return SizedBox(
              width: progressWidth,
              height: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.horizontal(
                  left: roundedLeft,
                  right: notAtEnd ? Radius.zero : roundedLeft,
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PlayerCornerHazeLayer(
                      colors: corners,
                      blurSigma: isDark ? 30 : 24,
                      radius: 1.28,
                    ),
                    if (notAtEnd)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          width: 1,
                          color: progressEdge,
                        ),
                      ),
                  ],
                ),
              ),
            );
          }

          return Stack(
            alignment: Alignment.centerLeft,
            clipBehavior: Clip.hardEdge,
            children: [
              if (notAtEnd)
                Positioned(
                  left: progressWidth,
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: remainFill(),
                )
              else if (!useCoverPalette)
                Positioned.fill(child: remainFill()),
              if (progressWidth > 0) playedFill(),
            ],
          );
        },
      );
    }

    final leadingIcon = collaborativeGuestMode && guestLocalPauseActive
        ? Icons.volume_off_rounded
        : isPlaying
        ? Icons.pause_rounded
        : Icons.play_arrow_rounded;

    final interior = SizedBox(
      height: height,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(child: progressLayer()),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: 0,
            child: Padding(
              padding: const EdgeInsets.only(
                left: 8,
                right: 16,
                top: 10,
                bottom: 10,
              ),
              child: Row(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onPlayPause,
                      customBorder: const CircleBorder(),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: collaborativeGuestMode
                              ? guestSurface
                              : Colors.transparent,
                        ),
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Icon(
                            leadingIcon,
                            size: 28,
                            color: collaborativeMode
                                ? sessionAccent
                                : coverAccent,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onTap,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                track.title,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: collaborativeMode
                                      ? palette.textPrimary
                                      : titleAccent,
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (collaborativeGuestMode)
                                Text(
                                  Localizations.localeOf(
                                            context,
                                          ).languageCode ==
                                          'en'
                                      ? 'Sync to host'
                                      : 'Синхронизация с хостом',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: sessionAccent,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onTap,
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
    );

    if (!useCoverPalette) return interior;

    return ListenableBuilder(
      listenable: playerCoverPalette!,
      builder: (context, _) => interior,
    );
  }
}

/// «Летающий» мини-плеер над боттом-баром: подложка с прогрессом, название трека, обложка справа.
/// Кнопка play/pause изолирована от области открытия полного плеера (без вложенного InkWell на всю карточку).
class FloatingMiniPlayer extends StatelessWidget {
  const FloatingMiniPlayer({
    super.key,
    required this.track,
    required this.playerCoverPalette,
    this.seeThroughChrome = false,
    this.trackProgress = 0.5,
    this.isPlaying = true,
    this.collaborativeMode = false,
    this.collaborativeGuestMode = false,
    this.guestLocalPauseActive = false,
    this.onTap,
    this.onPlayPause,
  });

  final Track track;
  final PlayerCoverPaletteService playerCoverPalette;

  /// На экранах настроек: только blur контента под плеером, без заливки обложкой.
  final bool seeThroughChrome;

  /// Прогресс трека 0.0..1.0.
  final double trackProgress;
  final bool isPlaying;
  final bool collaborativeMode;
  final bool collaborativeGuestMode;
  final bool guestLocalPauseActive;
  final VoidCallback? onTap;
  final VoidCallback? onPlayPause;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const radius = AppConstants.radiusLarge;
    final hostCollaborativeTint = isDark
        ? const Color(0xFF173247).withValues(alpha: 0.52)
        : const Color(0xFFDFF4FF).withValues(alpha: 0.68);
    final guestCollaborativeTint = isDark
        ? const Color(0xFF2A2F38).withValues(alpha: 0.56)
        : const Color(0xFFE8EBF0).withValues(alpha: 0.70);

    if (collaborativeMode) {
      final glassTint = seeThroughChrome
          ? Colors.transparent
          : collaborativeGuestMode
              ? guestCollaborativeTint
              : hostCollaborativeTint;
      return Material(
        color: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          clipBehavior: Clip.antiAlias,
          child: AppGlass.blurredTintLayerWithSigma(
            sigma: AppGlass.blurSigma,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: AppGlass.border(isDark), width: 1),
                color: glassTint,
                boxShadow:
                    seeThroughChrome ? null : AppGlass.cardShadows(isDark),
              ),
              child: MiniPlayerInterior(
                track: track,
                trackProgress: trackProgress,
                isPlaying: isPlaying,
                collaborativeMode: true,
                collaborativeGuestMode: collaborativeGuestMode,
                guestLocalPauseActive: guestLocalPauseActive,
                onTap: onTap,
                onPlayPause: onPlayPause,
              ),
            ),
          ),
        ),
      );
    }

    return ListenableBuilder(
      listenable: playerCoverPalette,
      builder: (context, _) {
        final crossfading = playerCoverPalette.isCrossfading;
        return Material(
          color: Colors.transparent,
          child: PlayerGlassShell(
            colors: playerCoverPalette.shellFrontColors,
            coverBytes: seeThroughChrome
                ? null
                : playerCoverPalette.shellFrontCover,
            underColors: seeThroughChrome
                ? null
                : crossfading
                    ? playerCoverPalette.shellBackColors
                    : null,
            underCoverBytes: seeThroughChrome
                ? null
                : crossfading
                    ? playerCoverPalette.shellBackCover
                    : null,
            crossfade: playerCoverPalette.shellCrossfade,
            isDark: isDark,
            borderRadius: BorderRadius.circular(radius),
            blurSigma: seeThroughChrome ? AppGlass.blurSigma : 0,
            seeThrough: seeThroughChrome,
            boxShadow:
                seeThroughChrome ? null : AppGlass.cardShadows(isDark),
            child: MiniPlayerInterior(
              track: track,
              playerCoverPalette: playerCoverPalette,
              trackProgress: trackProgress,
              isPlaying: isPlaying,
              onTap: onTap,
              onPlayPause: onPlayPause,
            ),
          ),
        );
      },
    );
  }
}
