import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

// --- copy_audio_to_app
Future<String?> copyPickedAudioToApp(String sourcePath, String trackId) async {
  try {
    final source = File(sourcePath);
    if (!await source.exists()) return null;
    final ext =
        sourcePath.contains('.') ? '.${sourcePath.split('.').last}' : '.mp3';
    final dir = await getApplicationDocumentsDirectory();
    final trackDir = Directory('${dir.path}/mimusic_tracks');
    await trackDir.create(recursive: true);
    final dest = File('${trackDir.path}/$trackId$ext');
    await source.copy(dest.path);
    return dest.path;
  } catch (_) {
    return null;
  }
}

// --- copy_cover_to_app
Future<String?> copyPickedCoverToApp(String sourcePath, String id) async {
  try {
    final source = File(sourcePath);
    if (!await source.exists()) return null;
    final ext =
        sourcePath.contains('.') ? '.${sourcePath.split('.').last}' : '.jpg';
    final dir = await getApplicationDocumentsDirectory();
    final coverDir = Directory('${dir.path}/mimusic_covers');
    await coverDir.create(recursive: true);
    final dest = File('${coverDir.path}/$id$ext');
    await source.copy(dest.path);
    return dest.path;
  } catch (_) {
    return null;
  }
}

// --- asset_to_uri
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

// --- audio_source_from_path
bool _isFilePath(String path) {
  if (path.startsWith('assets/')) return false;
  if (path.startsWith('/')) return true;
  if (path.length >= 2 && path[1] == ':') return true;
  return false;
}

AudioSource createAudioSource(String path) {
  if (_isFilePath(path)) {
    return AudioSource.file(path);
  }
  return AudioSource.asset(path);
}

// --- platform_utils
bool get isAndroid => Platform.isAndroid;

// --- cover_image_file
Widget buildCoverImageFromFile(
  String path,
  double width,
  double height,
  BorderRadius borderRadius,
  Widget placeholder,
  BoxFit fit,
) {
  final file = File(path);
  if (!file.existsSync()) return placeholder;
  return ClipRRect(
    borderRadius: borderRadius,
    child: SizedBox(
      width: width,
      height: height,
      child: Image.file(
        file,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (_, e, st) => placeholder,
      ),
    ),
  );
}

// --- studio_cover_image
Widget studioCoverImageFromFile(
  String path,
  double size,
  Widget placeholder,
) {
  final file = File(path);
  if (!file.existsSync()) return placeholder;
  return Image.file(
    file,
    width: size,
    height: size,
    fit: BoxFit.cover,
    errorBuilder: (_, error, stackTrace) => placeholder,
  );
}
