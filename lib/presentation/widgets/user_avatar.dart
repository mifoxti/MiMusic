import 'package:flutter/material.dart';

import '../../core/constants/server_avatar_constants.dart';
import '../../core/platform/platform.dart';
import '../../core/theme/app_colors.dart';
import 'server_me_avatar.dart';

const String kDefaultUserAvatarAsset = 'assets/images/identity.png';

/// Аватар из asset (`assets/...`) или из файла в памяти приложения (путь с диска).
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.avatarPath,
    required this.size,
    required this.palette,
    this.border,
    this.serverAvatarCacheRevision = 0,
  });

  final String? avatarPath;
  final double size;
  final AppColorPalette palette;
  final BoxBorder? border;
  /// Смена значения перезапрашивает [GET /me/avatar] внутри [ServerMeAvatar].
  final int serverAvatarCacheRevision;

  String get _resolved {
    final p = avatarPath?.trim();
    if (p == null || p.isEmpty) return kDefaultUserAvatarAsset;
    return p;
  }

  @override
  Widget build(BuildContext context) {
    final resolved = _resolved;
    if (resolved == kServerMeAvatarMarker) {
      return ServerMeAvatar(
        size: size,
        palette: palette,
        border: border,
        cacheRevision: serverAvatarCacheRevision,
      );
    }
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
