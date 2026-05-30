import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_glass.dart';
import '../../core/theme/app_theme.dart';

/// Стеклянная карточка в стиле приложения.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = AppPaletteExtension.of(context).palette;
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        child: AppGlass.blurredTintLayer(
          isDark: isDark,
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
              border: Border.all(color: AppGlass.border(isDark)),
              color: AppGlass.tint(isDark),
              boxShadow: AppGlass.cardShadows(isDark),
            ),
            child: DefaultTextStyle(
              style: TextStyle(color: palette.textPrimary),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Компактная метрика внутри [GlassPanel].
class GlassStatTile extends StatelessWidget {
  const GlassStatTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.accentColor,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    final accent = accentColor ?? palette.accent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 22, color: accent),
          const SizedBox(height: 8),
        ],
        Text(
          value,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 13, color: palette.textSecondary, height: 1.2),
        ),
      ],
    );
  }
}
