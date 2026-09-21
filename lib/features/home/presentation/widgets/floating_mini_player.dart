import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

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
    this.seeThroughChrome = false,
    this.trackProgress = 0.5,
    this.positionListenable,
    this.duration,
    this.isPlaying = true,
    this.collaborativeMode = false,
    this.collaborativeGuestMode = false,
    this.guestLocalPauseActive = false,
    this.onTap,
    this.onPlayPause,
  });

  final Track track;
  final PlayerCoverPaletteService? playerCoverPalette;

  /// На экранах настроек: без цветной подложки прогресса — только blur снаружи.
  final bool seeThroughChrome;
  final double trackProgress;
  final ValueListenable<Duration>? positionListenable;
  final Duration? duration;
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
    final useCoverPalette = !collaborativeMode && playerCoverPalette != null;
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

    Widget progressLayer(double trackProgress) {
      if (seeThroughChrome) {
        return const SizedBox.expand();
      }
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
                      ? Border(right: BorderSide(color: borderGlass, width: 1))
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
                        child: Container(width: 1, color: progressEdge),
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
          Positioned.fill(
            child: RepaintBoundary(
              child: positionListenable == null
                  ? progressLayer(trackProgress)
                  : ValueListenableBuilder<Duration>(
                      valueListenable: positionListenable!,
                      builder: (context, position, _) {
                        final ms = duration?.inMilliseconds ?? 0;
                        return progressLayer(
                          ms > 0 ? position.inMilliseconds / ms : 0,
                        );
                      },
                    ),
            ),
          ),
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
    this.positionListenable,
    this.duration,
    this.isPlaying = true,
    this.collaborativeMode = false,
    this.collaborativeGuestMode = false,
    this.guestLocalPauseActive = false,
    this.onTap,
    this.onPlayPause,
    this.onNext,
    this.onPrevious,
    this.onDismiss,
  });

  final Track track;
  final PlayerCoverPaletteService playerCoverPalette;

  /// На экранах настроек: только blur контента под плеером, без заливки обложкой.
  final bool seeThroughChrome;

  /// Прогресс трека 0.0..1.0.
  final double trackProgress;
  final ValueListenable<Duration>? positionListenable;
  final Duration? duration;
  final bool isPlaying;
  final bool collaborativeMode;
  final bool collaborativeGuestMode;
  final bool guestLocalPauseActive;
  final VoidCallback? onTap;
  final VoidCallback? onPlayPause;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) => _MiniPlayerGestures(
    onNext: onNext,
    onPrevious: onPrevious,
    onDismiss: onDismiss,
    child: _buildGlass(context),
  );

  Widget _buildGlass(BuildContext context) {
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
                boxShadow: seeThroughChrome
                    ? null
                    : AppGlass.cardShadows(isDark),
              ),
              child: MiniPlayerInterior(
                track: track,
                seeThroughChrome: seeThroughChrome,
                trackProgress: trackProgress,
                positionListenable: positionListenable,
                duration: duration,
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
            blurOnly: seeThroughChrome,
            seeThrough: false,
            boxShadow: seeThroughChrome ? null : AppGlass.cardShadows(isDark),
            child: MiniPlayerInterior(
              track: track,
              playerCoverPalette: playerCoverPalette,
              seeThroughChrome: seeThroughChrome,
              trackProgress: trackProgress,
              positionListenable: positionListenable,
              duration: duration,
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

/// Separate axis recognizers let taps still reach play/pause and open-player.
/// Only the transform repaints while dragging; the glass and text stay cached.
class _MiniPlayerGestures extends StatefulWidget {
  const _MiniPlayerGestures({
    required this.child,
    this.onNext,
    this.onPrevious,
    this.onDismiss,
  });
  final Widget child;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;
  final VoidCallback? onDismiss;

  @override
  State<_MiniPlayerGestures> createState() => _MiniPlayerGesturesState();
}

class _MiniPlayerGesturesState extends State<_MiniPlayerGestures>
    with SingleTickerProviderStateMixin {
  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  Offset _offset = Offset.zero;
  Offset _from = Offset.zero;
  Offset _to = Offset.zero;
  bool _busy = false;
  int? _pointer;
  Offset _dragStart = Offset.zero;
  Duration _dragStartedAt = Duration.zero;
  bool? _horizontalDrag;

  @override
  void initState() {
    super.initState();
    _settle.addListener(() {
      setState(
        () => _offset = Offset.lerp(
          _from,
          _to,
          Curves.easeOutCubic.transform(_settle.value),
        )!,
      );
    });
  }

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  Future<void> _finish(
    bool horizontal,
    double velocity, {
    bool cancelled = false,
  }) async {
    if (_busy) return;
    final distance = horizontal ? _offset.dx : _offset.dy;
    final committed =
        !cancelled &&
        (horizontal
            ? distance.abs() > 64 || velocity.abs() > 650
            : distance > 38 || velocity > 650);
    final direction = distance.abs() > 8 ? distance.sign : velocity.sign;
    final action = horizontal
        ? (direction < 0 ? widget.onNext : widget.onPrevious)
        : widget.onDismiss;
    // Change the track as soon as a horizontal swipe is committed. Waiting for
    // the settle animation made a fast swipe feel ignored on lower-end devices.
    if (horizontal && committed && action != null) action();
    _busy = true;
    _from = _offset;
    _to = committed && action != null
        ? (horizontal ? Offset(direction * 96, 0) : const Offset(0, 88))
        : Offset.zero;
    try {
      await _settle.forward(from: 0).orCancel;
      if (!mounted) return;
      if (!horizontal && committed && action != null) action();
      if (!mounted) return;
      if (horizontal && committed && action != null)
        _offset = Offset(-direction * 32, 0);
      _from = _offset;
      _to = Offset.zero;
      await _settle.forward(from: 0).orCancel;
    } on TickerCanceled {
      // The stop callback may remove the dock during its settling animation.
    } finally {
      _busy = false;
    }
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_busy) return;
    _pointer = event.pointer;
    _dragStart = event.position;
    _dragStartedAt = event.timeStamp;
    _horizontalDrag = null;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_pointer != event.pointer || _busy) return;
    final delta = event.position - _dragStart;
    final horizontal = _horizontalDrag ??= delta.dx.abs() > delta.dy.abs();
    if (delta.distance < 6) return;
    if (horizontal) {
      if ((delta.dx < 0 && widget.onNext == null) ||
          (delta.dx > 0 && widget.onPrevious == null)) {
        return;
      }
      setState(() => _offset = Offset(delta.dx.clamp(-120.0, 120.0), 0));
      return;
    }
    if (widget.onDismiss != null && delta.dy > 0) {
      setState(() => _offset = Offset(0, delta.dy.clamp(0.0, 100.0)));
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_pointer != event.pointer) return;
    final horizontal = _horizontalDrag;
    _pointer = null;
    _horizontalDrag = null;
    if (horizontal == null || _offset == Offset.zero) {
      return;
    }
    final elapsedMs = (event.timeStamp - _dragStartedAt).inMilliseconds;
    final distance = horizontal ? _offset.dx : _offset.dy;
    final velocity = elapsedMs > 0 ? distance * 1000 / elapsedMs : 0.0;
    _finish(horizontal, velocity);
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.opaque,
    onPointerDown: _onPointerDown,
    onPointerMove: _onPointerMove,
    onPointerUp: _onPointerUp,
    onPointerCancel: (_) {
      final horizontal = _horizontalDrag;
      _pointer = null;
      _horizontalDrag = null;
      if (horizontal != null) _finish(horizontal, 0, cancelled: true);
    },
    child: Transform.translate(
      offset: _offset,
      child: Opacity(
        opacity: (1 - _offset.distance / 180).clamp(0.25, 1.0),
        child: RepaintBoundary(child: widget.child),
      ),
    ),
  );
}
