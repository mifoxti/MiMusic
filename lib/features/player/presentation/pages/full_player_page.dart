import 'package:flutter/material.dart';

import '../../../../core/audio/audio_player_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/track_cover.dart';

class FullPlayerPage extends StatelessWidget {
  const FullPlayerPage({
    super.key,
    required this.audioPlayerService,
  });

  /// Имя маршрута для [NavigatorObserver] — скрытие мини-плеера без уведомлений во время build.
  static const String routeName = 'mimusic_full_player';

  final AudioPlayerService audioPlayerService;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              palette.gradientStart,
              palette.gradientMiddle,
              palette.gradientEnd,
            ],
          ),
        ),
        child: SafeArea(
          child: ListenableBuilder(
            listenable: audioPlayerService,
            builder: (context, _) {
              final track = audioPlayerService.currentTrack;
              final position = audioPlayerService.position;
              final duration = audioPlayerService.duration ?? Duration.zero;
              final isPlaying = audioPlayerService.isPlaying;

              if (track == null) {
                return Center(
                  child: Text(
                    'Сейчас ничего не играет',
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
              final sliderMax =
                  duration.inMilliseconds == 0 ? 1.0 : duration.inMilliseconds.toDouble();
              final sliderValue = duration.inMilliseconds == 0
                  ? 0.0
                  : clampedPosition.toDouble();

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.keyboard_arrow_down_rounded),
                          color: palette.textPrimary,
                          iconSize: 30,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.more_vert_rounded),
                          color: palette.textSecondary,
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Hero(
                          tag: 'mimusic_player_cover',
                          child: buildTrackCover(
                            coverSource: track.coverBytes ?? track.coverFallbackPath,
                            width: 260,
                            height: 260,
                            borderRadius: BorderRadius.circular(32),
                            placeholder: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(32),
                                color: palette.accent.withValues(alpha: 0.9),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.music_note_rounded,
                                size: 56,
                                color: Colors.white.withValues(alpha: 0.95),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
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
                              const SizedBox(height: 8),
                              Text(
                                track.artistDisplay,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: palette.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 28),
                              _PlayerSeekBar(
                                audioPlayerService: audioPlayerService,
                                palette: palette,
                                clampedPositionMs: clampedPosition,
                                duration: duration,
                                sliderMax: sliderMax,
                                sliderValueFromService: sliderValue.clamp(0.0, sliderMax),
                              ),
                              const SizedBox(height: 32),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _RoundIconButton(
                                    icon: Icons.skip_previous_rounded,
                                    onPressed: audioPlayerService.skipToPrevious,
                                    foregroundColor: palette.textSecondary,
                                  ),
                                  const SizedBox(width: 24),
                                  _PlayPauseButton(
                                    isPlaying: isPlaying,
                                    onPressed: audioPlayerService.togglePlayPause,
                                    foregroundColor: palette.textPrimary,
                                  ),
                                  const SizedBox(width: 24),
                                  _RoundIconButton(
                                    icon: Icons.skip_next_rounded,
                                    onPressed: audioPlayerService.skipToNext,
                                    foregroundColor: palette.textSecondary,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 32),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: const [
                                  _SmallIconCircle(icon: Icons.share_rounded),
                                  _SmallIconCircle(icon: Icons.favorite_border_rounded),
                                  _SmallIconCircle(icon: Icons.group_rounded),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
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
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 7,
            ),
            overlayShape: const RoundSliderOverlayShape(
              overlayRadius: 16,
            ),
            thumbColor: palette.accent,
            activeTrackColor: palette.accent,
            inactiveTrackColor:
                palette.cardBackground.withValues(alpha: 0.7),
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
                style: TextStyle(
                  fontSize: 12,
                  color: palette.textSecondary,
                ),
              ),
              Text(
                _formatDurationLabel(widget.duration),
                style: TextStyle(
                  fontSize: 12,
                  color: palette.textSecondary,
                ),
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
    final iconColor =
        isDark ? palette.playbackButtonIcon : foregroundColor;
    final shadowColor = isDark
        ? Colors.black.withValues(alpha: 0.4)
        : Colors.black.withValues(alpha: 0.18);
    return SizedBox(
      width: 82,
      height: 82,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: bgColors,
          ),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: IconButton(
          icon: Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          ),
          iconSize: 40,
          color: iconColor,
          onPressed: onPressed,
        ),
      ),
    );
  }
}

class _SmallIconCircle extends StatelessWidget {
  const _SmallIconCircle({
    required this.icon,
  });

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    return Material(
      color: Colors.white.withValues(alpha: 0.14),
      shape: const CircleBorder(),
      child: IconButton(
        icon: Icon(icon),
        color: palette.textPrimary,
        iconSize: 22,
        onPressed: () {},
      ),
    );
  }
}

