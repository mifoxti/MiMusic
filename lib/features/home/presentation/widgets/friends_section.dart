import 'package:flutter/material.dart';

import '../../../../core/l10n/app_localization.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../presentation/widgets/colisten_listening_card.dart';
import '../../domain/entities/friend_playback.dart';
import '../../domain/entities/listening_friend.dart';

/// Секция «Подключиться к друзьям»: заголовок как название раздела, блок с подложкой прогресса трека.
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
    final playback = friendPlayback;
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
        ColistenListeningCard(
          title: playback?.title ?? '',
          artistName: playback?.artistName ?? '',
          coverUrl: playback?.coverUrl,
          listeners: listeningFriends,
          positionSeconds: playback?.positionSeconds ?? 0,
          durationSeconds: playback?.durationSeconds,
          playing: playback?.playing ?? false,
          wallClockMs: playback?.wallClockMs ?? 0,
          onTap: onConnectTap,
        ),
      ],
    );
  }
}
