import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/l10n/app_localization.dart';
import '../../core/theme/app_theme.dart';

/// Стеклянный bottom sheet: нет связи с сервером (красная иконка Wi‑Fi).
Future<void> showGlassNoConnectionSheet(BuildContext context) {
  final rootContext = Navigator.of(context, rootNavigator: true).context;
  final palette = AppPaletteExtension.of(rootContext).palette;
  final isDark = Theme.of(rootContext).brightness == Brightness.dark;
  final glassTint = isDark
      ? Colors.white.withValues(alpha: 0.16)
      : Colors.white.withValues(alpha: 0.72);
  final borderGlass = Colors.white.withValues(alpha: isDark ? 0.22 : 0.55);

  return showModalBottomSheet<void>(
    context: rootContext,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useRootNavigator: true,
    barrierColor: Colors.black.withValues(alpha: 0.45),
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
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.wifi_off_rounded,
                        color: Colors.redAccent,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            ctx.t('network.noServerTitle'),
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            ctx.t('network.noServerBody'),
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: Icon(Icons.close_rounded, color: palette.textMuted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
