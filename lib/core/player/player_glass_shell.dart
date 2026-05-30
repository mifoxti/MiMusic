import 'dart:typed_data';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'player_corner_gradient.dart';
import 'player_cover_glass_colors.dart';

/// Декод обложки для фона: сильный blur, полный размер не нужен.
const int _kShellCoverDecodeSide = 192;

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
    final backOpacity = blend ? (1.0 - t).clamp(0.0, 1.0) : 0.0;
    final frontOpacity = blend ? t : 1.0;

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
            Positioned.fill(
              child: RepaintBoundary(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (blend && backOpacity > 0)
                      Positioned.fill(
                        child: Opacity(
                          opacity: backOpacity,
                          child: _GlassBackdropLayer(
                            colors: underColors!,
                            coverBytes: underCoverBytes,
                            isDark: isDark,
                            seeThrough: seeThrough,
                          ),
                        ),
                      ),
                    if (frontOpacity > 0)
                      Positioned.fill(
                        child: Opacity(
                          opacity: frontOpacity,
                          child: _GlassBackdropLayer(
                            colors: colors,
                            coverBytes: coverBytes,
                            isDark: isDark,
                            seeThrough: seeThrough,
                          ),
                        ),
                      ),
                  ],
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

  static final ImageFilter _coverBlurExpanded = ImageFilter.blur(
    sigmaX: 52,
    sigmaY: 52,
    tileMode: TileMode.decal,
  );
  static final ImageFilter _coverBlurSeeThrough = ImageFilter.blur(
    sigmaX: 40,
    sigmaY: 40,
    tileMode: TileMode.decal,
  );

  @override
  Widget build(BuildContext context) {
    final cornerTint = colors.glassLayerTint(
      isDark: isDark,
      seeThrough: seeThrough,
    );
    final scrimAlpha = seeThrough
        ? (isDark ? 0.10 : 0.06)
        : (isDark ? 0.22 : 0.14);
    final frostAlpha = seeThrough
        ? (isDark ? 0.03 : 0.04)
        : (isDark ? 0.05 : 0.07);
    final coverOpacity = seeThrough ? 0.38 : 1.0;
    final coverBlur =
        seeThrough ? _coverBlurSeeThrough : _coverBlurExpanded;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (coverBytes != null && coverBytes!.isNotEmpty)
          Positioned.fill(
            child: Opacity(
              opacity: coverOpacity,
              child: ImageFiltered(
                imageFilter: coverBlur,
                child: Image.memory(
                  coverBytes!,
                  fit: BoxFit.cover,
                  cacheWidth: _kShellCoverDecodeSide,
                  cacheHeight: _kShellCoverDecodeSide,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.low,
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
