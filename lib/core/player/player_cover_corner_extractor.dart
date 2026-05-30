import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'player_cover_glass_colors.dart';

/// Насыщенный «характерный» цвет угла (не среднее по серому фону).
Color _accentColorInRegion(
  ByteData data,
  int width,
  int height,
  int x0,
  int y0,
  int x1,
  int y1,
) {
  Color? best;
  var bestScore = -1.0;
  var rSum = 0;
  var gSum = 0;
  var bSum = 0;
  var n = 0;

  for (var y = y0; y < y1; y++) {
    for (var x = x0; x < x1; x++) {
      final i = (y * width + x) * 4;
      final a = data.getUint8(i + 3);
      if (a < 40) continue;
      final r = data.getUint8(i);
      final g = data.getUint8(i + 1);
      final b = data.getUint8(i + 2);
      rSum += r;
      gSum += g;
      bSum += b;
      n++;

      final hsl = HSLColor.fromColor(Color.fromARGB(255, r, g, b));
      final sat = hsl.saturation;
      final light = hsl.lightness;
      if (light < 0.08 || light > 0.92) continue;
      final score = sat * (1.0 - (light - 0.45).abs() * 1.2);
      if (score > bestScore) {
        bestScore = score;
        best = Color.fromARGB(255, r, g, b);
      }
    }
  }

  if (best != null && bestScore > 0.12) return _normalizeCorner(best);
  if (n == 0) return PlayerCoverGlassColors.fallback.topLeft;
  return _normalizeCorner(
    Color.fromARGB(
      255,
      (rSum / n).round().clamp(0, 255),
      (gSum / n).round().clamp(0, 255),
      (bSum / n).round().clamp(0, 255),
    ),
  );
}

Color _normalizeCorner(Color c) {
  final hsl = HSLColor.fromColor(c);
  return hsl
      .withSaturation(hsl.saturation.clamp(0.45, 1.0))
      .withLightness(hsl.lightness.clamp(0.30, 0.55))
      .toColor();
}

/// Четыре угла обложки: TL, TR, BL, BR.
Future<PlayerCoverGlassColors?> extractCornerColorsFromBytes(
  Uint8List bytes,
) async {
  if (bytes.isEmpty) return null;
  try {
    const side = 64;
    const band = 22;
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: side,
      targetHeight: side,
    );
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    if (data == null) return null;

    return PlayerCoverGlassColors(
      topLeft: _accentColorInRegion(data, side, side, 0, 0, band, band),
      topRight: _accentColorInRegion(
        data,
        side,
        side,
        side - band,
        0,
        side,
        band,
      ),
      bottomLeft: _accentColorInRegion(
        data,
        side,
        side,
        0,
        side - band,
        band,
        side,
      ),
      bottomRight: _accentColorInRegion(
        data,
        side,
        side,
        side - band,
        side - band,
        side,
        side,
      ),
    );
  } catch (_) {
    return null;
  }
}
