import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'cover_image.dart';

/// Обложка трека: поддерживает ID3 (байты), asset-путь или заглушку.
Widget buildTrackCover({
  required dynamic coverSource,
  required double width,
  required double height,
  required BorderRadius borderRadius,
  required Widget placeholder,
  BoxFit fit = BoxFit.cover,
}) {
  if (coverSource == null) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(width: width, height: height, child: placeholder),
    );
  }
  if (coverSource is List<int> || coverSource is Uint8List) {
    final bytes = coverSource is Uint8List ? coverSource : Uint8List.fromList(coverSource as List<int>);
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        width: width,
        height: height,
        child: Image.memory(
          bytes,
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (context, error, stackTrace) => placeholder,
        ),
      ),
    );
  }
  if (coverSource is String && coverSource.isNotEmpty) {
    return buildCoverImage(
      imageUrl: coverSource,
      width: width,
      height: height,
      borderRadius: borderRadius,
      placeholder: placeholder,
      fit: fit,
    );
  }
  return ClipRRect(
    borderRadius: borderRadius,
    child: SizedBox(width: width, height: height, child: placeholder),
  );
}
