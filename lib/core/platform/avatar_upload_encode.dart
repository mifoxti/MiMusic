import 'dart:math' as math;
import 'dart:io';
import 'dart:ui' as ui;

import 'package:path_provider/path_provider.dart';

/// Максимальная сторона перед кодированием в PNG (профильный аватар; меньше тело запроса и ответ сервера).
const int kAvatarUploadMaxEdgePx = 1024;

/// Декодирует изображение, при необходимости уменьшает длинную сторону до [kAvatarUploadMaxEdgePx],
/// кодирует в PNG для [POST /upload/avatar] (ImageIO на сервере).
Future<File> encodeImageFileToTempPngForAvatarUpload(File source) async {
  final bytes = await source.readAsBytes();
  var codec = await ui.instantiateImageCodec(bytes);
  var frame = await codec.getNextFrame();
  ui.Image img = frame.image;

  final iw = img.width;
  final ih = img.height;

  if (math.max(iw, ih) > kAvatarUploadMaxEdgePx) {
    img.dispose();
    codec.dispose();
    final int? tw = iw >= ih ? kAvatarUploadMaxEdgePx : null;
    final int? th = iw < ih ? kAvatarUploadMaxEdgePx : null;
    codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: tw,
      targetHeight: th,
    );
    frame = await codec.getNextFrame();
    img = frame.image;
  }

  try {
    final bd = await img.toByteData(format: ui.ImageByteFormat.png);
    if (bd == null) {
      throw StateError('avatar_encode_png');
    }
    final dir = await getTemporaryDirectory();
    final out = File(
      '${dir.path}/mimusic_avatar_upload_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await out.writeAsBytes(bd.buffer.asUint8List());
    return out;
  } finally {
    img.dispose();
    codec.dispose();
  }
}
