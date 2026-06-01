import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/cache/remote_image_cache.dart';
import '../../core/network/playlists_api.dart';
import '../../core/platform/platform.dart';
import '../../core/profile/me_profile_avatar_disk.dart';
import '../../core/theme/app_colors.dart';

/// Аватар текущего пользователя с [GET /me/avatar] (дисковый кэш + Bearer).
///
/// [clipCircle] — круг как в шапке профиля; `false` — прямоугольник под обложку (без круга).
class ServerMeAvatar extends StatefulWidget {
  const ServerMeAvatar({
    super.key,
    required this.size,
    required this.palette,
    this.border,
    this.clipCircle = true,
    this.boxWidth,
    this.boxHeight,
    this.cacheRevision = 0,
  });

  final double size;
  final AppColorPalette palette;
  final BoxBorder? border;
  final bool clipCircle;
  /// При [clipCircle] == false задаёт размер области (иначе [size]×[size]).
  final double? boxWidth;
  final double? boxHeight;
  /// При изменении перезапрашивает аватар (сброс сетевого кэша по ревизии).
  final int cacheRevision;

  @override
  State<ServerMeAvatar> createState() => _ServerMeAvatarState();
}

class _ServerMeAvatarState extends State<ServerMeAvatar> {
  String? _filePath;
  bool _loading = true;

  double get _w => widget.clipCircle ? widget.size : (widget.boxWidth ?? widget.size);
  double get _h => widget.clipCircle ? widget.size : (widget.boxHeight ?? widget.size);

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void didUpdateWidget(covariant ServerMeAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cacheRevision != widget.cacheRevision) {
      _load(forceRefresh: true);
    }
  }

  Future<void> _bootstrap() async {
    if (widget.cacheRevision > 0) {
      await _load(forceRefresh: true);
      return;
    }
    final stable = await MeProfileAvatarDisk.cachedFile();
    if (stable != null && mounted) {
      setState(() {
        _filePath = stable.path;
        _loading = false;
      });
    }
    await _load(forceRefresh: false);
  }

  Future<void> _load({required bool forceRefresh}) async {
    if (!forceRefresh && _filePath != null && _filePath!.isNotEmpty) {
      if (mounted) setState(() => _loading = false);
    } else if (mounted) {
      setState(() => _loading = true);
    }

    final url = meAvatarUrl(cacheRevision: widget.cacheRevision);
    final file = await RemoteImageCache.instance.fileForUrl(
      url,
      requireAuth: true,
      forceRefresh: forceRefresh,
    );
    if (!mounted) return;
    final path = file?.path;
    if (path != null && path.isNotEmpty) {
      await MeProfileAvatarDisk.saveFrom(file!);
    }
    setState(() {
      _filePath = path ?? _filePath;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: _w,
      height: _h,
      color: widget.palette.accent.withValues(alpha: 0.25),
      alignment: Alignment.center,
      child: Icon(
        Icons.person_rounded,
        color: widget.palette.accent,
        size: widget.clipCircle ? widget.size * 0.45 : math.min(_w, _h) * 0.35,
      ),
    );

    final path = _filePath;
    final Widget imageLayer;
    if (path != null && path.isNotEmpty) {
      imageLayer = buildCoverImageFromFile(
        path,
        _w,
        _h,
        BorderRadius.zero,
        placeholder,
        BoxFit.cover,
      );
    } else if (_loading) {
      imageLayer = placeholder;
    } else {
      imageLayer = placeholder;
    }

    if (!widget.clipCircle) {
      return SizedBox(
        width: _w,
        height: _h,
        child: ClipRect(child: imageLayer),
      );
    }

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(shape: BoxShape.circle, border: widget.border),
      clipBehavior: Clip.antiAlias,
      child: imageLayer,
    );
  }
}
