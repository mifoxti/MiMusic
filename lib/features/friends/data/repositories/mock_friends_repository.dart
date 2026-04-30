import '../../domain/entities/friend_listening_state.dart';
import '../../domain/repositories/friends_repository.dart';

class MockFriendsRepository implements FriendsRepository {
  @override
  Future<List<FriendListeningState>> getFriendsListening({
    required String currentUsername,
  }) async {
    // TODO(server): replace with API-backed repository.
    return const [
      FriendListeningState(
        username: 'alexwave',
        avatarUrl: 'https://i.pravatar.cc/128?img=12',
        trackTitle: 'Why We Lose',
        trackArtist: 'Cartoon',
      ),
      FriendListeningState(
        username: 'lofi_nora',
        avatarUrl: 'https://i.pravatar.cc/128?img=32',
        trackTitle: 'Lost Control',
        trackArtist: 'Gotarux',
      ),
      FriendListeningState(
        username: 'nightcore_anna',
        avatarUrl: 'https://i.pravatar.cc/128?img=45',
        trackTitle: 'Hero',
        trackArtist: 'Skillet',
      ),
    ];
  }
}
