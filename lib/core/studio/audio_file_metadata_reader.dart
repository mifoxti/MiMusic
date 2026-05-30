import 'dart:io';

import 'package:audiotags/audiotags.dart';
import 'package:flutter/foundation.dart';

import '../platform/platform.dart';

/// Результат разбора локального аудиофайла (теги + запасной разбор имени файла).
class ParsedAudioFileMetadata {
  const ParsedAudioFileMetadata({
    this.title,
    this.primaryArtist,
    this.coAuthors = const [],
    this.coverPath,
    this.hadEmbeddedTags = false,
    this.usedFilenameFallback = false,
  });

  final String? title;
  final String? primaryArtist;
  final List<String> coAuthors;

  /// Путь к сохранённой в приложении обложке из тегов.
  final String? coverPath;
  final bool hadEmbeddedTags;
  final bool usedFilenameFallback;

  bool get hasSuggestions =>
      (title != null && title!.trim().isNotEmpty) ||
      (primaryArtist != null && primaryArtist!.trim().isNotEmpty) ||
      coAuthors.isNotEmpty ||
      (coverPath != null && coverPath!.isNotEmpty);
}

class AudioFileMetadataReader {
  AudioFileMetadataReader._();

  static final AudioFileMetadataReader instance = AudioFileMetadataReader._();

  Future<ParsedAudioFileMetadata> read({
    required String audioFilePath,
    required String studioAssetId,
  }) async {
    if (audioFilePath.trim().isEmpty) {
      return const ParsedAudioFileMetadata();
    }

    ParsedAudioFileMetadata? fromTags;
    if (!kIsWeb) {
      try {
        final f = File(audioFilePath);
        if (await f.exists()) {
          fromTags = await _readWithAudiotags(audioFilePath, studioAssetId);
        }
      } catch (_) {}
    }

    if (fromTags != null && fromTags.hasSuggestions) {
      return fromTags;
    }

    final fromName = _parseFromFileName(audioFilePath);
    if (fromTags != null) {
      return ParsedAudioFileMetadata(
        title: fromTags.title ?? fromName.title,
        primaryArtist: fromTags.primaryArtist ?? fromName.primaryArtist,
        coAuthors: fromTags.coAuthors.isNotEmpty ? fromTags.coAuthors : fromName.coAuthors,
        coverPath: fromTags.coverPath ?? fromName.coverPath,
        hadEmbeddedTags: fromTags.hadEmbeddedTags,
        usedFilenameFallback: fromName.hasSuggestions,
      );
    }
    return fromName;
  }

  Future<ParsedAudioFileMetadata?> _readWithAudiotags(
    String path,
    String studioAssetId,
  ) async {
    final tag = await AudioTags.read(path);
    if (tag == null) return null;

    var title = _clean(tag.title);
    var artistLine = _clean(tag.trackArtist) ?? _clean(tag.albumArtist);
    final (primary, coAuthors) = _splitArtists(artistLine);

    String? coverPath;
    final pictures = tag.pictures;
    if (pictures.isNotEmpty) {
      final pic = pictures.first;
      final bytes = pic.bytes;
      if (bytes.isNotEmpty) {
        final ext = _coverExtFromMime(pic.mimeType?.name);
        coverPath = await saveCoverBytesToApp(bytes, studioAssetId, ext);
      }
    }

    final hadTags = title != null ||
        primary != null ||
        coAuthors.isNotEmpty ||
        coverPath != null;

    return ParsedAudioFileMetadata(
      title: title,
      primaryArtist: primary,
      coAuthors: coAuthors,
      coverPath: coverPath,
      hadEmbeddedTags: hadTags,
    );
  }

  ParsedAudioFileMetadata _parseFromFileName(String path) {
    final fileName = path.split(RegExp(r'[/\\]')).last;
    final baseName = fileName.replaceAll(
      RegExp(r'\.(mp3|m4a|mp4|flac|ogg|opus|wav|aac|wma|aiff|aif|alac)$', caseSensitive: false),
      '',
    );
    if (baseName.trim().isEmpty) {
      return const ParsedAudioFileMetadata(usedFilenameFallback: true);
    }

    final dash = baseName.indexOf(' - ');
    if (dash >= 0) {
      final artistPart = baseName.substring(0, dash).trim();
      final titlePart = baseName.substring(dash + 3).trim();
      final (primary, co) = _splitArtists(artistPart);
      return ParsedAudioFileMetadata(
        title: titlePart.isEmpty ? null : titlePart,
        primaryArtist: primary,
        coAuthors: co,
        usedFilenameFallback: true,
      );
    }

    return ParsedAudioFileMetadata(
      title: baseName.trim(),
      usedFilenameFallback: true,
    );
  }

  static String? _clean(String? raw) {
    if (raw == null) return null;
    final t = raw.trim();
    return t.isEmpty ? null : t;
  }

  static (String? primary, List<String> coAuthors) _splitArtists(String? line) {
    if (line == null || line.trim().isEmpty) {
      return (null, const []);
    }
    var normalized = line.trim();
    for (final sep in [' feat. ', ' ft. ', ' featuring ', ' & ']) {
      normalized = normalized.replaceAll(RegExp(sep, caseSensitive: false), ', ');
    }
    final parts = normalized
        .split(RegExp(r'[,;/]|\s+and\s+', caseSensitive: false))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return (null, const []);
    if (parts.length == 1) return (parts.first, const []);
    return (parts.first, parts.sublist(1));
  }

  static String _coverExtFromMime(String? mime) {
    final m = (mime ?? '').toLowerCase();
    if (m.contains('png')) return '.png';
    if (m.contains('webp')) return '.webp';
    if (m.contains('gif')) return '.gif';
    return '.jpg';
  }
}
