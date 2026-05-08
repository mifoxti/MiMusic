import '../../../../core/network/colisten_api.dart';
import '../../../../core/network/friends_api.dart';
import '../../../../core/network/playlists_api.dart';
import '../../../../core/network/tracks_api.dart';
import '../../../../core/auth/auth_session_store.dart';
import '../../domain/entities/friend_playback.dart';
import '../../domain/entities/home_section.dart';
import '../../domain/entities/listening_friend.dart';
import '../../domain/entities/recommended_playlist.dart';
import '../../domain/entities/release_item.dart';
import '../../domain/repositories/home_repository.dart';

/// Реализация репозитория главного экрана (заглушка с мок-данными).
class HomeRepositoryImpl implements HomeRepository {
  @override
  Future<HomeSection> getHomeSection() async {
    final liveRoom = await _loadFriendListeningRoom();
    // Сейчас — картинки из assets для превью. Позже заменим на URL с сервера.
    return HomeSection(
      historyArtists: const ['Sibewest', 'ETERNVL SVDNESS', 'ENSKA'],
      friendPlayback: liveRoom?.playback,
      listeningFriends: liveRoom?.friends ?? const [],
      latestReleases: const [
        ReleaseItem(
          title: 'Koc Bloem Care, Pt. 1',
          coverUrl: 'assets/images/stardust.png',
        ),
        ReleaseItem(title: 'Release 2', coverUrl: 'assets/images/identity.png'),
        ReleaseItem(title: 'Release 3', coverUrl: 'assets/images/geoxor.png'),
      ],
      featuredTrackTitle: 'your fears',
      featuredTrackCoverAsset: 'assets/images/xploson.png',
      recommendedTrackAssetPaths: const [
        'assets/music/Cartoon - Why We Lose - Cartoon.mp3',
        'assets/music/Gotarux - Lost Control.mp3',
      ],
      recommendedPlaylists: const [
        RecommendedPlaylist(
          id: 'pl_lofi_evening',
          title: 'Lo-Fi Evening',
          coverUrl: 'assets/images/identity.png',
        ),
        RecommendedPlaylist(
          id: 'pl_night_drive',
          title: 'Night Drive',
          coverUrl: 'assets/images/stardust.png',
        ),
      ],
      recommendedArtists: const [
        ListeningFriend(
          username: 'alexwave',
          avatarUrl: 'assets/images/identity.png',
        ),
        ListeningFriend(
          username: 'lofi_nora',
          avatarUrl: 'assets/images/geoxor.png',
        ),
        ListeningFriend(
          username: 'nightcore_anna',
          avatarUrl: 'assets/images/stardust.png',
        ),
      ],
      recommendedAlbums: const [
        ReleaseItem(title: 'SilverDust', coverUrl: 'assets/images/geoxor.png'),
        ReleaseItem(title: 'Heal her', coverUrl: 'assets/images/heal_her.png'),
      ],
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
