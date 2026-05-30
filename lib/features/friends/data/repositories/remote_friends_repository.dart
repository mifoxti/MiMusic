import '../../../../core/network/friends_api.dart';
import '../../../../core/network/playlists_api.dart';
import '../../domain/entities/friend_incoming_request.dart';
import '../../domain/entities/friend_listening_state.dart';
import '../../domain/repositories/friends_repository.dart';

class RemoteFriendsRepository implements FriendsRepository {
  RemoteFriendsRepository({FriendsApi? api}) : _api = api ?? FriendsApi();

  final FriendsApi _api;

  @override
  Future<List<FriendListeningState>> getFriendsListening() async {
    final rows = await _api.fetchFriends();
    final bust = DateTime.now().millisecondsSinceEpoch;
    return rows.map((r) {
      final np = r.online ? r.nowPlaying : null;
      return FriendListeningState(
        userId: r.id,
        username: r.username,
        avatarUrl: userAvatarUrl(r.id, cacheBust: bust),
        online: r.online,
        trackTitle: np?.title ?? '',
        trackArtist: np?.artist ?? '',
        nowPlayingTrackId: np?.trackId,
        activeColistenRoomId: r.activeColistenRoomId,
      );
    }).toList();
  }

  @override
  Future<List<FriendIncomingRequest>> getIncomingRequests() async {
    final rows = await _api.fetchIncomingRequests();
    return rows
        .map(
          (e) => FriendIncomingRequest(
            fromUserId: e.fromUserId,
            nickname: e.nickname,
            createdAt: e.createdAt,
          ),
        )
        .toList();
  }

  @override
  Future<void> sendFriendRequest(int toUserId) => _api.sendFriendRequest(toUserId);

  @override
  Future<void> acceptFriendRequest(int fromUserId) => _api.acceptIncomingRequest(fromUserId);

  @override
  Future<void> declineFriendRequest(int fromUserId) => _api.declineIncomingRequest(fromUserId);

  @override
  Future<void> removeFriend(int friendId) => _api.removeFriend(friendId);
}
