import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_glass.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/cover_image.dart';
import '../../../../core/widgets/track_cover.dart';

/// Горизонтальная карточка-кнопка («Для вас», «Чарты») с аватарками слева направо с наложением.
class NavCardButton extends StatelessWidget {
  const NavCardButton({
    super.key,
    required this.title,
    required this.onTap,
    this.avatarColors = const [Color(0xFF5C4A50), Color(0xFF4A3D42)],
    this.coverSources = const [],
  });

  final String title;
  final VoidCallback onTap;
  final List<Color> avatarColors;
  /// До двух обложек: URL или байты (base64 с API).
  final List<dynamic> coverSources;

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
    final sources = coverSources.take(2).toList();
    return SizedBox(
      width: totalWidth,
      height: radius * 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: _miniCover(
              sources.isNotEmpty ? sources[0] : null,
              radius,
              avatarColors[0],
            ),
          ),
          Positioned(
            left: radius * 2 - overlap,
            top: 0,
            child: _miniCover(
              sources.length > 1 ? sources[1] : null,
              radius,
              avatarColors.length > 1 ? avatarColors[1] : avatarColors[0],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniCover(
    dynamic source,
    double radius,
    Color fallback,
  ) {
    final placeholder = Container(
      color: fallback.withValues(alpha: 0.7),
      alignment: Alignment.center,
      child: const Icon(Icons.music_note_rounded, color: Colors.white70, size: 20),
    );
    if (source == null) {
      return Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: fallback.withValues(alpha: 0.7),
          boxShadow: _avatarShadow,
        ),
        child: const Icon(Icons.music_note_rounded, color: Colors.white70, size: 20),
      );
    }
    if (source is String && source.trim().isEmpty) {
      return Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: fallback.withValues(alpha: 0.7),
          boxShadow: _avatarShadow,
        ),
        child: const Icon(Icons.music_note_rounded, color: Colors.white70, size: 20),
      );
    }
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: const BoxDecoration(shape: BoxShape.circle, boxShadow: _avatarShadow),
      child: ClipOval(
        child: source is Uint8List || source is List<int>
            ? buildTrackCover(
                coverSource: source,
                width: radius * 2,
                height: radius * 2,
                borderRadius: BorderRadius.circular(radius),
                placeholder: placeholder,
              )
            : buildCoverImage(
                imageUrl: source as String,
                width: radius * 2,
                height: radius * 2,
                borderRadius: BorderRadius.circular(radius),
                placeholder: placeholder,
              ),
      ),
    );
  }
}
