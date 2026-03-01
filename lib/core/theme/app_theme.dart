import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Расширение темы для доступа к палитре MiMusic.
class AppPaletteExtension extends ThemeExtension<AppPaletteExtension> {
  const AppPaletteExtension({required this.palette});

  final AppColorPalette palette;

  @override
  AppPaletteExtension copyWith({AppColorPalette? palette}) {
    return AppPaletteExtension(palette: palette ?? this.palette);
  }

  @override
  AppPaletteExtension lerp(
    ThemeExtension<AppPaletteExtension>? other,
    double t,
  ) {
    return this;
  }

  static AppPaletteExtension of(BuildContext context) {
    return Theme.of(context).extension<AppPaletteExtension>()!;
  }
}

abstract final class AppTheme {
  static ThemeData get light {
    const p = LightPalette();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: p.accent,
        onPrimary: Colors.white,
        surface: p.primaryLight,
        onSurface: p.textPrimary,
        secondary: p.primaryDark,
        onSecondary: p.textPrimary,
        outline: p.textMuted,
        outlineVariant: p.primaryDark,
        surfaceContainerHighest: p.cardBackground,
        surfaceContainerHigh: p.primary,
        surfaceContainer: p.primaryLight,
      ),
      scaffoldBackgroundColor: p.primaryLight,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      iconTheme: IconThemeData(color: p.textSecondary),
      cardTheme: CardThemeData(
        color: p.cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: p.navBarBackground,
        selectedItemColor: p.textPrimary,
        unselectedItemColor: p.textMuted,
        type: BottomNavigationBarType.fixed,
      ),
      dividerColor: p.primaryDark,
      extensions: [const AppPaletteExtension(palette: LightPalette())],
    );
  }

  static ThemeData get dark {
    const p = DarkPalette();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: p.accent,
        onPrimary: Colors.white,
        surface: p.primaryLight,
        onSurface: p.textPrimary,
        secondary: p.primaryDark,
        onSecondary: p.textPrimary,
      ),
      scaffoldBackgroundColor: p.primaryLight,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: p.cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: p.navBarBackground,
        selectedItemColor: p.textPrimary,
        unselectedItemColor: p.textMuted,
        type: BottomNavigationBarType.fixed,
      ),
      extensions: [const AppPaletteExtension(palette: DarkPalette())],
    );
  }
}
