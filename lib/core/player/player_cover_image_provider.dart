import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio/track.dart';
import '../cache/remote_image_cache.dart';
import '../network/tracks_api.dart';
import '../network/tracks_upload_api.dart';

bool _isFilePath(String path) {
  if (path.startsWith('http://') || path.startsWith('https://')) return false;
  if (path.startsWith('assets/')) return false;
  if (path.startsWith('/')) return true;
  if (path.length >= 2 && path[1] == ':') return true;
  return false;
}

int? _serverTrackIdFromTrack(Track track) {
  final fromAsset = TracksApi().parseServerTrackId(track.assetPath);
  if (fromAsset != null) return fromAsset;
  final path = track.coverFallbackPath ?? '';
  final m = RegExp(r'/tracks/(\d+)/cover').firstMatch(path);
  if (m != null) return int.tryParse(m.group(1)!);
  return null;
}

Future<Uint8List?> _fetchCoverBytesFromUrl(String url) async {
  if (kIsWeb) return null;
  final file = await RemoteImageCache.instance.fileForUrl(
    url,
    requireAuth: false,
  );
  if (file != null && await file.exists() && await file.length() > 0) {
    return file.readAsBytes();
  }
  return null;
}

/// Байты обложки для палитры (те же источники, что и у [buildTrackCover]).
Future<Uint8List?> loadCoverBytesForTrack(Track track) async {
  final embedded = track.coverBytes;
  if (embedded != null && embedded.isNotEmpty) return embedded;

  final serverId = _serverTrackIdFromTrack(track);
  if (serverId != null) {
    final fromApi = await TracksUploadApi.fetchTrackCoverBytes(serverId);
    if (fromApi != null && fromApi.isNotEmpty) return fromApi;
  }

  final path = track.coverFallbackPath;
  if (path == null || path.isEmpty) return null;

  if (path.startsWith('http://') || path.startsWith('https://')) {
    return _fetchCoverBytesFromUrl(path);
  }
  if (_isFilePath(path)) {
    final file = File(path);
    if (await file.exists()) {
      return file.readAsBytes();
    }
    return null;
  }
  if (path.startsWith('assets/')) {
    try {
      final data = await rootBundle.load(path);
      return data.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }
  try {
    final data = await rootBundle.load(path);
    return data.buffer.asUint8List();
  } catch (_) {
    return null;
  }
}

/// @deprecated Используйте [loadCoverBytesForTrack].
Future<ImageProvider?> coverImageProviderForTrack(Track track) async {
  final bytes = await loadCoverBytesForTrack(track);
  if (bytes != null && bytes.isNotEmpty) return MemoryImage(bytes);
  return null;
}

String coverPaletteCacheKey(Track track) {
  final bytes = track.coverBytes;
  if (bytes != null && bytes.isNotEmpty) {
    return '${track.assetPath}:b${bytes.length}:${bytes.first}:${bytes.last}';
  }
  final path = track.coverFallbackPath ?? '';
  return '${track.assetPath}:p$path';
}
