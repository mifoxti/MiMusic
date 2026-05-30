import 'package:flutter/material.dart';

import '../theme/app_glass.dart';

/// Четыре основных цвета обложки по углам (для стекла и фона плеера).
class PlayerCoverGlassColors {
  const PlayerCoverGlassColors({
    required this.topLeft,
    required this.topRight,
    required this.bottomLeft,
    required this.bottomRight,
  });

  final Color topLeft;
  final Color topRight;
  final Color bottomLeft;
  final Color bottomRight;

  /// Нейтральный фон, пока нет трека (без «синего диагонального» дефолта).
  static const PlayerCoverGlassColors fallback = PlayerCoverGlassColors(
    topLeft: Color(0xFF2C3038),
    topRight: Color(0xFF2C3038),
    bottomLeft: Color(0xFF1E2228),
    bottomRight: Color(0xFF1E2228),
  );

  static PlayerCoverGlassColors lerp(
    PlayerCoverGlassColors a,
    PlayerCoverGlassColors b,
    double t,
  ) {
    final x = t.clamp(0.0, 1.0);
    return PlayerCoverGlassColors(
      topLeft: Color.lerp(a.topLeft, b.topLeft, x)!,
      topRight: Color.lerp(a.topRight, b.topRight, x)!,
      bottomLeft: Color.lerp(a.bottomLeft, b.bottomLeft, x)!,
      bottomRight: Color.lerp(a.bottomRight, b.bottomRight, x)!,
    );
  }

  bool isCloseTo(PlayerCoverGlassColors other, {double epsilon = 0.02}) {
    return _close(topLeft, other.topLeft, epsilon) &&
        _close(topRight, other.topRight, epsilon) &&
        _close(bottomLeft, other.bottomLeft, epsilon) &&
        _close(bottomRight, other.bottomRight, epsilon);
  }

  static bool _close(Color a, Color b, double epsilon) {
    return (a.r - b.r).abs() +
            (a.g - b.g).abs() +
            (a.b - b.b).abs() <
        epsilon;
  }

  /// Смягчить контраст между углами (меньше резких перепадов после blur).
  PlayerCoverGlassColors softened({double strength = 0.68}) {
    final topMid = Color.lerp(topLeft, topRight, 0.5)!;
    final bottomMid = Color.lerp(bottomLeft, bottomRight, 0.5)!;
    final center = Color.lerp(topMid, bottomMid, 0.5)!;
    final s = strength.clamp(0.0, 1.0);
    return PlayerCoverGlassColors(
      topLeft: Color.lerp(center, topLeft, s)!,
      topRight: Color.lerp(center, topRight, s)!,
      bottomLeft: Color.lerp(center, bottomLeft, s)!,
      bottomRight: Color.lerp(center, bottomRight, s)!,
    );
  }

  /// Цвета угловой дымки под матовое стекло.
  PlayerCoverGlassColors hazeCorners(bool isDark) {
    final alpha = isDark ? 0.78 : 0.62;
    return PlayerCoverGlassColors(
      topLeft: topLeft.withValues(alpha: alpha),
      topRight: topRight.withValues(alpha: alpha),
      bottomLeft: bottomLeft.withValues(alpha: alpha),
      bottomRight: bottomRight.withValues(alpha: alpha),
    );
  }

  PlayerCoverGlassColors withAlphaScale(double scale) {
    final s = scale.clamp(0.0, 1.0);
    Color scaleColor(Color c) =>
        c.withValues(alpha: (c.a * s).clamp(0.0, 1.0));
    return PlayerCoverGlassColors(
      topLeft: scaleColor(topLeft),
      topRight: scaleColor(topRight),
      bottomLeft: scaleColor(bottomLeft),
      bottomRight: scaleColor(bottomRight),
    );
  }

  /// Непроигранная часть полосы прогресса (приглушённая).
  PlayerCoverGlassColors progressRemainCorners(bool isDark) {
    final alpha = isDark ? 0.10 : 0.08;
    return PlayerCoverGlassColors(
      topLeft: topLeft.withValues(alpha: alpha),
      topRight: topRight.withValues(alpha: alpha),
      bottomLeft: bottomLeft.withValues(alpha: alpha),
      bottomRight: bottomRight.withValues(alpha: alpha),
    );
  }

  /// Проигранная часть — ярче фона карточки.
  PlayerCoverGlassColors progressPlayedCorners(bool isDark) {
    final alpha = isDark ? 0.56 : 0.44;
    return PlayerCoverGlassColors(
      topLeft: topLeft.withValues(alpha: alpha),
      topRight: topRight.withValues(alpha: alpha),
      bottomLeft: bottomLeft.withValues(alpha: alpha),
      bottomRight: bottomRight.withValues(alpha: alpha),
    );
  }

  Color border(bool isDark) => AppGlass.border(isDark);
}
