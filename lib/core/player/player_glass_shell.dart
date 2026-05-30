import 'dart:typed_data';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'player_corner_gradient.dart';
import 'player_cover_glass_colors.dart';

/// Фон плеера: blur контента приложения + размытая обложка + 4 угловых цвета + лёгкая вуаль.
class PlayerGlassShell extends StatelessWidget {
  const PlayerGlassShell({
    super.key,
    required this.colors,
    required this.isDark,
    required this.child,
    this.coverBytes,
    this.underColors,
    this.underCoverBytes,
    this.crossfade = 1.0,
    this.borderRadius,
    this.borderWidth = 1,
    this.showBorder = true,
    this.blurSigma,
    this.boxShadow,
    /// Полный плеер: размытый контент приложения под стеклом, обложка только лёгким оттенком.
    this.seeThrough = false,
  });

  final PlayerCoverGlassColors colors;
  final bool isDark;
  final Widget child;
  final Uint8List? coverBytes;
  final PlayerCoverGlassColors? underColors;
  final Uint8List? underCoverBytes;
  final double crossfade;
  final bool seeThrough;
  final BorderRadius? borderRadius;
  final double borderWidth;
  final bool showBorder;
  final double? blurSigma;
  final List<BoxShadow>? boxShadow;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.zero;
    final sigma = blurSigma ?? 0;
    final t = crossfade.clamp(0.0, 1.0);
    final blend = underColors != null;

    return ClipRRect(
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          border: showBorder
              ? Border.all(color: colors.border(isDark), width: borderWidth)
              : null,
          boxShadow: boxShadow,
        ),
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            if (sigma > 0.5)
              Positioned.fill(
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: sigma,
                      sigmaY: sigma,
                      tileMode: TileMode.decal,
                    ),
                    child: const ColoredBox(color: Color(0x00000000)),
                  ),
                ),
              ),
            if (blend)
              Positioned.fill(
                child: Opacity(
                  opacity: (1.0 - t).clamp(0.0, 1.0),
                  child: _GlassBackdropLayer(
                    colors: underColors!,
                    coverBytes: underCoverBytes,
                    isDark: isDark,
                    seeThrough: seeThrough,
                  ),
                ),
              ),
            Positioned.fill(
              child: Opacity(
                opacity: blend ? t : 1.0,
                child: _GlassBackdropLayer(
                  colors: colors,
                  coverBytes: coverBytes,
                  isDark: isDark,
                  seeThrough: seeThrough,
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _GlassBackdropLayer extends StatelessWidget {
  const _GlassBackdropLayer({
    required this.colors,
    required this.coverBytes,
    required this.isDark,
    required this.seeThrough,
  });

  final PlayerCoverGlassColors colors;
  final Uint8List? coverBytes;
  final bool isDark;
  final bool seeThrough;

  @override
  Widget build(BuildContext context) {
    final cornerAlpha = seeThrough
        ? (isDark ? 0.48 : 0.40)
        : (isDark ? 0.62 : 0.52);
    final cornerTint = PlayerCoverGlassColors(
      topLeft: colors.topLeft.withValues(alpha: cornerAlpha),
      topRight: colors.topRight.withValues(alpha: cornerAlpha),
      bottomLeft: colors.bottomLeft.withValues(alpha: cornerAlpha),
      bottomRight: colors.bottomRight.withValues(alpha: cornerAlpha),
    );
    final scrimAlpha = seeThrough
        ? (isDark ? 0.10 : 0.06)
        : (isDark ? 0.22 : 0.14);
    final frostAlpha = seeThrough
        ? (isDark ? 0.03 : 0.04)
        : (isDark ? 0.05 : 0.07);
    final coverOpacity = seeThrough ? 0.38 : 1.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (coverBytes != null && coverBytes!.isNotEmpty)
          Positioned.fill(
            child: Opacity(
              opacity: coverOpacity,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: seeThrough ? 40 : 52,
                  sigmaY: seeThrough ? 40 : 52,
                  tileMode: TileMode.decal,
                ),
                child: Image.memory(
                  coverBytes!,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
          ),
        Positioned.fill(
          child: ColoredBox(
            color: Colors.black.withValues(alpha: scrimAlpha),
          ),
        ),
        Positioned.fill(
          child: PlayerCornerHazeLayer(
            colors: cornerTint,
            blurSigma: 18,
            radius: 1.45,
          ),
        ),
        Positioned.fill(
          child: ColoredBox(
            color: Colors.white.withValues(alpha: frostAlpha),
          ),
        ),
      ],
    );
  }
}
