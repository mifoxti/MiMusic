import 'dart:math' show max;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'hold_to_confirm_button.dart';

/// Открытые стеклянные bottom/center sheet (для системной «назад» в shell).
class GlassModalOverlay {
  GlassModalOverlay._();

  static int depth = 0;
}

/// Пункт «стеклянного» меню (как ⋮ в полном плеере).
class GlassMenuAction {
  const GlassMenuAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.labelStyle,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final TextStyle? labelStyle;
}

/// Bottom sheet в стиле [showFullPlayerTrackMenu] (blur 24, скругление 20, отступы).
Future<void> showGlassBottomMenuSheet(
  BuildContext context, {
  required List<GlassMenuAction> actions,
}) async {
  final palette = AppPaletteExtension.of(context).palette;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final glassTint = isDark
      ? Colors.white.withValues(alpha: 0.12)
      : Colors.white.withValues(alpha: 0.34);
  final borderGlass = Colors.white.withValues(alpha: isDark ? 0.22 : 0.45);

  GlassModalOverlay.depth++;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.paddingOf(ctx).bottom + 12,
          left: 12,
          right: 12,
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(Radius.circular(20)),
                border: Border.all(color: borderGlass),
                color: glassTint,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: palette.textMuted.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  for (final action in actions)
                    ListTile(
                      leading: Icon(
                        action.icon,
                        color: action.iconColor ?? palette.accent,
                      ),
                      title: Text(
                        action.label,
                        style: action.labelStyle ??
                            TextStyle(
                              color: palette.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        action.onTap();
                      },
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      );
    },
  ).whenComplete(() {
    GlassModalOverlay.depth = max(0, GlassModalOverlay.depth - 1);
  });
}

/// Центрированная «стеклянная» карточка (подтверждение). [builder] получает context листа.
Future<T?> showGlassCenterSheet<T>(
  BuildContext context, {
  required Widget Function(BuildContext sheetContext) builder,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final glassTint = isDark
      ? Colors.white.withValues(alpha: 0.12)
      : Colors.white.withValues(alpha: 0.34);
  final borderGlass = Colors.white.withValues(alpha: isDark ? 0.22 : 0.45);

  GlassModalOverlay.depth++;
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (sheetContext) {
      final viewInsets = MediaQuery.viewInsetsOf(sheetContext);
      return PopScope(
        canPop: true,
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: viewInsets.bottom +
                MediaQuery.paddingOf(sheetContext).bottom +
                16,
            top: 48,
          ),
          child: SingleChildScrollView(
            child: ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(20)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.all(Radius.circular(20)),
                    border: Border.all(color: borderGlass),
                    color: glassTint,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withValues(alpha: isDark ? 0.35 : 0.12),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: builder(sheetContext),
                ),
              ),
            ),
          ),
        ),
      );
    },
  ).whenComplete(() {
    GlassModalOverlay.depth = max(0, GlassModalOverlay.depth - 1);
  });
}

/// Подтверждение с удержанием «Удалить» (как удаление мысли).
Future<bool?> showGlassHoldToConfirmSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
  String? holdHint,
}) {
  return showGlassCenterSheet<bool>(
    context,
    builder: (sheetContext) {
      final palette = AppPaletteExtension.of(sheetContext).palette;
      return Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: TextStyle(
                color: palette.textSecondary,
                height: 1.35,
              ),
            ),
            if (holdHint != null) ...[
              const SizedBox(height: 8),
              Text(
                holdHint,
                style: TextStyle(
                  color: palette.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(sheetContext, false),
                    child: Text(cancelLabel),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: HoldToConfirmButton(
                    label: confirmLabel,
                    onConfirmed: () => Navigator.pop(sheetContext, true),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}
