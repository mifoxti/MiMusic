import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/audio/audio_player_service.dart';
import '../../core/auth/auth_session_store.dart';
import '../../core/constants/app_constants.dart';
import '../../core/l10n/app_localization.dart';
import '../../core/network/friends_api.dart';
import '../../core/network/notifications_api.dart';
import '../../core/network/playlists_api.dart';
import '../../core/social/colisten_controller.dart';
import '../../core/social/listening_room_session.dart';
import '../../core/player/player_dock_host.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/player/shell_route_back_guard.dart';
import 'user_public_profile_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({
    super.key,
    required this.currentUsername,
    required this.audioPlayerService,
    this.onUnreadChanged,
  });

  final String currentUsername;
  final AudioPlayerService audioPlayerService;
  final VoidCallback? onUnreadChanged;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<ServerNotificationDto> _items = [];
  bool _loading = true;
  String? _error;
  bool _loggedIn = false;

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
    final acc = await AuthSessionStore.readAccount();
    final token = acc?.sessionToken.trim() ?? '';
    if (token.isEmpty) {
      if (!mounted) return;
      setState(() {
        _loggedIn = false;
        _items = [];
        _loading = false;
      });
      widget.onUnreadChanged?.call();
      return;
    }
    try {
      final list = await NotificationsApi().fetchNotifications(limit: 100);
      if (!mounted) return;
      setState(() {
        _loggedIn = true;
        _items = list;
        _loading = false;
      });
      widget.onUnreadChanged?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _markRead(ServerNotificationDto n) async {
    try {
      await NotificationsApi().markRead(n.id);
      await _load();
    } catch (_) {}
  }

  Future<void> _onAccept(ServerNotificationDto n) async {
    final fromId = n.actorUserId ?? n.entityId;
    if (fromId == null) return;
    try {
      await FriendsApi().acceptIncomingRequest(fromId);
      await NotificationsApi().markRead(n.id);
      if (!mounted) return;
      await _load();
    } on DioException catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('common.errorLoading'))),
      );
    }
  }

  Future<void> _onDecline(ServerNotificationDto n) async {
    final fromId = n.actorUserId ?? n.entityId;
    if (fromId == null) return;
    try {
      await FriendsApi().declineIncomingRequest(fromId);
      await NotificationsApi().markRead(n.id);
      if (!mounted) return;
      await _load();
    } on DioException catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('common.errorLoading'))),
      );
    }
  }

  Future<void> _onJoinColisten(ServerNotificationDto n) async {
    final roomId = n.colistenRoomId;
    if (roomId == null || roomId.isEmpty) return;
    try {
      final acc = await AuthSessionStore.readAccount();
      final me = (acc?.nickname.trim().isNotEmpty ?? false)
          ? acc!.nickname
          : widget.currentUsername;
      final host = n.actorNickname ?? 'host';
      ListeningRoomSession.instance.start(
        roomTitle: '@$host',
        listeners: [me, host],
        hostUsername: host,
        currentUsername: me,
        privateRoom: false,
        pauseHostOnly: true,
        seekHostOnly: true,
        shuffleHostOnly: true,
        repeatHostOnly: true,
        skipHostOnly: true,
        playlistHostOnly: true,
        selectedPlaylists: const [],
        queue: const [],
      );
      await ColistenController.instance.connectGuest(
        roomId: roomId,
        audio: widget.audioPlayerService,
      );
      await NotificationsApi().markRead(n.id);
      if (!mounted) return;
      PlayerDockHost.expand();
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('common.errorLoading'))),
      );
    }
  }

  void _openActorProfile(ServerNotificationDto n) {
    final uid = n.actorUserId ?? n.entityId;
    if (uid == null) return;
    Navigator.of(context).push(
      ShellMaterialPageRoute<void>(
        builder: (_) => UserPublicProfilePage(
          userId: uid,
          nickname: n.actorNickname ?? '',
          audioPlayerService: widget.audioPlayerService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;

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
          actions: [
            if (_loggedIn && _items.any((e) => !e.read))
              TextButton(
                onPressed: () async {
                  try {
                    await NotificationsApi().markAllRead();
                    await _load();
                  } catch (_) {}
                },
                child: Text(context.t('notifications.markAllRead')),
              ),
          ],
        ),
        body: _loading
            ? Center(child: CircularProgressIndicator(color: palette.accent))
            : !_loggedIn
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        context.t('notifications.loginRequired'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: palette.textSecondary, fontSize: 16),
                      ),
                    ),
                  )
                : _error != null
                    ? Center(
                        child: Text(
                          _error!,
                          style: TextStyle(color: palette.textSecondary),
                        ),
                      )
                    : _items.isEmpty
                        ? Center(
                            child: Text(
                              context.t('notifications.empty'),
                              style: TextStyle(color: palette.textSecondary, fontSize: 16),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                              itemCount: _items.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final item = _items[index];
                                return Dismissible(
                                  key: ValueKey('n-${item.id}'),
                                  direction: DismissDirection.horizontal,
                                  background: _DismissBackground(
                                    palette: palette,
                                    alignment: Alignment.centerLeft,
                                    icon: Icons.done_all_rounded,
                                  ),
                                  secondaryBackground: _DismissBackground(
                                    palette: palette,
                                    alignment: Alignment.centerRight,
                                    icon: Icons.done_all_rounded,
                                  ),
                                  onDismissed: (_) => _markRead(item),
                                  child: _ServerNotificationCard(
                                    item: item,
                                    palette: palette,
                                    onAccept: !item.read
                                        ? (item.normalizedType == 'friend_request'
                                              ? () => _onAccept(item)
                                              : (item.normalizedType == 'colisten_invite'
                                                    ? () => _onJoinColisten(item)
                                                    : null))
                                        : null,
                                    onDecline: item.normalizedType == 'friend_request' && !item.read
                                        ? () => _onDecline(item)
                                        : null,
                                    onOpenProfile: () => _openActorProfile(item),
                                  ),
                                );
                              },
                            ),
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

