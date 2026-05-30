import '../../../../core/auth/auth_session_store.dart';
import '../../../../core/network/colisten_api.dart';
import '../../../../core/network/friends_api.dart';
import '../../../../core/network/playlists_api.dart';
import '../../../../core/network/recommendations_api.dart';
import '../../../../core/network/tracks_api.dart';
import '../../domain/entities/friend_playback.dart';
import '../../domain/entities/home_section.dart';
import '../../domain/entities/home_recommended_track.dart';
import '../../domain/entities/listening_friend.dart';
import '../../domain/entities/recommended_playlist.dart';
import '../../domain/entities/release_item.dart';
import '../../domain/repositories/home_repository.dart';

/// Главная: друзья в colisten, релизы и рекомендации с API при входе.
class HomeRepositoryImpl implements HomeRepository {
  @override
  Future<HomeSection> getHomeSection() async {
    final liveRoom = await _loadFriendListeningRoom();
    final acc = await AuthSessionStore.readAccount();
    final loggedIn =
        acc != null && acc.sessionToken.trim().isNotEmpty && acc.userId != null;

    var latestReleases = const <ReleaseItem>[];
    var recommendedServerTracks = const <HomeRecommendedTrack>[];
    var recommendedPlaylists = const <RecommendedPlaylist>[];
    var recommendedArtists = const <ListeningFriend>[];

    if (loggedIn) {
      try {
        final catalog = await TracksApi().fetchTracks(limit: 8);
        latestReleases = catalog
            .map(
              (t) => ReleaseItem(
                title: t.title,
                coverUrl: t.coverUrl(),
                trackId: t.id,
                artist: t.artist,
              ),
            )
            .toList();
      } catch (_) {}

      try {
        final rec = await RecommendationsApi().fetchRecommendedTracks(limit: 12);
        recommendedServerTracks = rec
            .map(
              (t) => HomeRecommendedTrack(
                id: t.id,
                title: t.title,
                artist: t.artist,
                coverUrl: t.coverUrl(),
                score: t.score,
              ),
            )
            .toList();
      } catch (_) {}

      try {
        final public = await PlaylistsApi().fetchPublicPlaylists(limit: 8);
        recommendedPlaylists = public
            .map(
              (p) => RecommendedPlaylist(
                id: 'srv:${p.id}',
                title: p.title ?? 'Playlist',
                coverUrl: playlistCoverUrl(p.id),
              ),
            )
            .toList();
        final myUserId = acc.userId;
        final seen = <int>{};
        recommendedArtists = public
            .where((p) => myUserId == null || p.ownerUserId != myUserId)
            .where((p) => seen.add(p.ownerUserId))
            .take(6)
            .map(
              (p) => ListeningFriend(
                username: p.ownerNickname ?? 'user_${p.ownerUserId}',
                avatarUrl: userAvatarUrl(p.ownerUserId),
                userId: p.ownerUserId,
              ),
            )
            .toList();
      } catch (_) {}
    }

    final historyArtists = latestReleases
        .map((e) => (e.artist ?? '').trim())
        .where((e) => e.isNotEmpty)
        .take(3)
        .toList();

    return HomeSection(
      historyArtists: historyArtists,
      friendPlayback: liveRoom?.playback,
      listeningFriends: liveRoom?.friends ?? const [],
      latestReleases: latestReleases,
      recommendedServerTracks: recommendedServerTracks,
      recommendedPlaylists: recommendedPlaylists,
      recommendedArtists: recommendedArtists,
      isPlaying: true,
    );
  }

  Future<_FriendRoomPreview?> _loadFriendListeningRoom() async {
    try {
      final friends = await FriendsApi().fetchFriends();
      final activeFriends = friends
          .where(
            (friend) => (friend.activeColistenRoomId ?? '').trim().isNotEmpty,
          )
          .toList();
      if (activeFriends.isEmpty) return null;

      final grouped = <String, List<FriendRemoteDto>>{};
      for (final friend in activeFriends) {
        final roomId = friend.activeColistenRoomId!.trim();
        grouped.putIfAbsent(roomId, () => <FriendRemoteDto>[]).add(friend);
      }
      final selected = grouped.entries.reduce(
        (a, b) => a.value.length >= b.value.length ? a : b,
      );

      final room = await ColistenApi().getRoomState(selected.key);
      ServerTrackListItem? track;
      final trackId = room.trackId;
      if (trackId != null) {
        try {
          track = await TracksApi().fetchTrackById(trackId);
        } catch (_) {}
      }

      final friendById = {for (final friend in friends) friend.id: friend};
      final listeners = <ListeningFriend>[];
      final account = await AuthSessionStore.readAccount();
      final myUserId = account?.userId;
      final myNickname = account?.nickname.trim() ?? '';
      for (final userId in room.participantIds) {
        if (myUserId != null &&
            userId == myUserId &&
            myNickname.isNotEmpty &&
            !listeners.any((listener) => listener.userId == myUserId)) {
          listeners.add(
            ListeningFriend(
              username: myNickname,
              avatarUrl: userAvatarUrl(myUserId),
              userId: myUserId,
            ),
          );
          continue;
        }
        final friend = friendById[userId];
        if (friend == null) continue;
        listeners.add(
          ListeningFriend(
            username: friend.username,
            avatarUrl: userAvatarUrl(friend.id),
            userId: friend.id,
          ),
        );
      }
      for (final friend in selected.value) {
        if (listeners.any((listener) => listener.userId == friend.id)) continue;
        listeners.add(
          ListeningFriend(
            username: friend.username,
            avatarUrl: userAvatarUrl(friend.id),
            userId: friend.id,
          ),
        );
      }
      if (listeners.isEmpty) return null;

      final title =
          (track?.title ?? selected.value.first.nowPlaying?.title ?? '').trim();
      if (title.isEmpty) return null;
      final artist =
          (track?.artist ?? selected.value.first.nowPlaying?.artist ?? '')
              .trim();
      return _FriendRoomPreview(
        playback: FriendPlayback(
          title: title,
          artistName: artist,
          coverUrl: track?.coverUrl(),
          activeRoomId: room.roomId,
          positionSeconds: room.positionSeconds,
          durationSeconds: track?.durationSec,
          playing: room.playing,
          wallClockMs: room.wallClockMs,
        ),
        friends: listeners,
      );
    } catch (_) {
      return null;
    }
  }
}

class _FriendRoomPreview {
  const _FriendRoomPreview({required this.playback, required this.friends});

  final FriendPlayback playback;
  final List<ListeningFriend> friends;
}
