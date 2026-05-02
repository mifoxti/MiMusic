import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

String _fileExtension(String sourcePath, String fallback) {
  final lastDot = sourcePath.lastIndexOf('.');
  if (lastDot == -1 || lastDot == sourcePath.length - 1) return fallback;
  return sourcePath.substring(lastDot);
}

Future<Directory> _appMediaDirectory(String folderName) async {
  final supportDir = await getApplicationSupportDirectory();
  final target = Directory('${supportDir.path}/$folderName');
  await target.create(recursive: true);
  if (Platform.isAndroid) {
    final nomedia = File('${target.path}/.nomedia');
    if (!nomedia.existsSync()) {
      nomedia.writeAsStringSync('');
    }
  }
  return target;
}

Future<void> _removeSiblingVariants({
  required Directory directory,
  required String fileId,
}) async {
  final entries = directory.listSync(followLinks: false);
  for (final entry in entries) {
    if (entry is! File) continue;
    final name = entry.uri.pathSegments.isNotEmpty
        ? entry.uri.pathSegments.last
        : '';
    if (name.startsWith('$fileId.')) {
      try {
        entry.deleteSync();
      } catch (_) {}
    }
  }
}

// --- copy_audio_to_app
Future<String?> copyPickedAudioToApp(String sourcePath, String trackId) async {
  try {
    final source = File(sourcePath);
    if (!await source.exists()) return null;
    final ext = _fileExtension(sourcePath, '.mp3');
    final trackDir = await _appMediaDirectory('mimusic_tracks');
    await _removeSiblingVariants(directory: trackDir, fileId: trackId);
    final dest = File('${trackDir.path}/$trackId$ext');
    await source.copy(dest.path);
    return dest.path;
  } catch (_) {
    return null;
  }
}

/// Writes image bytes directly into app-private storage (avoids gallery indexing
/// from picker cache paths on some Android versions).
Future<String?> saveCoverBytesToApp(List<int> bytes, String id, String extension) async {
  try {
    if (bytes.isEmpty) return null;
    var ext = extension.trim();
    if (ext.isEmpty) ext = '.jpg';
    if (!ext.startsWith('.')) ext = '.$ext';
    final coverDir = await _appMediaDirectory('mimusic_covers');
    await _removeSiblingVariants(directory: coverDir, fileId: id);
    final dest = File('${coverDir.path}/$id$ext');
    await dest.writeAsBytes(bytes, flush: true);
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
    final ext = _fileExtension(sourcePath, '.jpg');
    final coverDir = await _appMediaDirectory('mimusic_covers');
    await _removeSiblingVariants(directory: coverDir, fileId: id);
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