class _ServerNotificationCard extends StatelessWidget {
  const _ServerNotificationCard({
    required this.item,
    required this.palette,
    required this.onAccept,
    required this.onDecline,
    required this.onOpenProfile,
  });

  final ServerNotificationDto item;
  final AppColorPalette palette;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback onOpenProfile;

  String _title(BuildContext context) {
    final nick = item.actorNickname ?? '?';
    final en = Localizations.localeOf(context).languageCode == 'en';
    switch (item.normalizedType) {
      case 'friend_request':
        return en
            ? '@$nick sent you a friend request'
            : '@$nick отправил(а) вам заявку в друзья';
      case 'friend_accepted':
        return en
            ? '@$nick accepted your friend request'
            : '@$nick принял(а) вашу заявку в друзья';
      case 'colisten_invite':
        return en
            ? '@$nick invited you to co-listen'
            : '@$nick пригласил(а) вас в совместное прослушивание';
      default:
        return en ? 'Notification' : 'Уведомление';
    }
  }

  String _status(BuildContext context) {
    if (item.read) {
      return Localizations.localeOf(context).languageCode == 'en' ? 'Read' : 'Прочитано';
    }
    if (item.normalizedType == 'friend_request') {
      return context.t('notifications.pending');
    }
    return context.t('notifications.pending');
  }

  @override
  Widget build(BuildContext context) {
    final bust = DateTime.now().millisecondsSinceEpoch;
    final uid = item.actorUserId ?? item.entityId;
    final avatarUrl = uid != null ? userAvatarUrl(uid, cacheBust: bust) : '';
    final nick = item.actorNickname ?? '?';

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
                    backgroundImage: uid != null && avatarUrl.isNotEmpty
                        ? NetworkImage(avatarUrl)
                        : null,
                    child: uid == null
                        ? Text(
                            nick.isNotEmpty ? nick[0].toUpperCase() : '?',
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _title(context),
                      maxLines: 3,
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
                _status(context),
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
                  if (item.normalizedType == 'friend_request' && onAccept != null && onDecline != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onDecline,
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
                        onPressed: onAccept,
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
                  if (item.normalizedType == 'colisten_invite') ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: onAccept,
                        child: Text(
                          Localizations.localeOf(context).languageCode == 'en'
                              ? 'Join'
                              : 'Подключиться',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
