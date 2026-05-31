import 'dart:typed_data';

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

/// Квадратный превью обложки из байтов (в т.ч. с сервера).
Widget studioCoverPreviewFromBytes(AppColorPalette palette, Uint8List bytes, double size) {
  final brokenPlaceholder = Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: palette.primaryDark.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
    ),
    child: Icon(Icons.broken_image_rounded, color: palette.textMuted),
  );
  return ClipRRect(
    borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
    child: SizedBox(
      width: size,
      height: size,
      child: Image.memory(
        bytes,
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, e, st) => brokenPlaceholder,
      ),
    ),
  );
}

/// Квадратная обложка в стеклянной рамке; ширина = блок [studioGlassPanel] (горизонтальный отступ 20).
Widget studioGlassSquareCover({
  required BuildContext context,
  required AppColorPalette palette,
  String? coverPath,
  Uint8List? coverBytes,
  Widget? emptyPlaceholder,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: studioGlassPanel(
      context: context,
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final side = constraints.maxWidth;
          final Widget preview;
          if (coverPath != null && coverPath.isNotEmpty) {
            preview = studioDialogCoverPreview(palette, coverPath, side);
          } else if (coverBytes != null && coverBytes.isNotEmpty) {
            preview = studioCoverPreviewFromBytes(palette, coverBytes, side);
          } else if (emptyPlaceholder != null) {
            preview = SizedBox(width: side, height: side, child: emptyPlaceholder);
          } else {
            preview = studioDialogCoverPreview(palette, '', side);
          }
          return AspectRatio(aspectRatio: 1, child: preview);
        },
      ),
    ),
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

/// Переключатель «Треки / Альбомы» в стеклянном стиле.
Widget studioGlassTabBar({
  required BuildContext context,
  required AppColorPalette palette,
  required List<Tab> tabs,
  TabController? controller,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return ClipRRect(
    borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
    child: AppGlass.blurredTintLayer(
      isDark: isDark,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppGlass.tint(isDark),
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
          border: Border.all(color: AppGlass.border(isDark)),
        ),
        child: TabBar(
          controller: controller,
          dividerColor: Colors.transparent,
          labelColor: palette.textPrimary,
          unselectedLabelColor: palette.textMuted,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            color: palette.accent.withValues(alpha: isDark ? 0.32 : 0.24),
            borderRadius: BorderRadius.circular(
              AppConstants.radiusLarge - 2,
            ),
          ),
          tabs: tabs,
        ),
      ),
    ),
  );
}

/// Кнопка «Добавить трек/альбом» в стеклянном стиле.
Widget studioGlassActionButton({
  required BuildContext context,
  required AppColorPalette palette,
  required VoidCallback onPressed,
  required IconData icon,
  required String label,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        child: AppGlass.blurredTintLayer(
          isDark: isDark,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                palette.accent.withValues(alpha: isDark ? 0.38 : 0.28),
                AppGlass.tint(isDark),
              ),
              borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
              border: Border.all(color: AppGlass.border(isDark)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 20, color: palette.textPrimary),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: palette.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
