import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'player_cover_glass_colors.dart';

/// Мягкая дымка: 4 радиальных пятна по углам + сильное размытие.
class PlayerCornerHazeLayer extends StatelessWidget {
  const PlayerCornerHazeLayer({
    super.key,
    required this.colors,
    this.blurSigma = 0,
    this.radius = 1.35,
  });

  final PlayerCoverGlassColors colors;
  final double blurSigma;
  final double radius;

  @override
  Widget build(BuildContext context) {
    Widget layer = Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.hardEdge,
      children: [
        _cornerGlow(Alignment.topLeft, colors.topLeft),
        _cornerGlow(Alignment.topRight, colors.topRight),
        _cornerGlow(Alignment.bottomLeft, colors.bottomLeft),
        _cornerGlow(Alignment.bottomRight, colors.bottomRight),
      ],
    );

    if (blurSigma > 0.5) {
      layer = RepaintBoundary(
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(
            sigmaX: blurSigma,
            sigmaY: blurSigma,
            tileMode: TileMode.decal,
          ),
          child: layer,
        ),
      );
    } else {
      layer = RepaintBoundary(child: layer);
    }
    return layer;
  }

  Widget _cornerGlow(Alignment center, Color color) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: center,
            radius: radius,
            colors: [
              color,
              color.withValues(alpha: 0),
            ],
            stops: const [0.0, 1.0],
          ),
        ),
      ),
    );
  }
}
