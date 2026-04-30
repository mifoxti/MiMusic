import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../core/audio/audio_player_service.dart';
import '../../../../core/l10n/app_localization.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/player/player_dock_host.dart';
import '../../../../core/player/shell_navigator_host.dart';
import '../../../../core/widgets/track_cover.dart';
import '../../../../presentation/pages/artist_page.dart';
import '../../../../presentation/pages/listening_room_page.dart';
import '../widgets/full_player_track_menu.dart';

/// Контент полного плеера. Полупрозрачное стекло — у родителя ([ExpandablePlayerDock] / мини-плеер).
class FullPlayerDockPanel extends StatelessWidget {
  const FullPlayerDockPanel({
    super.key,
    required this.audioPlayerService,
    required this.onCollapse,
  });

  final AudioPlayerService audioPlayerService;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;

    return SafeArea(
      child: ListenableBuilder(
        listenable: audioPlayerService,
        builder: (context, _) {
                  final track = audioPlayerService.currentTrack;
                  final position = audioPlayerService.position;
                  final duration = audioPlayerService.duration ?? Duration.zero;
                  final isPlaying = audioPlayerService.isPlaying;
                  final path = audioPlayerService.currentPlayablePath ?? '';
                  final liked =
                      path.isNotEmpty && audioPlayerService.isPathLiked(path);
                  final disliked =
                      path.isNotEmpty &&
                      audioPlayerService.isPathDisliked(path);
                  final shuffleOn = audioPlayerService.shuffleEnabled;
                  final loop = audioPlayerService.loopMode;
                  final multiQueue = audioPlayerService.hasMultiTrackQueue;

                  if (track == null) {
                    return Center(
                      child: Text(
                        context.t('player.nothingPlaying'),
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 16,
                        ),
                      ),
                    );
                  }

                  final clampedPosition = position.inMilliseconds.clamp(
                    0,
                    duration.inMilliseconds == 0 ? 0 : duration.inMilliseconds,
                  );
                  final sliderMax = duration.inMilliseconds == 0
                      ? 1.0
                      : duration.inMilliseconds.toDouble();
                  final sliderValue = duration.inMilliseconds == 0
                      ? 0.0
                      : clampedPosition.toDouble();

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                              ),
                              color: palette.textPrimary,
                              iconSize: 30,
                              onPressed: onCollapse,
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.more_vert_rounded),
                              color: palette.textSecondary,
                              onPressed: () => showFullPlayerTrackMenu(
                                context,
                                audioPlayerService: audioPlayerService,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: Column(
                            children: [
                              Hero(
                                tag: 'mimusic_player_cover',
                                child: buildTrackCover(
                                  coverSource:
                                      track.coverBytes ??
                                      track.coverFallbackPath,
                                  width: 260,
                                  height: 260,
                                  borderRadius: BorderRadius.circular(32),
                                  placeholder: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(32),
                                      color: palette.accent.withValues(
                                        alpha: 0.9,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Icon(
                                      Icons.music_note_rounded,
                                      size: 56,
                                      color: Colors.white.withValues(
                                        alpha: 0.95,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 28),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 28,
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      track.title,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w700,
                                        color: palette.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap:
                                            track.artistDisplay.trim().isEmpty
                                            ? null
                                            : () {
                                                final route =
                                                    MaterialPageRoute<void>(
                                                  builder: (_) => ArtistPage(
                                                    artistName:
                                                        track.artistDisplay,
                                                    coverAssetPath: track
                                                        .coverFallbackPath,
                                                    audioPlayerService:
                                                        audioPlayerService,
                                                  ),
                                                );
                                                final pushed =
                                                    ShellNavigatorHost.push(
                                                  route,
                                                );
                                                if (pushed) {
                                                  PlayerDockHost.collapse();
                                                } else {
                                                  Navigator.of(context).push(
                                                    route,
                                                  );
                                                }
                                              },
                                        borderRadius: BorderRadius.circular(8),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          child: Text(
                                            track.artistDisplay.isEmpty
                                                ? context.t('common.notSpecifiedArtist')
                                                : track.artistDisplay,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                              color:
                                                  track.artistDisplay
                                                      .trim()
                                                      .isEmpty
                                                  ? palette.textMuted
                                                  : palette.accent,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    _PlayerSeekBar(
                                      audioPlayerService: audioPlayerService,
                                      palette: palette,
                                      clampedPositionMs: clampedPosition,
                                      duration: duration,
                                      sliderMax: sliderMax,
                                      sliderValueFromService: sliderValue.clamp(
                                        0.0,
                                        sliderMax,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        _RoundIconButton(
                                          icon: Icons.skip_previous_rounded,
                                          onPressed:
                                              audioPlayerService.skipToPrevious,
                                          foregroundColor:
                                              palette.textSecondary,
                                        ),
                                        const SizedBox(width: 20),
                                        _PlayPauseButton(
                                          isPlaying: isPlaying,
                                          onPressed: audioPlayerService
                                              .togglePlayPause,
                                          foregroundColor: palette.textPrimary,
                                        ),
                                        const SizedBox(width: 20),
                                        _RoundIconButton(
                                          icon: Icons.skip_next_rounded,
                                          onPressed:
                                              audioPlayerService.skipToNext,
                                          foregroundColor:
                                              palette.textSecondary,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      child: SizedBox(
                                        width: double.infinity,
                                        child: FilledButton.icon(
                                          onPressed: () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute<void>(
                                                settings: const RouteSettings(
                                                  name: ListeningRoomPage
                                                      .routeName,
                                                ),
                                                builder: (_) =>
                                                    const ListeningRoomPage(),
                                              ),
                                            );
                                          },
                                          icon: const Icon(
                                            Icons.groups_rounded,
                                            size: 22,
                                          ),
                                          label: Padding(
                                            padding: EdgeInsets.symmetric(
                                              vertical: 4,
                                            ),
                                            child: Text(
                                              context.t('player.listenTogether'),
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          style: FilledButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 14,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Center(
                                              child: _LikeCircle(
                                                icon: disliked
                                                    ? Icons.thumb_down_rounded
                                                    : Icons
                                                          .thumb_down_off_alt_rounded,
                                                filled: disliked,
                                                onPressed: () =>
                                                    audioPlayerService
                                                        .toggleDislikeCurrent(),
                                                palette: palette,
                                                accentWhenOn:
                                                    palette.textSecondary,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Center(
                                              child: _RepeatGlyph(
                                                mode: loop,
                                                onPressed: () =>
                                                    audioPlayerService
                                                        .cycleLoopMode(),
                                                palette: palette,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Center(
                                              child: _TransportGlyph(
                                                icon: Icons.shuffle_rounded,
                                                active: shuffleOn,
                                                enabled: multiQueue,
                                                onPressed: multiQueue
                                                    ? () => audioPlayerService
                                                          .toggleShuffle()
                                                    : null,
                                                palette: palette,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Center(
                                              child: _LikeCircle(
                                                icon: liked
                                                    ? Icons.favorite_rounded
                                                    : Icons
                                                          .favorite_border_rounded,
                                                filled: liked,
                                                onPressed: () =>
                                                    audioPlayerService
                                                        .toggleLike(),
                                                palette: palette,
                                                accentWhenOn: palette.accent,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
    );
  }
}

class _TransportGlyph extends StatelessWidget {
  const _TransportGlyph({
    required this.icon,
    required this.active,
    required this.enabled,
    required this.onPressed,
    required this.palette,
  });

  final IconData icon;
  final bool active;
  final bool enabled;
  final VoidCallback? onPressed;
  final AppColorPalette palette;

  @override
  Widget build(BuildContext context) {
    final color = !enabled
        ? palette.textMuted.withValues(alpha: 0.35)
        : active
        ? palette.accent
        : palette.textSecondary;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: Colors.white.withValues(alpha: 0.14),
        shape: const CircleBorder(),
        child: IconButton(
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          padding: EdgeInsets.zero,
          icon: Icon(icon),
          color: color,
          iconSize: 24,
          onPressed: onPressed,
        ),
      ),
    );
  }
}

class _RepeatGlyph extends StatelessWidget {
  const _RepeatGlyph({
    required this.mode,
    required this.onPressed,
    required this.palette,
  });

  final LoopMode mode;
  final VoidCallback onPressed;
  final AppColorPalette palette;

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color color;
    switch (mode) {
      case LoopMode.off:
        icon = Icons.repeat_rounded;
        color = palette.textSecondary;
        break;
      case LoopMode.all:
        icon = Icons.repeat_rounded;
        color = palette.accent;
        break;
      case LoopMode.one:
        icon = Icons.repeat_one_rounded;
        color = palette.accent;
        break;
    }
    return Material(
      color: Colors.white.withValues(alpha: 0.14),
      shape: const CircleBorder(),
      child: IconButton(
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        padding: EdgeInsets.zero,
        icon: Icon(icon),
        color: color,
        iconSize: 24,
        onPressed: onPressed,
      ),
    );
  }
}

class _LikeCircle extends StatelessWidget {
  const _LikeCircle({
    required this.icon,
    required this.filled,
    required this.onPressed,
    required this.palette,
    required this.accentWhenOn,
  });

  final IconData icon;
  final bool filled;
  final VoidCallback onPressed;
  final AppColorPalette palette;
  final Color accentWhenOn;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.14),
      shape: const CircleBorder(),
      child: IconButton(
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        padding: EdgeInsets.zero,
        icon: Icon(icon),
        color: filled ? accentWhenOn : palette.textPrimary,
        iconSize: 24,
        onPressed: onPressed,
      ),
    );
  }
}

/// Слайдер прогресса: при перетаскивании локальное значение (важно для web и плавного scrub).
class _PlayerSeekBar extends StatefulWidget {
  const _PlayerSeekBar({
    required this.audioPlayerService,
    required this.palette,
    required this.clampedPositionMs,
    required this.duration,
    required this.sliderMax,
    required this.sliderValueFromService,
  });

  final AudioPlayerService audioPlayerService;
  final AppColorPalette palette;
  final int clampedPositionMs;
  final Duration duration;
  final double sliderMax;
  final double sliderValueFromService;

  @override
  State<_PlayerSeekBar> createState() => _PlayerSeekBarState();
}

class _PlayerSeekBarState extends State<_PlayerSeekBar> {
  bool _dragging = false;
  double _dragValue = 0;

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final maxV = widget.sliderMax <= 0 ? 1.0 : widget.sliderMax;
    final fromService = widget.sliderValueFromService.clamp(0.0, maxV);
    final thumb = _dragging ? _dragValue.clamp(0.0, maxV) : fromService;

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            thumbColor: palette.accent,
            activeTrackColor: palette.accent,
            inactiveTrackColor: palette.cardBackground.withValues(alpha: 0.7),
          ),
          child: Slider(
            min: 0,
            max: maxV,
            value: thumb,
            onChangeStart: (_) {
              setState(() {
                _dragging = true;
                _dragValue = fromService;
              });
            },
            onChanged: maxV <= 1 && widget.duration.inMilliseconds == 0
                ? null
                : (value) {
                    setState(() => _dragValue = value);
                  },
            onChangeEnd: (value) {
              widget.audioPlayerService.seek(
                Duration(milliseconds: value.toInt()),
              );
              setState(() => _dragging = false);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDurationLabel(
                  Duration(
                    milliseconds: _dragging
                        ? _dragValue.toInt().clamp(0, 1 << 30)
                        : widget.clampedPositionMs,
                  ),
                ),
                style: TextStyle(fontSize: 12, color: palette.textSecondary),
              ),
              Text(
                _formatDurationLabel(widget.duration),
                style: TextStyle(fontSize: 12, color: palette.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDurationLabel(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    final minutesStr = minutes.toString().padLeft(1, '0');
    final secondsStr = seconds.toString().padLeft(2, '0');
    return '$minutesStr:$secondsStr';
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onPressed,
    required this.foregroundColor,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      shape: const CircleBorder(),
      child: IconButton(
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        padding: const EdgeInsets.all(8),
        icon: Icon(icon),
        color: foregroundColor,
        iconSize: 28,
        onPressed: onPressed,
      ),
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({
    required this.isPlaying,
    required this.onPressed,
    required this.foregroundColor,
  });

  final bool isPlaying;
  final VoidCallback onPressed;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColors = isDark
        ? [
            palette.playbackButtonBg,
            palette.playbackButtonBg.withValues(alpha: 0.9),
          ]
        : [
            Colors.white.withValues(alpha: 0.95),
            Colors.white.withValues(alpha: 0.8),
          ];
    final iconColor = isDark ? palette.playbackButtonIcon : foregroundColor;
    final shadowColor = isDark
        ? Colors.black.withValues(alpha: 0.4)
        : Colors.black.withValues(alpha: 0.18);
    return SizedBox(
      width: 76,
      height: 76,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: bgColors),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: IconButton(
          padding: EdgeInsets.zero,
          icon: Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          ),
          iconSize: 38,
          color: iconColor,
          onPressed: onPressed,
        ),
      ),
    );
  }
}
