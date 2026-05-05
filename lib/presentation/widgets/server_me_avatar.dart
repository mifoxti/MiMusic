import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/network/authenticated_dio.dart';
import '../../core/theme/app_colors.dart';

/// Аватар текущего пользователя с [GET /me/avatar] (Bearer из [createAuthenticatedDio]).
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
  /// При изменении перезапрашивает байты (смена аккаунта, после загрузки аватара).
  final int cacheRevision;

  @override
  State<ServerMeAvatar> createState() => _ServerMeAvatarState();
}

class _ServerMeAvatarState extends State<ServerMeAvatar> {
  Uint8List? _bytes;

  double get _w => widget.clipCircle ? widget.size : (widget.boxWidth ?? widget.size);
  double get _h => widget.clipCircle ? widget.size : (widget.boxHeight ?? widget.size);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ServerMeAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cacheRevision != widget.cacheRevision) {
      setState(() => _bytes = null);
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final dio = await createAuthenticatedDio();
      final res = await dio.get<List<int>>(
        '/me/avatar',
        queryParameters: <String, dynamic>{
          'cb': '${widget.cacheRevision}_${DateTime.now().millisecondsSinceEpoch}',
        },
        options: Options(responseType: ResponseType.bytes),
      );
      final data = res.data;
      if (!mounted) return;
      if (data != null && data.isNotEmpty) {
        setState(() => _bytes = Uint8List.fromList(data));
      }
    } catch (_) {}
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
    final b = _bytes;
    Widget imageLayer;
    if (b != null && b.isNotEmpty) {
      imageLayer = Image.memory(
        b,
        width: _w,
        height: _h,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
      );
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
