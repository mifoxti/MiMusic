import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/friend_playback.dart';
import '../../domain/entities/listening_friend.dart';

/// Один блок «Подключиться к друзьям»: слева — заголовок и карточка друга, справа — «Сейчас слушают» с аватарками.
class FriendsSection extends StatelessWidget {
  const FriendsSection({
    super.key,
    this.friendPlayback,
    this.listeningFriends = const [],
    this.onConnectTap,
  });

  final FriendPlayback? friendPlayback;
  final List<ListeningFriend> listeningFriends;
  final VoidCallback? onConnectTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onConnectTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: palette.cardBackground,
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Подключиться к друзьям',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: palette.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    if (friendPlayback != null) ...[
                      const SizedBox(height: 12),
                      _FriendPlaybackContent(playback: friendPlayback!),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Сейчас слушают:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _ListeningList(friends: listeningFriends.take(3).toList()),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FriendPlaybackContent extends StatelessWidget {
  const _FriendPlaybackContent({required this.playback});

  final FriendPlayback playback;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: palette.accent.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.music_note, color: Colors.white54, size: 28),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                playback.title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: palette.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  CircleAvatar(
                    radius: 6,
                    backgroundColor: palette.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      playback.artistName,
                      style: TextStyle(
                        fontSize: 12,
                        color: palette.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

const _avatarShadow = [
  BoxShadow(
    color: Color(0x1A000000),
    blurRadius: 6,
    offset: Offset(0, 2),
  ),
];

/// Список «кто слушает»: аватарки слева, ники справа (как на скрине).
class _ListeningList extends StatelessWidget {
  const _ListeningList({required this.friends});

  final List<ListeningFriend> friends;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    const radius = 12.0;
    const overlap = 6.0;
    if (friends.isEmpty) {
      return const SizedBox.shrink();
    }
    final step = radius * 2 - overlap;
    return IntrinsicHeight(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _AvatarStack(friends: friends),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < friends.length; i++)
                SizedBox(
                  height: i < friends.length - 1 ? step : radius * 2,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      friends[i].username,
                      style: TextStyle(
                        fontSize: 13,
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.friends});

  final List<ListeningFriend> friends;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    const radius = 12.0;
    const overlap = 6.0;
    if (friends.isEmpty) {
      return const SizedBox.shrink();
    }
    final step = radius * 2 - overlap;
    final totalHeight = radius * 2 + (friends.length - 1) * step;
    return SizedBox(
      width: radius * 2,
      height: totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < friends.length; i++)
            Positioned(
              left: 0,
              top: i * step,
              child: Container(
                width: radius * 2,
                height: radius * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: palette.accent.withValues(alpha: 0.5),
                  boxShadow: _avatarShadow,
                ),
                alignment: Alignment.center,
                child: Text(
                  friends[i].username.isNotEmpty
                      ? friends[i].username[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontSize: 12,
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
