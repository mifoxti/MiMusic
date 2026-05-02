import 'package:flutter/material.dart';

import '../../core/platform/platform.dart';
import '../../core/theme/app_colors.dart';

const String kDefaultUserAvatarAsset = 'assets/images/identity.png';

/// Аватар из asset (`assets/...`) или из файла в памяти приложения (путь с диска).
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.avatarPath,
    required this.size,
    required this.palette,
    this.border,
  });

  final String? avatarPath;
  final double size;
  final AppColorPalette palette;
  final BoxBorder? border;

  String get _resolved {
    final p = avatarPath?.trim();
    if (p == null || p.isEmpty) return kDefaultUserAvatarAsset;
    return p;
  }

  @override
  Widget build(BuildContext context) {
    final resolved = _resolved;
    final placeholder = Container(
      width: size,
      height: size,
      color: palette.accent.withValues(alpha: 0.25),
      alignment: Alignment.center,
      child: Icon(Icons.person_rounded, color: palette.accent, size: size * 0.45),
    );

    final Widget child;
    if (resolved.startsWith('assets/')) {
      child = Image.asset(
        resolved,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
      );
    } else {
      child = buildCoverImageFromFile(
        resolved,
        size,
        size,
        BorderRadius.zero,
        placeholder,
        BoxFit.cover,
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: border,
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
