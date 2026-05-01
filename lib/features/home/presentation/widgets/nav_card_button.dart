import 'package:flutter/material.dart';

import '../../../../core/theme/app_glass.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';

/// Горизонтальная карточка-кнопка («Для вас», «Чарты») с аватарками слева направо с наложением.
class NavCardButton extends StatelessWidget {
  const NavCardButton({
    super.key,
    required this.title,
    required this.onTap,
    this.avatarColors = const [Color(0xFF5C4A50), Color(0xFF4A3D42)],
  });

  final String title;
  final VoidCallback onTap;
  final List<Color> avatarColors;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glassTint = AppGlass.tint(isDark);
    final borderGlass = AppGlass.border(isDark);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
          child: AppGlass.blurredTintLayer(
            isDark: isDark,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: glassTint,
                borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
                border: Border.all(color: borderGlass),
                boxShadow: AppGlass.cardShadows(isDark),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildAvatarStack(palette),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
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
    );
  }

  static const _avatarShadow = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
  ];

  Widget _buildAvatarStack(AppColorPalette palette) {
    const radius = 18.0;
    const overlap = 14.0;
    const totalWidth = radius * 2 + (radius * 2 - overlap);
    return SizedBox(
      width: totalWidth,
      height: radius * 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: Container(
              width: radius * 2,
              height: radius * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: avatarColors[0].withValues(alpha: 0.7),
                boxShadow: _avatarShadow,
              ),
              child: const Icon(Icons.person, color: Colors.white70, size: 20),
            ),
          ),
          Positioned(
            left: radius * 2 - overlap,
            top: 0,
            child: Container(
              width: radius * 2,
              height: radius * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (avatarColors.length > 1 ? avatarColors[1] : avatarColors[0])
                    .withValues(alpha: 0.7),
                boxShadow: _avatarShadow,
              ),
              child: const Icon(Icons.person, color: Colors.white70, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
