import '../entities/friend_incoming_request.dart';
import '../entities/friend_listening_state.dart';

abstract class FriendsRepository {
  Future<List<FriendListeningState>> getFriendsListening();

  Future<List<FriendIncomingRequest>> getIncomingRequests();

  Future<void> sendFriendRequest(int toUserId);

  Future<void> acceptFriendRequest(int fromUserId);

  Future<void> declineFriendRequest(int fromUserId);

  Future<void> removeFriend(int friendId);
}
