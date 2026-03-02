import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

Future<Uri?> assetToFileUri(String assetPath) async {
  try {
    final data = await rootBundle.load(assetPath);
    final dir = await getTemporaryDirectory();
    final ext = assetPath.split('.').last;
    final file = File('${dir.path}/mimusic_cover.$ext');
    await file.writeAsBytes(data.buffer.asUint8List());
    return Uri.file(file.path);
  } catch (_) {
    return null;
  }
}
