import 'dart:convert';
import 'dart:typed_data';

import '../audio/track.dart';
import 'api_config.dart';
import 'authenticated_dio.dart';

class ArtistSongDto {
  const ArtistSongDto({
    required this.id,
    required this.title,
    this.artist,
    this.coverBytes,
    this.isLiked = false,
  });

  final int id;
  final String title;
  final String? artist;
  final Uint8List? coverBytes;
  final bool isLiked;

  factory ArtistSongDto.fromJson(Map<String, dynamic> j) {
    Uint8List? coverBytes;
    final rawCover = j['coverArt'];
    if (rawCover is String && rawCover.isNotEmpty) {
      try {
        coverBytes = Uint8List.fromList(base64Decode(rawCover));
      } catch (_) {
        coverBytes = null;
      }
    }
    return ArtistSongDto(
      id: (j['id'] as num).toInt(),
      title: j['title'] as String? ?? '',
      artist: j['artist'] as String?,
      coverBytes: coverBytes,
      isLiked: j['isLiked'] as bool? ?? false,
    );
  }

  Track toTrack() {
    final b = ApiConfig.baseUrl.replaceAll(RegExp(r'/+$'), '');
    return Track(
      assetPath: 'server_track_$id',
      title: title,
      artist: artist,
      audioFilePath: '$b/tracks/$id/stream',
      coverBytes: coverBytes,
      coverAssetPath: '$b/tracks/$id/cover',
    );
  }
}

class ArtistProfileDto {
  const ArtistProfileDto({
    required this.thoughts,
    required this.songs,
  });

  final String thoughts;
  final List<ArtistSongDto> songs;

  factory ArtistProfileDto.fromJson(Map<String, dynamic> j) {
    final raw = j['songs'];
    return ArtistProfileDto(
      thoughts: j['thoughts'] as String? ?? '',
      songs: raw is List
          ? raw
              .map(
                (e) => ArtistSongDto.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList()
          : const [],
    );
  }
}

class ArtistApi {
  Future<ArtistProfileDto> fetchByName(String name, {int? userId}) async {
    final dio = await createAuthenticatedDio();
    final res = await dio.get<Map<String, dynamic>>(
      '/artist',
      queryParameters: {
        'name': name,
        if (userId != null) 'userId': userId,
      },
    );
    final data = res.data;
    if (data == null) {
      throw StateError('Empty artist response');
    }
    return ArtistProfileDto.fromJson(data);
  }
}
