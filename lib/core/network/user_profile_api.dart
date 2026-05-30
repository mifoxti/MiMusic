import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'api_config.dart';

class UserNowPlayingDto {
  const UserNowPlayingDto({
    required this.trackId,
    required this.title,
    this.artist,
  });

  final int trackId;
  final String title;
  final String? artist;

  factory UserNowPlayingDto.fromJson(Map<String, dynamic> j) {
    return UserNowPlayingDto(
      trackId: (j['trackId'] as num).toInt(),
      title: j['title'] as String? ?? '',
      artist: j['artist'] as String?,
    );
  }
}

class UserPublicPlaylistDto {
  const UserPublicPlaylistDto({
    required this.id,
    this.title,
    this.isPublic,
    required this.trackCount,
    this.coverStorageKey,
  });

  final int id;
  final String? title;
  final bool? isPublic;
  final int trackCount;
  /// Если null/пусто — обложки нет, не дергаем [playlistCoverUrl].
  final String? coverStorageKey;

  factory UserPublicPlaylistDto.fromJson(Map<String, dynamic> j) {
    return UserPublicPlaylistDto(
      id: (j['id'] as num).toInt(),
      title: j['title'] as String?,
      isPublic: j['isPublic'] as bool?,
      trackCount: (j['trackCount'] as num?)?.toInt() ?? 0,
      coverStorageKey: j['coverStorageKey'] as String?,
    );
  }
}

class UserProfileThoughtDto {
  const UserProfileThoughtDto({
    required this.id,
    this.bodyText,
    this.createdAt,
    this.attachmentType,
    this.attachmentTrackId,
    this.attachmentPlaylistId,
    this.attachmentTrackTitle,
    this.attachmentTrackArtist,
    this.attachmentPlaylistTitle,
  });

  final int id;
  final String? bodyText;
  final String? createdAt;
  final int? attachmentType;
  final int? attachmentTrackId;
  final int? attachmentPlaylistId;
  final String? attachmentTrackTitle;
  final String? attachmentTrackArtist;
  final String? attachmentPlaylistTitle;

  factory UserProfileThoughtDto.fromJson(Map<String, dynamic> j) {
    return UserProfileThoughtDto(
      id: (j['id'] as num).toInt(),
      bodyText: j['bodyText'] as String?,
      createdAt: j['createdAt'] as String?,
      attachmentType: (j['attachmentType'] as num?)?.toInt(),
      attachmentTrackId: (j['attachmentTrackId'] as num?)?.toInt(),
      attachmentPlaylistId: (j['attachmentPlaylistId'] as num?)?.toInt(),
      attachmentTrackTitle: j['attachmentTrackTitle'] as String?,
      attachmentTrackArtist: j['attachmentTrackArtist'] as String?,
      attachmentPlaylistTitle: j['attachmentPlaylistTitle'] as String?,
    );
  }
}

class UserUploadedTrackDto {
  const UserUploadedTrackDto({
    required this.id,
    required this.title,
    this.artist,
    this.durationSec,
    this.genres = const [],
    this.coverBytes,
  });

  final int id;
  final String title;
  final String? artist;
  final int? durationSec;
  final List<String> genres;
  final Uint8List? coverBytes;

  factory UserUploadedTrackDto.fromJson(Map<String, dynamic> json) {
    final g = json['genres'];
    Uint8List? coverBytes;
    final rawCover = json['cover'];
    if (rawCover is String && rawCover.isNotEmpty) {
      try {
        coverBytes = Uint8List.fromList(base64Decode(rawCover));
      } catch (_) {
        coverBytes = null;
      }
    }
    return UserUploadedTrackDto(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String? ?? '',
      artist: json['artist'] as String?,
      durationSec: (json['duration'] as num?)?.toInt(),
      genres: g is List ? g.map((e) => e.toString()).toList() : const [],
      coverBytes: coverBytes,
    );
  }

  String streamUrl() {
    final b = ApiConfig.baseUrl.replaceAll(RegExp(r'/+$'), '');
    return '$b/tracks/$id/stream';
  }

  String coverUrl() {
    final b = ApiConfig.baseUrl.replaceAll(RegExp(r'/+$'), '');
    return '$b/tracks/$id/cover';
  }
}

class UserPublicProfileDto {
  const UserPublicProfileDto({
    required this.id,
    required this.nickname,
    this.bio,
    this.avatarStorageKey,
    this.online = false,
    this.nowPlaying,
    this.publicPlaylists = const [],
    this.uploadedTracks = const [],
    this.recentThoughts = const [],
  });

  final int id;
  final String nickname;
  final String? bio;
  final String? avatarStorageKey;
  final bool online;
  final UserNowPlayingDto? nowPlaying;
  final List<UserPublicPlaylistDto> publicPlaylists;
  final List<UserUploadedTrackDto> uploadedTracks;
  final List<UserProfileThoughtDto> recentThoughts;

  factory UserPublicProfileDto.fromJson(Map<String, dynamic> j) {
    final np = j['nowPlaying'];
    final online = j['online'] as bool? ?? false;
    final pl = j['publicPlaylists'];
    final tr = j['uploadedTracks'];
    final th = j['recentThoughts'];
    return UserPublicProfileDto(
      id: (j['id'] as num).toInt(),
      nickname: j['nickname'] as String? ?? '',
      bio: j['bio'] as String?,
      avatarStorageKey: j['avatarStorageKey'] as String?,
      online: online,
      nowPlaying: online && np is Map<String, dynamic>
          ? UserNowPlayingDto.fromJson(np)
          : null,
      publicPlaylists: pl is List
          ? pl.map((e) => UserPublicPlaylistDto.fromJson(Map<String, dynamic>.from(e as Map))).toList()
          : const [],
      uploadedTracks: tr is List
          ? tr.map((e) => UserUploadedTrackDto.fromJson(Map<String, dynamic>.from(e as Map))).toList()
          : const [],
      recentThoughts: th is List
          ? th.map((e) => UserProfileThoughtDto.fromJson(Map<String, dynamic>.from(e as Map))).toList()
          : const [],
    );
  }
}

class UserProfileApi {
  UserProfileApi({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: ApiConfig.baseUrl,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 30),
              ),
            );

  final Dio _dio;

  Future<UserPublicProfileDto> fetchPublicProfile(int userId) async {
    final res = await _dio.get<Map<String, dynamic>>('/users/$userId/profile');
    final data = res.data;
    if (data == null) throw StateError('Empty profile');
    return UserPublicProfileDto.fromJson(data);
  }
}
