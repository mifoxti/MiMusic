import 'package:flutter/material.dart';

import '../../../../core/audio/audio_player_service.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/social/listening_room_session.dart';
import '../../../../core/theme/app_glass.dart';
import '../../../home/presentation/widgets/floating_mini_player.dart';
import '../pages/full_player_page.dart';

/// Высота от верха мини-блока до низа оверлея shell: мини [64] + padding под мини [12],
/// затем навигация: бар [12 + ряд ~60 + 12] + нижний padding навигации [12].
/// Должна совпадать с колонкой в [MainShell] (без второго [SafeArea] у навигации).
const double _kChromeHeightBelowMiniTop =
    64.0 + 12.0 + (12.0 + 60.0 + 12.0) + 12.0;

/// Свёрнутый прямоугольник мини-плеера в локальных координатах слоя дока (как у реального мини).
Rect collapsedMiniRectInOverlay(Size overlaySize) {
  const miniH = 64.0;
  const hPad = 12.0;
  final w = overlaySize.width;
  final h = overlaySize.height;
  final top = h - _kChromeHeightBelowMiniTop;
  return Rect.fromLTWH(hPad, top, w - 2 * hPad, miniH);
}

/// Один слой: затемнение + «карта» с тем же стеклом, что у мини-плеера, расширяется до экрана.
class ExpandablePlayerDock extends StatelessWidget {
  const ExpandablePlayerDock({
    super.key,
    required this.expandController,
    required this.audioPlayerService,
    required this.onCollapse,
  });

  final AnimationController expandController;
  final AudioPlayerService audioPlayerService;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final overlaySize = Size(constraints.maxWidth, constraints.maxHeight);
        final full = Rect.fromLTWH(0, 0, overlaySize.width, overlaySize.height);
        final begin = collapsedMiniRectInOverlay(overlaySize);

        return ListenableBuilder(
          listenable: expandController,
          builder: (context, _) {
            final raw = expandController.value.clamp(0.0, 1.0);
            // Совпадает со сдвигом нижнего блока в MainShell; easeInOut сглаживает рывки на краях.
            final u = Curves.easeInOutCubic.transform(raw);
            final rect = Rect.lerp(begin, full, u)!;
            final radius = BorderRadius.lerp(
              BorderRadius.circular(AppConstants.radiusLarge),
              BorderRadius.zero,
              u,
            )!;
            final borderW = u >= 0.995 ? 0.0 : 1.0;
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final glassTint = AppGlass.tint(isDark);
            final borderGlass = AppGlass.border(isDark);
            // BackdropFilter на всём кадре дорогой: размытие только ближе к полному развороту.
            final blurSigma = u < 0.82
                ? 0.0
                : AppGlass.blurSigma *
                    Curves.easeOut.transform(((u - 0.82) / 0.18).clamp(0.0, 1.0));

            return Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onCollapse,
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: 0.42 * u),
                    ),
                  ),
                ),
                Positioned(
                  left: rect.left,
                  top: rect.top,
                  width: rect.width,
                  height: rect.height,
                  child: RepaintBoundary(
                    child: ClipRRect(
                      borderRadius: radius,
                      clipBehavior: Clip.antiAlias,
                      child: AppGlass.blurredTintLayerWithSigma(
                        sigma: blurSigma,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: radius,
                            border: borderW > 0
                                ? Border.all(color: borderGlass, width: borderW)
                                : null,
                            color: glassTint,
                            boxShadow: u < 0.98
                                ? AppGlass.cardShadows(isDark)
                                : null,
                          ),
                          child: Stack(
                            clipBehavior: Clip.hardEdge,
                            fit: StackFit.expand,
                            children: [
                              _DockMiniLayer(
                                u: u,
                                audioPlayerService: audioPlayerService,
                              ),
                              if (u > 0.14)
                                Positioned.fill(
                                  child: IgnorePointer(
                                    ignoring: u < 0.22,
                                    child: Opacity(
                                      opacity:
                                          ((u - 0.14) / 0.72).clamp(0.0, 1.0),
                                      child: FullPlayerDockPanel(
                                        audioPlayerService: audioPlayerService,
                                        onCollapse: onCollapse,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Только слой мини (прогресс), чтобы перерисовки позиции трека не трогали весь док.
class _DockMiniLayer extends StatelessWidget {
  const _DockMiniLayer({required this.u, required this.audioPlayerService});

  final double u;
  final AudioPlayerService audioPlayerService;

  @override
  Widget build(BuildContext context) {
    if (u >= 0.5) {
      return const SizedBox.shrink();
    }
    return ListenableBuilder(
      listenable: Listenable.merge([audioPlayerService, ListeningRoomSession.instance]),
      builder: (context, _) {
        final dur = audioPlayerService.duration;
        final pos = audioPlayerService.position;
        final progress = dur != null && dur.inMilliseconds > 0
            ? pos.inMilliseconds / dur.inMilliseconds
            : 0.0;
        final track = audioPlayerService.currentTrack;
        if (track == null) {
          return const SizedBox.shrink();
        }
        final miniOp = (1.0 - (u / 0.48).clamp(0.0, 1.0));
        return Positioned.fill(
          child: RepaintBoundary(
            child: IgnorePointer(
              ignoring: miniOp < 0.05,
              child: Opacity(
                opacity: miniOp,
                child: MiniPlayerInterior(
                  track: track,
                  trackProgress: progress,
                  isPlaying: audioPlayerService.isPlaying,
                  collaborativeMode: ListeningRoomSession.instance.active,
                  collaborativeGuestMode: ListeningRoomSession.instance.active &&
                      !ListeningRoomSession.instance.isHost,
                  onTap: () {},
                  onPlayPause: () => audioPlayerService.togglePlayPause(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
