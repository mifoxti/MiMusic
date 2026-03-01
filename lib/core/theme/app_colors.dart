import 'package:flutter/material.dart';

/// Базовая палитра (светлая или тёмная).
abstract class AppColorPalette {
  Color get primaryLight;
  Color get primary;
  Color get primaryDark;
  Color get accent;
  Color get accentDark;

  Color get textPrimary;
  Color get textSecondary;
  Color get textMuted;

  Color get cardBackground;
  Color get navBarBackground;
  Color get navActiveBackground;

  Color get gradientStart;
  Color get gradientMiddle;
  Color get gradientEnd;

  Color get playbackButtonBg;
  Color get playbackButtonIcon;
}

/// Светлая тема — розовая гамма.
class LightPalette implements AppColorPalette {
  const LightPalette();

  @override
  Color get primaryLight => const Color(0xFFFDF2F5);
  @override
  Color get primary => const Color(0xFFF8E4E9);
  @override
  Color get primaryDark => const Color(0xFFF0D4DC);
  @override
  Color get accent => const Color(0xFFD84A7A);
  @override
  Color get accentDark => const Color(0xFFB83A65);

  @override
  Color get textPrimary => const Color(0xFF2D2528);
  @override
  Color get textSecondary => const Color(0xFF5C5054);
  @override
  Color get textMuted => const Color(0xFF8E8488);

  @override
  Color get cardBackground => const Color(0xFFF5E6EB);
  @override
  Color get navBarBackground => const Color(0xFFFBF5F7);
  @override
  Color get navActiveBackground => const Color(0xFFF5E6EB);

  @override
  Color get gradientStart => const Color(0xFFFDF2F5);
  @override
  Color get gradientMiddle => const Color(0xFFFAE8ED);
  @override
  Color get gradientEnd => const Color(0xFFF5DCE4);

  @override
  Color get playbackButtonBg => const Color(0xFFE8E0E4);
  @override
  Color get playbackButtonIcon => const Color(0xFF4A4050);
}

/// Тёмная тема — розово-тёмная гамма.
class DarkPalette implements AppColorPalette {
  const DarkPalette();

  @override
  Color get primaryLight => const Color(0xFF2D2328);
  @override
  Color get primary => const Color(0xFF3D3038);
  @override
  Color get primaryDark => const Color(0xFF4A3D45);
  @override
  Color get accent => const Color(0xFFE85A8A);
  @override
  Color get accentDark => const Color(0xFFC84A75);

  @override
  Color get textPrimary => const Color(0xFFF5EDEF);
  @override
  Color get textSecondary => const Color(0xFFC8BEC2);
  @override
  Color get textMuted => const Color(0xFF9A8E92);

  @override
  Color get cardBackground => const Color(0xFF3D3238);
  @override
  Color get navBarBackground => const Color(0xFF2A2228);
  @override
  Color get navActiveBackground => const Color(0xFF4A3D45);

  @override
  Color get gradientStart => const Color(0xFF2D2328);
  @override
  Color get gradientMiddle => const Color(0xFF352A30);
  @override
  Color get gradientEnd => const Color(0xFF3D3238);

  @override
  Color get playbackButtonBg => const Color(0xFF4A4050);
  @override
  Color get playbackButtonIcon => const Color(0xFFE8E0EC);
}

/// Текущая палитра приложения (задаётся темой).
abstract final class AppColors {
  static AppColorPalette of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const DarkPalette()
        : const LightPalette();
  }
}
