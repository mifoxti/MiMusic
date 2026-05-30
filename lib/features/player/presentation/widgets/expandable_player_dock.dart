import 'package:flutter/material.dart';

import '../../../../core/audio/audio_player_service.dart';
import '../../../playlists/domain/repositories/playlists_repository.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/social/listening_room_session.dart';
import '../../../../core/player/player_cover_palette_service.dart';
import '../../../../core/player/player_glass_shell.dart';
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
    required this.playerCoverPalette,
    required this.onCollapse,
    required this.playlistsRepository,
  });

  final AnimationController expandController;
  final AudioPlayerService audioPlayerService;
  final PlayerCoverPaletteService playerCoverPalette;
  final VoidCallback onCollapse;
  final PlaylistsRepository playlistsRepository;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final overlaySize = Size(constraints.maxWidth, constraints.maxHeight);
        final full = Rect.fromLTWH(0, 0, overlaySize.width, overlaySize.height);
        final begin = collapsedMiniRectInOverlay(overlaySize);

        return ListenableBuilder(
          listenable: Listenable.merge([
            expandController,
            playerCoverPalette,
          ]),
          builder: (context, _) {
            final raw = expandController.value.clamp(0.0, 1.0);
            // Пока док полностью свёрнут, не перехватываем тапы по экрану — иначе блокируются
            // списки, диалоги и маршруты под слоем дока в MainShell.
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
            final palette = playerCoverPalette;
            final crossfading = palette.isCrossfading;
            // Размытие контента под плеером (как у мини): раньше, чем раньше — с ~35% разворота.
            final blurSigma = u < 0.35
                ? 0.0
                : AppGlass.blurSigma *
                      Curves.easeOut.transform(
                        ((u - 0.35) / 0.65).clamp(0.0, 1.0),
                      );

            return Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    // Синхронизировать с «кривой» u: при малом raw затемнение уже почти 0,
                    // а карта по u ещё заметна — иначе тапы проходят к списку под доком.
                    ignoring: u < 0.02,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onCollapse,
                      child: ColoredBox(
                        color: Colors.black.withValues(alpha: 0.14 * u),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: rect.left,
                  top: rect.top,
                  width: rect.width,
                  height: rect.height,
                  child: RepaintBoundary(
                    child: PlayerGlassShell(
                      colors: palette.shellFrontColors,
                      coverBytes: palette.shellFrontCover,
                      underColors:
                          crossfading ? palette.shellBackColors : null,
                      underCoverBytes:
                          crossfading ? palette.shellBackCover : null,
                      crossfade: palette.shellCrossfade,
                      isDark: isDark,
                      seeThrough: u > 0.35,
                      borderRadius: radius,
                      showBorder: borderW > 0,
                      borderWidth: borderW,
                      blurSigma: blurSigma,
                      boxShadow: u < 0.98
                          ? AppGlass.cardShadows(isDark)
                          : null,
                      child: Stack(
                        clipBehavior: Clip.hardEdge,
                        fit: StackFit.expand,
                        children: [
                          _DockMiniLayer(
                            u: u,
                            audioPlayerService: audioPlayerService,
                            playerCoverPalette: playerCoverPalette,
                          ),
                          if (u > 0.14)
                            Positioned.fill(
                              child: IgnorePointer(
                                ignoring: u < 0.22,
                                child: Opacity(
                                  opacity: ((u - 0.14) / 0.72).clamp(
                                    0.0,
                                    1.0,
                                  ),
                                  child: FullPlayerDockPanel(
                                    audioPlayerService: audioPlayerService,
                                    playerCoverPalette: playerCoverPalette,
                                    onCollapse: onCollapse,
                                    playlistsRepository:
                                        playlistsRepository,
                                  ),
                                ),
                              ),
                            ),
                        ],
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
  const _DockMiniLayer({
    required this.u,
    required this.audioPlayerService,
    required this.playerCoverPalette,
  });

  final double u;
  final AudioPlayerService audioPlayerService;
  final PlayerCoverPaletteService playerCoverPalette;

  @override
  Widget build(BuildContext context) {
    if (u >= 0.5) {
      return const SizedBox.shrink();
    }
    return ListenableBuilder(
      listenable: Listenable.merge([
        audioPlayerService,
        ListeningRoomSession.instance,
        playerCoverPalette,
      ]),
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
                  playerCoverPalette: playerCoverPalette,
                  collaborativeMode: ListeningRoomSession.instance.active,
                  collaborativeGuestMode:
                      ListeningRoomSession.instance.active &&
                      !ListeningRoomSession.instance.isHost,
                  guestLocalPauseActive:
                      audioPlayerService.guestLocalPauseActive,
                  onTap: () {},
                  onPlayPause:
                      ListeningRoomSession.instance.active &&
                          !ListeningRoomSession.instance.canControlPause
                      ? null
                      : () => audioPlayerService.togglePlayPause(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
