import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/l10n/app_localization.dart';
import '../../core/studio/studio_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_glass.dart';
import '../../core/platform/platform.dart';

/// Стеклянная карточка в стиле главной / плейлистов.
Widget studioGlassPanel({
  required BuildContext context,
  required Widget child,
  EdgeInsetsGeometry padding = const EdgeInsets.all(14),
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return ClipRRect(
    borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
    child: AppGlass.blurredTintLayer(
      isDark: isDark,
      child: Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: AppGlass.tint(isDark),
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
          border: Border.all(color: AppGlass.border(isDark)),
          boxShadow: AppGlass.cardShadows(isDark),
        ),
        child: child,
      ),
    ),
  );
}

InputDecoration studioGlassFieldDecoration({
  required AppColorPalette palette,
  required String labelText,
  String? hintText,
}) {
  final borderColor = palette.textPrimary.withValues(alpha: 0.2);
  final fill = palette.primaryDark.withValues(alpha: 0.42);
  final radius = BorderRadius.circular(14);
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    filled: true,
    fillColor: fill,
    labelStyle: TextStyle(color: palette.textSecondary, fontSize: 13),
    hintStyle: TextStyle(color: palette.textMuted, fontSize: 13),
    floatingLabelBehavior: FloatingLabelBehavior.auto,
    border: OutlineInputBorder(borderRadius: radius),
    enabledBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: borderColor),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(
        color: palette.accent.withValues(alpha: 0.9),
        width: 1.5,
      ),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  );
}

Widget studioDialogCoverPreview(AppColorPalette palette, String path, double size) {
  final placeholder = Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: palette.primaryDark.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
    ),
    child: Icon(Icons.image_rounded, color: palette.textMuted, size: size * 0.5),
  );
  final brokenPlaceholder = Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: palette.primaryDark.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
    ),
    child: Icon(Icons.broken_image_rounded, color: palette.textMuted),
  );
  if (path.isEmpty) return placeholder;
  return ClipRRect(
    borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
    child: SizedBox(
      width: size,
      height: size,
      child: path.startsWith('assets/')
          ? Image.asset(path, fit: BoxFit.cover, errorBuilder: (_, e, st) => brokenPlaceholder)
          : studioCoverImageFromFile(path, size, brokenPlaceholder),
    ),
  );
}

String studioGenreChipLabel(BuildContext context, String stored) {
  final id = normalizeStudioGenreId(stored);
  if (id != null && studioGenreIds.contains(id)) {
    return context.t('studio.genre.$id');
  }
  return stored;
}
