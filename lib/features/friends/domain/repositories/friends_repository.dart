import '../entities/friend_listening_state.dart';

abstract class FriendsRepository {
  Future<List<FriendListeningState>> getFriendsListening({
    required String currentUsername,
  });
}
