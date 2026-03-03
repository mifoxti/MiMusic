import 'package:flutter/material.dart';

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
/// [imageUrl] — null = заглушка; http(s) = сеть; файловый путь = с диска; иначе = asset.
Widget buildCoverImage({
  required String? imageUrl,
  required double width,
  required double height,
  required BorderRadius borderRadius,
  required Widget placeholder,
  BoxFit fit = BoxFit.cover,
}) {
  if (imageUrl == null || imageUrl.isEmpty) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(width: width, height: height, child: placeholder),
    );
  }
  if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
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
          errorBuilder: (context, error, stackTrace) => placeholder,
        ),
      ),
    );
  }
  if (_isFilePath(imageUrl)) {
    return buildCoverImageFromFile(imageUrl, width, height, borderRadius, placeholder, fit);
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
