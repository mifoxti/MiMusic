import 'friend_playback.dart';
import 'listening_friend.dart';
import 'recommended_playlist.dart';
import 'release_item.dart';

/// Модель данных для главного экрана (агрегат секций).
class HomeSection {
  const HomeSection({
    this.historyArtists = const [],
    this.friendPlayback,
    this.listeningFriends = const [],
    this.latestReleases = const [],
    this.featuredTrackTitle,
    this.featuredTrackCoverAsset,
    this.recommendedTrackAssetPaths = const [],
    this.recommendedPlaylists = const [],
    this.recommendedArtists = const [],
    this.recommendedAlbums = const [],
    this.isPlaying = false,
  });

  final List<String> historyArtists;
  final FriendPlayback? friendPlayback;
  final List<ListeningFriend> listeningFriends;
  final List<ReleaseItem> latestReleases;
  final String? featuredTrackTitle;
  /// Путь к обложке текущего трека в мини-плеере (например, assets/images/cover.png).
  final String? featuredTrackCoverAsset;
  final List<String> recommendedTrackAssetPaths;
  final List<RecommendedPlaylist> recommendedPlaylists;
  final List<ListeningFriend> recommendedArtists;
  final List<ReleaseItem> recommendedAlbums;
  final bool isPlaying;
}
