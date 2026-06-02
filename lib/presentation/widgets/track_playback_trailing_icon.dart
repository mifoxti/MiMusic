import 'package:flutter/material.dart';

import '../../core/audio/audio_player_service.dart';
import '../../core/audio/track.dart';
import '../../core/theme/app_theme.dart';

/// Иконка play/pause в списке треков — реагирует на [AudioPlayerService].
class TrackPlaybackTrailingIcon extends StatelessWidget {
  const TrackPlaybackTrailingIcon({
    super.key,
    required this.audioPlayerService,
    required this.track,
    this.size = 28,
  });

  final AudioPlayerService audioPlayerService;
  final Track track;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    return ListenableBuilder(
      listenable: audioPlayerService,
      builder: (context, _) {
        final current = audioPlayerService.currentTrack;
        final active = current != null &&
            current.assetPath == track.assetPath &&
            (current.audioFilePath == track.audioFilePath ||
                track.audioFilePath == null);
        final playing = active && audioPlayerService.isPlaying;
        return Icon(
          active && playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: palette.accent.withValues(alpha: 0.9),
          size: size,
        );
      },
    );
  }
}
