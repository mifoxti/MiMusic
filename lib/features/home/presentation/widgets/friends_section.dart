import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/cover_image.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/friend_playback.dart';
import '../../domain/entities/listening_friend.dart';

/// Секция «Подключиться к друзьям»: заголовок как название раздела, блок с подложкой прогресса трека.
class FriendsSection extends StatelessWidget {
  const FriendsSection({
    super.key,
    this.friendPlayback,
    this.listeningFriends = const [],
    this.trackProgress = 0.5,
    this.onConnectTap,
  });

  final FriendPlayback? friendPlayback;
  final List<ListeningFriend> listeningFriends;
  /// Прогресс трека, который слушают друзья (0.0..1.0). По умолчанию 50%.
  final double trackProgress;
  final VoidCallback? onConnectTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Подключиться к друзьям',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: palette.textPrimary,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onConnectTap,
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
              child: Stack(
                children: [
                  // Подложка: прогресс трека (слева — пройденная часть, справа — остаток)
                  Positioned.fill(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final progress = trackProgress.clamp(0.0, 1.0);
                        return Row(
                          children: [
                            SizedBox(
                              width: constraints.maxWidth * progress,
                              child: Container(color: palette.accent.withValues(alpha: 0.35)),
                            ),
                            Expanded(
                              child: Container(color: palette.primaryDark.withValues(alpha: 0.2)),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  // Контент поверх подложки: обложка — квадрат на всю высоту карточки, углы совпадают с карточкой
                  SizedBox(
                    height: 110,
                    child: Container(
                      padding: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        color: palette.cardBackground.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (friendPlayback != null)
                            _FriendPlaybackContent(playback: friendPlayback!),
                          if (friendPlayback != null) const SizedBox(width: 12),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Сейчас слушают:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: palette.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  _ListeningList(friends: listeningFriends.take(3).toList()),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Левая часть блока: квадратная обложка (углы совпадают с карточкой), рядом название и автор.
class _FriendPlaybackContent extends StatelessWidget {
  const _FriendPlaybackContent({required this.playback});

  final FriendPlayback playback;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    const radius = AppConstants.radiusLarge;
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.maxHeight.isFinite && constraints.maxHeight > 0
            ? constraints.maxHeight
            : 72.0;
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Квадратная обложка. coverUrl = null → заглушка; позже с сервера — URL в coverUrl.
            SizedBox(
              width: side,
              height: side,
              child: buildCoverImage(
                imageUrl: playback.coverUrl,
                width: side,
                height: side,
                borderRadius: BorderRadius.circular(radius),
                placeholder: Container(
                  color: palette.accent.withValues(alpha: 0.6),
                  alignment: Alignment.center,
                  child: const Icon(Icons.music_note, color: Colors.white54, size: 40),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Название трека и автор — рядом с обложкой, по центру по вертикали
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 6,
                      backgroundColor: palette.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
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
          ],
        );
      },
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
