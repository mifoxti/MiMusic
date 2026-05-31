// ignore_for_file: avoid_print

import 'dart:io';

import 'package:image/image.dart' as img;

/// Замена фона иконки (чёрный, прозрачный или нейтральный).
/// Запуск: dart run tool/replace_app_icon_bg.dart [pink|darkpink|white|transparent]
void main(List<String> args) {
  final mode = args.isEmpty ? 'darkpink' : args.first.toLowerCase();
  const src = 'assets/icon/app_icon_source.png';
  const out = 'assets/icon/app_icon.png';

  final file = File(src);
  if (!file.existsSync()) {
    stderr.writeln('Missing $src — copy source PNG there first.');
    exit(1);
  }

  final image = img.decodeImage(file.readAsBytesSync());
  if (image == null) {
    stderr.writeln('Could not decode $src');
    exit(1);
  }

  final bg = switch (mode) {
    'white' => img.ColorRgba8(255, 255, 255, 255),
    'transparent' => img.ColorRgba8(0, 0, 0, 0),
    'pink' => img.ColorRgba8(253, 240, 244, 255), // gradientStart light
    'darkpink' => img.ColorRgba8(82, 61, 74, 255), // пастельно-тёмный розовый
    _ => throw ArgumentError('Use: pink | darkpink | white | transparent'),
  };

  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final p = image.getPixel(x, y);
      final r = p.r.toInt();
      final g = p.g.toInt();
      final b = p.b.toInt();
      final a = p.a.toInt();
      if (_isBackgroundPixel(r, g, b, a)) {
        image.setPixel(x, y, bg);
      }
    }
  }

  // 1024×1024 достаточно для launcher icons
  final resized = img.copyResize(image, width: 1024, height: 1024);
  File(out).writeAsBytesSync(img.encodePng(resized));
  print('Wrote $out ($mode background)');
}

bool _isBackgroundPixel(int r, int g, int b, int a) {
  if (a < 32) return true;
  final maxC = [r, g, b].reduce((a, c) => a > c ? a : c);
  final minC = [r, g, b].reduce((a, c) => a < c ? a : c);
  final chroma = maxC - minC;
  if (maxC < 48) return true;
  if (maxC < 90 && chroma < 28) return true;
  return false;
}
