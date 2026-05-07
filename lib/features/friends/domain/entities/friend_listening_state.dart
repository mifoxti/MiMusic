class FriendListeningState {
  const FriendListeningState({
    required this.userId,
    required this.username,
    required this.avatarUrl,
    required this.online,
    required this.trackTitle,
    required this.trackArtist,
    this.trackCoverUrl,
    this.nowPlayingTrackId,
    this.activeColistenRoomId,
  });

  final int userId;
  final String username;
  final String avatarUrl;
  final bool online;
  final String trackTitle;
  final String trackArtist;
  final String? trackCoverUrl;

  /// Id трека на сервере, если друг слушает каталог; иначе `null` (локальный fallback).
  final int? nowPlayingTrackId;

  /// Комната Colisten на сервере (если друг сейчас в активной комнате).
  final String? activeColistenRoomId;
}
