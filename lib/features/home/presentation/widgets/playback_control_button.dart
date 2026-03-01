import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Большая круглая кнопка воспроизведения/паузы в шапке.
class PlaybackControlButton extends StatelessWidget {
  const PlaybackControlButton({
    super.key,
    required this.isPlaying,
    required this.onPressed,
  });

  final bool isPlaying;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(48),
        child: Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: palette.playbackButtonBg,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: 48,
            color: palette.playbackButtonIcon,
          ),
        ),
      ),
    );
  }
}
