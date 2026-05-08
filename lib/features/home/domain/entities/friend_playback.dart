/// Трек, который сейчас слушает друг.
class FriendPlayback {
  const FriendPlayback({
    required this.title,
    required this.artistName,
    this.coverUrl,
    this.activeRoomId,
    this.positionSeconds = 0,
    this.durationSeconds,
    this.playing = false,
    this.wallClockMs = 0,
  });

  final String title;
  final String artistName;
  final String? coverUrl;
  final String? activeRoomId;
  final double positionSeconds;
  final int? durationSeconds;
  final bool playing;
  final int wallClockMs;
}
