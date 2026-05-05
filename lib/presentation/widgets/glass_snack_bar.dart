import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Плавающий «стеклянный» SnackBar (blur + tint), без заливки Material по умолчанию.
void showGlassSnackBar(
  BuildContext context,
  String message, {
  EdgeInsetsGeometry margin = const EdgeInsets.fromLTRB(16, 0, 16, 96),
}) {
  final palette = AppPaletteExtension.of(context).palette;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final glassTint = isDark
      ? Colors.white.withValues(alpha: 0.12)
      : Colors.white.withValues(alpha: 0.34);
  final borderGlass = Colors.white.withValues(alpha: isDark ? 0.22 : 0.45);

  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      elevation: 0,
      margin: margin,
      padding: EdgeInsets.zero,
      duration: const Duration(seconds: 4),
      content: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderGlass),
              color: glassTint,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                  color: palette.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
