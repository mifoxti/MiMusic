import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../cache/remote_image_cache.dart';
import '../platform/platform.dart' show buildCoverImageFromFile;

/// Путь к файлу на диске (не asset и не URL).
bool _isFilePath(String path) {
  if (path.startsWith('http://') || path.startsWith('https://')) return false;
  if (path.startsWith('assets/')) return false;
  if (path.startsWith('/')) return true;
  if (path.length >= 2 && path[1] == ':') return true;
  return false;
}

/// Обложка трека/релиза по URL, пути к asset или пути к файлу.
/// HTTP(S) — с дисковым кэшем; файловый путь и asset — как раньше.
Widget buildCoverImage({
  required String? imageUrl,
  required double width,
  required double height,
  required BorderRadius borderRadius,
  required Widget placeholder,
  BoxFit fit = BoxFit.cover,
  bool forceRefreshNetwork = false,
}) {
  if (imageUrl == null || imageUrl.isEmpty) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(width: width, height: height, child: placeholder),
    );
  }
  if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
    if (kIsWeb) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: SizedBox(
          width: width,
          height: height,
          child: Image.network(
            imageUrl,
            fit: fit,
            width: width,
            height: height,
            errorBuilder: (_, _, _) => placeholder,
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        width: width,
        height: height,
        child: _CachedNetworkCover(
          imageUrl: imageUrl,
          width: width,
          height: height,
          placeholder: placeholder,
          fit: fit,
          forceRefresh: forceRefreshNetwork,
        ),
      ),
    );
  }
  if (_isFilePath(imageUrl)) {
    return buildCoverImageFromFile(
      imageUrl,
      width,
      height,
      borderRadius,
      placeholder,
      fit,
    );
  }
  return ClipRRect(
    borderRadius: borderRadius,
    child: SizedBox(
      width: width,
      height: height,
      child: Image.asset(
        imageUrl,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (context, error, stackTrace) => placeholder,
      ),
    ),
  );
}

class _CachedNetworkCover extends StatefulWidget {
  const _CachedNetworkCover({
    required this.imageUrl,
    required this.width,
    required this.height,
    required this.placeholder,
    required this.fit,
    required this.forceRefresh,
  });

  final String imageUrl;
  final double width;
  final double height;
  final Widget placeholder;
  final BoxFit fit;
  final bool forceRefresh;

  @override
  State<_CachedNetworkCover> createState() => _CachedNetworkCoverState();
}

class _CachedNetworkCoverState extends State<_CachedNetworkCover> {
  String? _filePath;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _CachedNetworkCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.forceRefresh != widget.forceRefresh) {
      setState(() {
        _filePath = null;
        _loading = true;
      });
      _load();
    }
  }

  Future<void> _load() async {
    var file = await RemoteImageCache.instance.fileForUrl(
      widget.imageUrl,
      forceRefresh: widget.forceRefresh,
    );
  // Повтор: сервер мог только что извлечь обложку из MP3 при первом GET.
    if (file == null && !widget.forceRefresh) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      file = await RemoteImageCache.instance.fileForUrl(
        widget.imageUrl,
        forceRefresh: true,
      );
    }
    if (!mounted) return;
    setState(() {
      _filePath = file?.path;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _filePath == null) {
      return widget.placeholder;
    }
    final path = _filePath;
    if (path == null || path.isEmpty) {
      return widget.placeholder;
    }
    return buildCoverImageFromFile(
      path,
      widget.width,
      widget.height,
      BorderRadius.zero,
      widget.placeholder,
      widget.fit,
    );
  }
}
