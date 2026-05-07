import '../../domain/entities/friend_incoming_request.dart';
import '../../domain/entities/friend_listening_state.dart';
import '../../domain/repositories/friends_repository.dart';

class MockFriendsRepository implements FriendsRepository {
  @override
  Future<List<FriendListeningState>> getFriendsListening() async {
    return const [
      FriendListeningState(
        userId: 101,
        username: 'alexwave',
        avatarUrl: 'https://i.pravatar.cc/128?img=12',
        online: true,
        trackTitle: 'Why We Lose',
        trackArtist: 'Cartoon',
        nowPlayingTrackId: null,
        activeColistenRoomId: null,
      ),
      FriendListeningState(
        userId: 102,
        username: 'lofi_nora',
        avatarUrl: 'https://i.pravatar.cc/128?img=32',
        online: false,
        trackTitle: 'Lost Control',
        trackArtist: 'Gotarux',
        nowPlayingTrackId: null,
        activeColistenRoomId: null,
      ),
    ];
  }

  @override
  Future<List<FriendIncomingRequest>> getIncomingRequests() async => const [];

  @override
  Future<void> sendFriendRequest(int toUserId) async {}

  @override
  Future<void> acceptFriendRequest(int fromUserId) async {}

  @override
  Future<void> declineFriendRequest(int fromUserId) async {}

  @override
  Future<void> removeFriend(int friendId) async {}
}
