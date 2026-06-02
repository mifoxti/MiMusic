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
    final acc = await AuthSessionStore.readAccount();
    final loggedIn =
        acc != null && acc.sessionToken.trim().isNotEmpty && acc.userId != null;

    final roomFuture = _loadFriendListeningRoom();
    final releasesFuture = loggedIn ? _loadLatestReleases() : Future.value(const <ReleaseItem>[]);
    final recFuture = loggedIn
        ? _loadRecommendedTracks()
        : Future.value(const <HomeRecommendedTrack>[]);
    final playlistsFuture = loggedIn && acc.userId != null
        ? _loadRecommendedPlaylistsAndArtists(acc.userId!)
        : Future.value((
            playlists: const <RecommendedPlaylist>[],
            artists: const <ListeningFriend>[],
          ));

    final results = await Future.wait<Object?>([
      roomFuture,
      releasesFuture,
      recFuture,
      playlistsFuture,
    ]);

    final liveRoom = results[0] as _FriendRoomPreview?;
    final latestReleases = results[1]! as List<ReleaseItem>;
    final recommendedServerTracks = results[2]! as List<HomeRecommendedTrack>;
    final plBundle = results[3]! as ({List<RecommendedPlaylist> playlists, List<ListeningFriend> artists});
    final recommendedPlaylists = plBundle.playlists;
    final recommendedArtists = plBundle.artists;

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

  Future<List<ReleaseItem>> _loadLatestReleases() async {
    try {
      final catalog = await TracksApi().fetchTracks(limit: 8);
      return catalog
          .map(
            (t) => ReleaseItem(
              title: t.title,
              coverUrl: t.coverUrl(),
              trackId: t.id,
              artist: t.artist,
            ),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<HomeRecommendedTrack>> _loadRecommendedTracks() async {
    try {
      final rec = await RecommendationsApi().fetchRecommendedTracks(limit: 12);
      return rec
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
    } catch (_) {
      return const [];
    }
  }

  Future<({List<RecommendedPlaylist> playlists, List<ListeningFriend> artists})>
      _loadRecommendedPlaylistsAndArtists(int myUserId) async {
    var playlists = const <RecommendedPlaylist>[];
    var artists = const <ListeningFriend>[];
    List<PublicPlaylistItemRemote>? public;

    try {
      public = await PlaylistsApi().fetchPublicPlaylists(limit: 8);
      playlists = public
          .map(
            (p) => RecommendedPlaylist(
              id: 'srv:${p.id}',
              title: p.title ?? 'Playlist',
              coverUrl: playlistCoverUrl(p.id),
            ),
          )
          .toList();
    } catch (_) {}

    artists = await _loadRecommendedUploaders(myUserId);

    if (artists.isEmpty && public != null) {
      final seen = <int>{};
      artists = public
          .where((p) => p.ownerUserId != myUserId)
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
    }

    return (playlists: playlists, artists: artists);
  }

  /// Загрузчики: API recent-uploaders → уникальные uploader из каталога треков → пусто.
  Future<List<ListeningFriend>> _loadRecommendedUploaders(int myUserId) async {
    try {
      final uploaders = await TracksApi().fetchRecentUploaders(limit: 8);
      if (uploaders.isNotEmpty) {
        return uploaders
            .where((u) => u.userId != myUserId)
            .map(
              (u) => ListeningFriend(
                username: u.nickname,
                avatarUrl: userAvatarUrl(u.userId),
                userId: u.userId,
              ),
            )
            .take(8)
            .toList();
      }
    } catch (_) {}

    try {
      final tracks = await TracksApi().fetchTracks(limit: 48);
      final seen = <int>{};
      final fromTracks = <ListeningFriend>[];
      for (final t in tracks) {
        final uid = t.uploaderUserId;
        if (uid == null || uid == myUserId || !seen.add(uid)) continue;
        fromTracks.add(
          ListeningFriend(
            username: (t.uploaderNickname?.trim().isNotEmpty ?? false)
                ? t.uploaderNickname!.trim()
                : 'user_$uid',
            avatarUrl: userAvatarUrl(uid),
            userId: uid,
          ),
        );
        if (fromTracks.length >= 8) break;
      }
      if (fromTracks.isNotEmpty) return fromTracks;
    } catch (_) {}

    return const [];
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
      // Пробуем все комнаты друзей (не только самую «популярную») — первая живая на сервере.
      final roomCandidates = grouped.entries.toList()
        ..sort((a, b) => b.value.length.compareTo(a.value.length));
      ColistenRoomStateDto? room;
      List<FriendRemoteDto>? selectedFriends;
      for (final entry in roomCandidates) {
        try {
          room = await ColistenApi().getRoomState(entry.key);
          selectedFriends = entry.value;
          break;
        } catch (_) {
          continue;
        }
      }
      if (room == null || selectedFriends == null) return null;
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
      for (final friend in selectedFriends) {
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
          (track?.title ?? selectedFriends.first.nowPlaying?.title ?? '').trim();
      if (title.isEmpty) return null;
      final artist =
          (track?.artist ?? selectedFriends.first.nowPlaying?.artist ?? '')
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
