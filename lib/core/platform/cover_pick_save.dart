import 'package:file_picker/file_picker.dart';

import 'platform.dart';

String _coverExtensionFromPicker(PlatformFile file) {
  final name = file.name;
  final dot = name.lastIndexOf('.');
  if (dot != -1 && dot < name.length - 1) {
    return name.substring(dot);
  }
  return '.jpg';
}

/// Picks an image and copies it into private app storage without relying on a
/// potentially media-scanned temporary path when bytes are available.
Future<String?> pickAndSaveCoverImage(String id) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.image,
    withData: true,
  );
  if (result == null || result.files.isEmpty) return null;
  final file = result.files.single;
  final bytes = file.bytes;
  if (bytes != null && bytes.isNotEmpty) {
    final ext = _coverExtensionFromPicker(file);
    return saveCoverBytesToApp(bytes, id, ext);
  }
  final path = file.path;
  if (path != null && path.isNotEmpty) {
    return copyPickedCoverToApp(path, id);
  }
  return null;
}
