import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'platform.dart';

String _coverExtensionFromPicker(PlatformFile file) {
  final name = file.name;
  final dot = name.lastIndexOf('.');
  if (dot != -1 && dot < name.length - 1) {
    return name.substring(dot);
  }
  return '.jpg';
}

String _audioExtensionFromPicker(PlatformFile file) {
  final name = file.name;
  final dot = name.lastIndexOf('.');
  if (dot != -1 && dot < name.length - 1) {
    return name.substring(dot);
  }
  return '.mp3';
}

/// Убирает фокус и даёт кадр на стабилизацию UI — пикер поверх [AlertDialog] на Android
/// провоцирует лишние временные копии в галерее.
Future<void> _prepareFilePickerSurface() async {
  FocusManager.instance.primaryFocus?.unfocus();
  await WidgetsBinding.instance.endOfFrame;
  await Future<void>.delayed(const Duration(milliseconds: 120));
}

Future<void> _clearPickerTemporaryFilesBestEffort() async {
  if (kIsWeb) return;
  try {
    await FilePicker.platform.clearTemporaryFiles();
  } catch (_) {}
}

/// Picks an image and copies it into private app storage without relying on a
/// potentially media-scanned temporary path when bytes are available.
Future<String?> pickAndSaveCoverImage(String id) async {
  await _prepareFilePickerSurface();

  final result = await FilePicker.platform.pickFiles(
    type: FileType.image,
    withData: true,
    allowCompression: false,
    compressionQuality: 100,
  );
  if (result == null || result.files.isEmpty) return null;
  final file = result.files.single;

  Uint8List? data = file.bytes;

  if (kIsWeb) {
    if (data == null || data.isEmpty) return null;
    final saved = await saveCoverBytesToApp(data, id, _coverExtensionFromPicker(file));
    if (saved != null) await _clearPickerTemporaryFilesBestEffort();
    return saved;
  }

  if (data == null || data.isEmpty) {
    try {
      data = await file.xFile.readAsBytes();
    } catch (_) {}
  }
  if (data != null && data.isNotEmpty) {
    final saved = await saveCoverBytesToApp(data, id, _coverExtensionFromPicker(file));
    if (saved != null) await _clearPickerTemporaryFilesBestEffort();
    return saved;
  }

  final path = file.path;
  if (path != null && path.isNotEmpty && !path.startsWith('content://')) {
    final saved = await copyPickedCoverToApp(path, id);
    if (saved != null) await _clearPickerTemporaryFilesBestEffort();
    return saved;
  }
  return null;
}

/// Выбор аудиофайла для трека студии: те же ограничения, что и для обложек (content://, сжатие).
Future<String?> pickAndSaveTrackAudio(String trackId) async {
  await _prepareFilePickerSurface();

  final result = await FilePicker.platform.pickFiles(
    type: FileType.audio,
    withData: true,
    allowCompression: false,
    compressionQuality: 100,
  );
  if (result == null || result.files.isEmpty) return null;
  final file = result.files.single;

  Uint8List? data = file.bytes;

  if (kIsWeb) {
    if (data == null || data.isEmpty) return null;
    final saved = await saveAudioBytesToApp(data, trackId, _audioExtensionFromPicker(file));
    if (saved != null) await _clearPickerTemporaryFilesBestEffort();
    return saved;
  }

  if (data == null || data.isEmpty) {
    try {
      data = await file.xFile.readAsBytes();
    } catch (_) {}
  }
  if (data != null && data.isNotEmpty) {
    final saved = await saveAudioBytesToApp(data, trackId, _audioExtensionFromPicker(file));
    if (saved != null) await _clearPickerTemporaryFilesBestEffort();
    return saved;
  }

  final path = file.path;
  if (path != null && path.isNotEmpty && !path.startsWith('content://')) {
    final saved = await copyPickedAudioToApp(path, trackId);
    if (saved != null) await _clearPickerTemporaryFilesBestEffort();
    return saved;
  }
  return null;
}
