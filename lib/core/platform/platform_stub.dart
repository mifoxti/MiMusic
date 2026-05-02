import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

// --- copy_audio_to_app
Future<String?> copyPickedAudioToApp(String sourcePath, String trackId) async =>
    null;

// --- copy_cover_to_app
Future<String?> saveCoverBytesToApp(List<int> bytes, String id, String extension) async =>
    null;

Future<String?> copyPickedCoverToApp(String sourcePath, String id) async =>
    null;

// --- asset_to_uri
Future<Uri?> assetToFileUri(String assetPath) async => null;

// --- audio_source_from_path
AudioSource createAudioSource(String path) {
  if (!path.startsWith('assets/')) {
    throw UnsupportedError(
      'Воспроизведение из файла недоступно на этой платформе',
    );
  }
  return AudioSource.asset(path);
}

// --- platform_utils
bool get isAndroid => false;

// --- cover_image_file
Widget buildCoverImageFromFile(
  String path,
  double width,
  double height,
  BorderRadius borderRadius,
  Widget placeholder,
  BoxFit fit,
) {
  return ClipRRect(
    borderRadius: borderRadius,
    child: SizedBox(width: width, height: height, child: placeholder),
  );
}

// --- studio_cover_image
Widget studioCoverImageFromFile(
  String path,
  double size,
  Widget placeholder,
) {
  return placeholder;
}
