import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/l10n/app_localization.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_glass.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/cover_image.dart';
import '../../../../core/widgets/marquee_text.dart';
import '../../domain/entities/friend_playback.dart';
import '../../domain/entities/listening_friend.dart';

/// Секция «Подключиться к друзьям»: заголовок как название раздела, блок с подложкой прогресса трека.
class FriendsSection extends StatefulWidget {
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
  State<FriendsSection> createState() => _FriendsSectionState();
}

class _FriendsSectionState extends State<FriendsSection> {
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void didUpdateWidget(covariant FriendsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.friendPlayback != widget.friendPlayback) {
      _syncTimer();
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  void _syncTimer() {
    _progressTimer?.cancel();
    final playback = widget.friendPlayback;
    if (playback == null ||
        !playback.playing ||
        playback.durationSeconds == null) {
      return;
    }
    _progressTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  double get _trackProgress {
    final playback = widget.friendPlayback;
    final duration = playback?.durationSeconds;
    if (playback == null || duration == null || duration <= 0) return 0;
    var position = playback.positionSeconds;
    if (playback.playing && playback.wallClockMs > 0) {
      final elapsedMs =
          DateTime.now().millisecondsSinceEpoch - playback.wallClockMs;
      if (elapsedMs > 0) position += elapsedMs / 1000.0;
    }
    return (position / duration).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t('home.connectFriends'),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: palette.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onConnectTap,
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
              child: AppGlass.blurredTintLayer(
                isDark: isDark,
                child: Stack(
                  children: [
                    // Подложка: прогресс трека (слева — пройденная часть, справа — остаток)
                    Positioned.fill(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final progress = _trackProgress;
                          return Row(
                            children: [
                              SizedBox(
                                width: constraints.maxWidth * progress,
                                child: Container(
                                  color: palette.accent.withValues(alpha: 0.35),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  color: AppGlass.tint(
                                    isDark,
                                  ).withValues(alpha: 0.55),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    // Контент: слева обложка + название/автор, справа — блок друзей прижат к правому краю бокса
                    SizedBox(
                      height: 110,
                      child: Container(
                        padding: const EdgeInsets.only(
                          left: 12,
                          top: 10,
                          bottom: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppGlass.tint(isDark),
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusLarge,
                          ),
                          border: Border.all(color: AppGlass.border(isDark)),
                          boxShadow: AppGlass.cardShadows(isDark),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (widget.friendPlayback != null) ...[
                              _FriendPlaybackContent(
                                playback: widget.friendPlayback!,
                              ),
                              const SizedBox(width: 10),
                            ],
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: _TrackTitleMarquee(
                                  title: widget.friendPlayback?.title ?? '',
                                  artistName:
                                      widget.friendPlayback?.artistName ?? '',
                                  palette: palette,
                                ),
                              ),
                            ),
                            Flexible(
                              fit: FlexFit.loose,
                              child: Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 150,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        context.t('home.listeningNow'),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: palette.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      _ListeningList(
                                        friends: widget.listeningFriends
                                            .take(4)
                                            .toList(),
                                      ),
                                    ],
                                  ),
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
        ),
      ],
    );
  }
}

/// Левая часть: только квадратная обложка трека.
class _FriendPlaybackContent extends StatelessWidget {
  const _FriendPlaybackContent({required this.playback});

  final FriendPlayback playback;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    const radius = AppConstants.radiusLarge;
    const side = 90.0;
    return SizedBox(
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
    );
  }
}

/// Название и автор трека; при нехватке места текст крутится (бегущая строка).
class _TrackTitleMarquee extends StatelessWidget {
  const _TrackTitleMarquee({
    required this.title,
    required this.artistName,
    required this.palette,
  });

  final String title;
  final String artistName;
  final AppColorPalette palette;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MarqueeText(
          text: title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: palette.textPrimary,
          ),
        ),
        if (artistName.isNotEmpty) ...[
          const SizedBox(height: 4),
          MarqueeText(
            text: artistName,
            style: TextStyle(fontSize: 12, color: palette.textSecondary),
          ),
        ],
      ],
    );
  }
}

const _avatarShadow = [
  BoxShadow(color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 2)),
];

/// Список «кто слушает»: аватарки слева, ники справа. Масштабируется под ширину экрана.
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
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
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
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: _avatarShadow,
                ),
                child: ClipOval(
                  child: SizedBox(
                    width: radius * 2,
                    height: radius * 2,
                    child: _AvatarImage(friend: friends[i], palette: palette),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AvatarImage extends StatelessWidget {
  const _AvatarImage({required this.friend, required this.palette});

  final ListeningFriend friend;
  final AppColorPalette palette;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: palette.accent.withValues(alpha: 0.5),
      child: Center(
        child: Text(
          friend.username.isNotEmpty ? friend.username[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: 12,
            color: palette.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
    final avatarUrl = friend.avatarUrl;
    if (avatarUrl == null || avatarUrl.trim().isEmpty) return fallback;
    return Image.network(
      avatarUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}
