import '../../domain/entities/friend_playback.dart';
import '../../domain/entities/home_section.dart';
import '../../domain/entities/listening_friend.dart';
import '../../domain/entities/release_item.dart';
import '../../domain/repositories/home_repository.dart';

/// Реализация репозитория главного экрана (заглушка с мок-данными).
class HomeRepositoryImpl implements HomeRepository {
  @override
  Future<HomeSection> getHomeSection() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return const HomeSection(
      historyArtists: ['Sibewest', 'ETERNVL SVDNESS', 'ENSKA'],
      friendPlayback: FriendPlayback(
        title: 'Doki Doki',
        artistName: 'Kaito Shoma',
      ),
      listeningFriends: [
        ListeningFriend(username: 'Kardiboba'),
        ListeningFriend(username: 'dockfr10'),
        ListeningFriend(username: 'AzukiNHG'),
      ],
      latestReleases: [
        ReleaseItem(title: 'Koc Bloem Care, Pt. 1'),
        ReleaseItem(title: 'Release 2'),
        ReleaseItem(title: 'Release 3'),
      ],
      featuredTrackTitle: 'your fears',
      isPlaying: true,
    );
  }
}
