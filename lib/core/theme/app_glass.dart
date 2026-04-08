import 'dart:ui';

import 'package:flutter/material.dart';

/// Единый «стеклянный» вид мини-плеера, нижней навигации и полноэкранного плеера.
abstract final class AppGlass {
  static const double blurSigma = 24;

  static Color tint(bool isDark) => isDark
      ? Colors.white.withValues(alpha: 0.12)
      : Colors.white.withValues(alpha: 0.34);

  static Color border(bool isDark) =>
      Colors.white.withValues(alpha: isDark ? 0.22 : 0.45);

  static List<BoxShadow> cardShadows(bool isDark) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.08),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];

  /// Размытие фона как у [FloatingMiniPlayer] / [_BottomNavBar].
  static Widget blurredTintLayer({
    required bool isDark,
    required Widget child,
  }) {
    return blurredTintLayerWithSigma(sigma: blurSigma, child: child);
  }

  /// То же стекло с настраиваемой силой размытия (например, 0 во время морфинга).
  static Widget blurredTintLayerWithSigma({
    required double sigma,
    required Widget child,
  }) {
    if (sigma <= 0.5) {
      return child;
    }
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: child,
      ),
    );
  }
}
