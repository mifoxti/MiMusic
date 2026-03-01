import 'package:flutter/material.dart';

/// Обложка трека/релиза по URL или пути к asset.
/// [imageUrl] — null = заглушка; строка с http(s) = загрузка с сервера; иначе = asset.
/// Позже при подключении своего сервера достаточно подставлять URL в [imageUrl].
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
  final isNetwork = imageUrl.startsWith('http://') || imageUrl.startsWith('https://');
  return ClipRRect(
    borderRadius: borderRadius,
    child: SizedBox(
      width: width,
      height: height,
      child: isNetwork
          ? Image.network(
              imageUrl,
              fit: fit,
              width: width,
              height: height,
              errorBuilder: (context, error, stackTrace) => placeholder,
            )
          : Image.asset(
              imageUrl,
              fit: fit,
              width: width,
              height: height,
              errorBuilder: (context, error, stackTrace) => placeholder,
            ),
    ),
  );
}
