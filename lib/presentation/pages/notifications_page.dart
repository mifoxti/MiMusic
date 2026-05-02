import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/audio/audio_player_service.dart';
import '../../core/constants/app_constants.dart';
import '../../core/l10n/app_localization.dart';
import '../../core/social/friend_request_notifications.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/player/shell_route_back_guard.dart';
import 'artist_page.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({
    super.key,
    required this.currentUsername,
    required this.audioPlayerService,
  });

  final String currentUsername;
  final AudioPlayerService audioPlayerService;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    final center = FriendRequestNotifications.instance;
    center.seedDemoIfNeeded(currentUsername);

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
          title: Text(context.t('notifications.title')),
        ),
        body: AnimatedBuilder(
          animation: center,
          builder: (context, _) {
            final items = center.allFor(currentUsername);
            if (items.isEmpty) {
              return Center(
                child: Text(
                  context.t('notifications.empty'),
                  style: TextStyle(color: palette.textSecondary, fontSize: 16),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = items[index];
                return Dismissible(
                  key: ValueKey(item.id),
                  direction: DismissDirection.horizontal,
                  background: _DismissBackground(
                    palette: palette,
                    alignment: Alignment.centerLeft,
                    icon: Icons.delete_outline_rounded,
                  ),
                  secondaryBackground: _DismissBackground(
                    palette: palette,
                    alignment: Alignment.centerRight,
                    icon: Icons.delete_outline_rounded,
                  ),
                  onDismissed: (_) => center.remove(item.id),
                  child: _NotificationCard(
                    item: item,
                    palette: palette,
                    onAccept: item.status == FriendRequestStatus.pending
                        ? () => center.setStatus(
                              notificationId: item.id,
                              status: FriendRequestStatus.accepted,
                            )
                        : null,
                    onDecline: item.status == FriendRequestStatus.pending
                        ? () => center.setStatus(
                              notificationId: item.id,
                              status: FriendRequestStatus.declined,
                            )
                        : null,
                    onOpenProfile: () {
                      Navigator.of(context).push(
                        ShellMaterialPageRoute<void>(
                          builder: (_) => ArtistPage(
                            artistName: item.fromUsername,
                            audioPlayerService: audioPlayerService,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _DismissBackground extends StatelessWidget {
  const _DismissBackground({
    required this.palette,
    required this.alignment,
    required this.icon,
  });

  final AppColorPalette palette;
  final Alignment alignment;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: palette.accent.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
      ),
      child: Icon(icon, color: palette.textPrimary),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.item,
    required this.palette,
    required this.onAccept,
    required this.onDecline,
    required this.onOpenProfile,
  });

  final FriendRequestNotification item;
  final AppColorPalette palette;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: palette.accent.withValues(alpha: 0.22),
                    backgroundImage: (item.fromAvatarUrl ?? '').isNotEmpty
                        ? NetworkImage(item.fromAvatarUrl!)
                        : null,
                    child: (item.fromAvatarUrl ?? '').isNotEmpty
                        ? null
                        : Text(
                            item.fromUsername.isNotEmpty
                                ? item.fromUsername[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      Localizations.localeOf(context).languageCode == 'en'
                          ? '@${item.fromUsername} sent you a friend request'
                          : '@${item.fromUsername} отправил(а) вам заявку в друзья',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: palette.textPrimary,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _statusLabel(context, item.status),
                style: TextStyle(
                  fontSize: 13,
                  color: palette.textSecondary,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: onOpenProfile,
                      style: TextButton.styleFrom(
                        foregroundColor: palette.textPrimary,
                        textStyle: const TextStyle(
                          decoration: TextDecoration.none,
                        ),
                      ),
                      child: Text(context.t('notifications.openProfile')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: item.status == FriendRequestStatus.pending
                          ? onDecline
                          : null,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: palette.textPrimary,
                        side: BorderSide(
                          color: palette.textSecondary.withValues(alpha: 0.5),
                        ),
                        textStyle: const TextStyle(
                          decoration: TextDecoration.none,
                        ),
                      ),
                      child: const Icon(Icons.close_rounded),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed:
                          item.status == FriendRequestStatus.pending
                          ? onAccept
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: palette.accent.withValues(alpha: 0.78),
                        disabledBackgroundColor:
                            palette.primaryDark.withValues(alpha: 0.45),
                        textStyle: const TextStyle(
                          decoration: TextDecoration.none,
                        ),
                      ),
                      child: const Icon(Icons.check_rounded),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _statusLabel(BuildContext context, FriendRequestStatus status) {
    switch (status) {
      case FriendRequestStatus.pending:
        return context.t('notifications.pending');
      case FriendRequestStatus.accepted:
        return context.t('notifications.accepted');
      case FriendRequestStatus.declined:
        return context.t('notifications.declined');
    }
  }
}
