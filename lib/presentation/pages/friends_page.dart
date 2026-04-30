import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/audio/audio_player_service.dart';
import '../../core/constants/app_constants.dart';
import '../../core/l10n/app_localization.dart';
import '../../core/theme/app_theme.dart';
import '../../features/friends/data/repositories/mock_friends_repository.dart';
import '../../features/friends/domain/repositories/friends_repository.dart';
import 'artist_page.dart';
import 'listening_room_page.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({
    super.key,
    required this.currentUsername,
    required this.audioPlayerService,
    this.repository,
  });

  final String currentUsername;
  final AudioPlayerService audioPlayerService;
  final FriendsRepository? repository;

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  late final FriendsRepository _repository =
      widget.repository ?? MockFriendsRepository();

  bool _loading = true;
  String? _error;
  List<_FriendVm> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _repository.getFriendsListening(
        currentUsername: widget.currentUsername,
      );
      if (!mounted) return;
      setState(() {
        _items = data
            .map(
              (e) => _FriendVm(
                username: e.username,
                avatarUrl: e.avatarUrl,
                trackTitle: e.trackTitle,
                trackArtist: e.trackArtist,
              ),
            )
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = context.t('common.errorLoading');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    final hasMiniPlayer = widget.audioPlayerService.currentTrack != null;
    final bottomInset = hasMiniPlayer
        ? AppConstants.shellBottomInsetWithMiniPlayer
        : AppConstants.shellBottomInset;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            palette.gradientStart,
            palette.gradientMiddle,
            palette.gradientEnd,
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text(
            Localizations.localeOf(context).languageCode == 'en'
                ? 'Friends'
                : 'Друзья',
          ),
        ),
        body: _loading
            ? Center(child: CircularProgressIndicator(color: palette.accent))
            : _error != null
                ? Center(
                    child: Text(
                      _error!,
                      style: TextStyle(color: palette.textSecondary),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return _FriendCard(
                          item: item,
                          onOpenProfile: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ArtistPage(
                                  artistName: item.username,
                                  coverImageUrl: item.avatarUrl.isEmpty
                                      ? null
                                      : item.avatarUrl,
                                  audioPlayerService: widget.audioPlayerService,
                                ),
                              ),
                            );
                          },
                          onOpenRoom: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                settings: const RouteSettings(
                                  name: ListeningRoomPage.routeName,
                                ),
                                builder: (_) => const ListeningRoomPage(),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}

class _FriendCard extends StatelessWidget {
  const _FriendCard({
    required this.item,
    required this.onOpenProfile,
    required this.onOpenRoom,
  });

  final _FriendVm item;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenRoom;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    final initial = item.username.isNotEmpty ? item.username[0].toUpperCase() : '?';
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.cardBackground.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
            border: Border.all(
              color: palette.textPrimary.withValues(alpha: 0.14),
            ),
          ),
          child: Row(
            children: [
              InkWell(
                onTap: onOpenProfile,
                borderRadius: BorderRadius.circular(24),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: palette.accent.withValues(alpha: 0.24),
                  backgroundImage:
                      item.avatarUrl.isNotEmpty ? NetworkImage(item.avatarUrl) : null,
                  child: item.avatarUrl.isNotEmpty
                      ? null
                      : Text(
                          initial,
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '@${item.username}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.trackArtist} — ${item.trackTitle}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onOpenRoom,
                icon: const Icon(Icons.headphones_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: palette.accent.withValues(alpha: 0.2),
                  foregroundColor: palette.accent,
                ),
                tooltip: Localizations.localeOf(context).languageCode == 'en'
                    ? 'Listening room'
                    : 'Совместное прослушивание',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FriendVm {
  const _FriendVm({
    required this.username,
    required this.avatarUrl,
    required this.trackTitle,
    required this.trackArtist,
  });

  final String username;
  final String avatarUrl;
  final String trackTitle;
  final String trackArtist;
}
