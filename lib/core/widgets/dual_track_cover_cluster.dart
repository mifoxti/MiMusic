import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../audio/track.dart';
import 'cover_image.dart';
import 'track_cover.dart';

/// Две обложки треков (наложение): первые в списке, у которых есть cover.
List<({dynamic source})> pickTwoTrackCoverSources(List<Track> tracks) {
  final picked = <({dynamic source})>[];
  for (final t in tracks) {
    final src = t.coverBytes ?? t.coverAssetPath;
    if (src == null) continue;
    if (src is String && src.trim().isEmpty) continue;
    picked.add((source: src));
    if (picked.length >= 2) break;
  }
  return picked;
}

/// Две круглые обложки в стиле карточек «Для вас» / «Чарты».
class DualTrackCoverCluster extends StatelessWidget {
  const DualTrackCoverCluster({
    super.key,
    required this.covers,
    this.size = 88,
    this.overlap = 28,
    this.placeholderColor = const Color(0xFF5C4A50),
    this.placeholderColor2 = const Color(0xFF4A3D42),
  });

  final List<({dynamic source})> covers;
  final double size;
  final double overlap;
  final Color placeholderColor;
  final Color placeholderColor2;

  @override
  Widget build(BuildContext context) {
    final radius = size / 2;
    final totalWidth = size + (size - overlap);
    return SizedBox(
      width: totalWidth,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            top: 0,
            child: _coverCircle(
              covers.isNotEmpty ? covers[0].source : null,
              radius,
              placeholderColor,
            ),
          ),
          Positioned(
            left: size - overlap,
            top: 0,
            child: _coverCircle(
              covers.length > 1 ? covers[1].source : null,
              radius,
              placeholderColor2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _coverCircle(dynamic source, double radius, Color fallbackColor) {
    if (source == null) {
      return Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: fallbackColor.withValues(alpha: 0.75),
        ),
        child: const Icon(Icons.music_note_rounded, color: Colors.white70, size: 28),
      );
    }
    return ClipOval(
      child: SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: source is Uint8List || source is List<int>
            ? buildTrackCover(
                coverSource: source,
                width: radius * 2,
                height: radius * 2,
                borderRadius: BorderRadius.circular(radius),
                placeholder: _placeholder(radius, fallbackColor),
              )
            : buildCoverImage(
                imageUrl: source as String,
                width: radius * 2,
                height: radius * 2,
                borderRadius: BorderRadius.circular(radius),
                placeholder: _placeholder(radius, fallbackColor),
              ),
      ),
    );
  }

  Widget _placeholder(double radius, Color color) {
    return Container(
      color: color.withValues(alpha: 0.75),
      alignment: Alignment.center,
      child: const Icon(Icons.music_note_rounded, color: Colors.white70, size: 28),
    );
  }
}
