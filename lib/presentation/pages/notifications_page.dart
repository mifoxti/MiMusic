import 'dart:async';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/audio/audio_player_service.dart';
import '../../core/auth/auth_session_store.dart';
import '../../core/constants/app_constants.dart';
import '../../core/l10n/app_localization.dart';
import '../../core/network/friends_api.dart';
import '../../core/network/api_config.dart';
import '../../core/network/notifications_api.dart';
import '../../core/network/playlists_api.dart';
import '../../core/network/server_connectivity.dart';
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
  final Set<int> _deletingIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool fromUser = false}) async {
    if (fromUser && mounted) {
      if (!await ServerConnectivity.instance.guardUserNetworkAction(context)) {
        setState(() => _loading = false);
        return;
      }
    }
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
      if (fromUser) {
        await ServerConnectivity.instance.reportNetworkErrorIfOffline(context, e);
      }
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _removeLocally(int id) {
    if (!mounted) return;
    setState(() {
      _items = _items.where((e) => e.id != id).toList();
      _deletingIds.remove(id);
    });
    widget.onUnreadChanged?.call();
  }

  Future<void> _deleteOne(ServerNotificationDto n) async {
    final id = n.id;
    if (_deletingIds.contains(id)) return;
    _deletingIds.add(id);
    _removeLocally(id);
    try {
      await NotificationsApi().deleteNotification(id);
    } catch (e) {
      if (!mounted) return;
      await ServerConnectivity.instance.reportNetworkErrorIfOffline(context, e);
      await _load();
    }
  }

  Future<void> _markAllRead() async {
    if (!await ServerConnectivity.instance.guardUserNetworkAction(context)) {
      return;
    }
    try {
      await NotificationsApi().markAllRead();
      if (!mounted) return;
      setState(() {
        _items = _items
            .map(
              (e) => ServerNotificationDto(
                id: e.id,
                type: e.type,
                actorUserId: e.actorUserId,
                actorNickname: e.actorNickname,
                read: true,
                createdAt: e.createdAt,
                entityRef: e.entityRef,
                entityId: e.entityId,
                payloadJson: e.payloadJson,
              ),
            )
            .toList();
      });
      widget.onUnreadChanged?.call();
    } catch (e) {
      if (!mounted) return;
      await ServerConnectivity.instance.reportNetworkErrorIfOffline(context, e);
    }
  }

  Future<void> _confirmDeleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final palette = AppPaletteExtension.of(ctx).palette;
        return AlertDialog(
          backgroundColor: palette.cardBackground,
          title: Text(context.t('notifications.deleteAllConfirmTitle')),
          content: Text(
            context.t('notifications.deleteAllConfirmBody'),
            style: TextStyle(color: palette.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.t('common.cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                context.t('notifications.deleteAllConfirm'),
                style: TextStyle(color: palette.accent),
              ),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    if (!await ServerConnectivity.instance.guardUserNetworkAction(context)) {
      return;
    }
    final snapshot = List<ServerNotificationDto>.from(_items);
    setState(() => _items = []);
    widget.onUnreadChanged?.call();
    try {
      await NotificationsApi().deleteAll();
    } catch (e) {
      if (!mounted) return;
      setState(() => _items = snapshot);
      widget.onUnreadChanged?.call();
      await ServerConnectivity.instance.reportNetworkErrorIfOffline(context, e);
    }
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t('common.errorLoading'))));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t('common.errorLoading'))));
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
        pauseHostOnly: false,
        seekHostOnly: false,
        shuffleHostOnly: false,
        repeatHostOnly: false,
        skipHostOnly: false,
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t('common.errorLoading'))));
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
            if (_loggedIn && _items.isNotEmpty) ...[
              if (_items.any((e) => !e.read))
                TextButton(
                  onPressed: _markAllRead,
                  child: Text(context.t('notifications.markAllRead')),
                ),
              TextButton(
                onPressed: _confirmDeleteAll,
                child: Text(context.t('notifications.deleteAll')),
              ),
            ],
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
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 16,
                    ),
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
                onRefresh: () => _load(fromUser: true),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  itemCount: _items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return Dismissible(
                      key: ValueKey('notification-${item.id}'),
                      direction: DismissDirection.horizontal,
                      background: _DismissBackground(
                        palette: palette,
                        alignment: Alignment.centerLeft,
                        icon: Icons.delete_outline_rounded,
                        destructive: true,
                      ),
                      secondaryBackground: _DismissBackground(
                        palette: palette,
                        alignment: Alignment.centerRight,
                        icon: Icons.delete_outline_rounded,
                        destructive: true,
                      ),
                      onDismissed: (_) => unawaited(_deleteOne(item)),
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
                        onDecline:
                            item.normalizedType == 'friend_request' &&
                                !item.read
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
    this.destructive = false,
  });

  final AppColorPalette palette;
  final Alignment alignment;
  final IconData icon;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final bg = destructive
        ? Colors.redAccent.withValues(alpha: 0.35)
        : palette.accent.withValues(alpha: 0.2);
    final fg = destructive ? Colors.red.shade900 : palette.textPrimary;
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
      ),
      child: Icon(icon, color: fg),
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
      case 'admin_message':
        final t = item.adminMessageTitle;
        if (t != null && t.isNotEmpty) return t;
        return en ? 'Message from MiMusic' : 'Сообщение от MiMusic';
      default:
        return en ? 'Notification' : 'Уведомление';
    }
  }

  String _status(BuildContext context) {
    if (item.read) {
      return Localizations.localeOf(context).languageCode == 'en'
          ? 'Read'
          : 'Прочитано';
    }
    if (item.normalizedType == 'friend_request') {
      return context.t('notifications.pending');
    }
    if (item.isAdminMessage) {
      final body = item.adminMessageBody;
      if (body != null && body.isNotEmpty) return body;
      return Localizations.localeOf(context).languageCode == 'en'
          ? 'Announcement'
          : 'Объявление';
    }
    return context.t('notifications.pending');
  }

  static String _absoluteMediaUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final b = ApiConfig.baseUrl.replaceAll(RegExp(r'/+$'), '');
    return path.startsWith('/') ? '$b$path' : '$b/$path';
  }

  List<Widget> _adminAttachments(
    BuildContext context,
    ServerNotificationDto item,
    AppColorPalette palette,
  ) {
    final en = Localizations.localeOf(context).languageCode == 'en';
    final widgets = <Widget>[];
    final imageUrl = item.adminMessageImageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      widgets.add(
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            _absoluteMediaUrl(imageUrl),
            height: 140,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
      );
    }
    final trackId = item.adminMessageTrackId;
    if (trackId != null) {
      widgets.add(
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                '${ApiConfig.baseUrl.replaceAll(RegExp(r'/+$'), '')}/tracks/$trackId/cover',
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox(width: 48, height: 48),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                en ? 'Attached track #$trackId' : 'Вложен трек #$trackId',
                style: TextStyle(color: palette.textSecondary, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }
    final playlistId = item.adminMessagePlaylistId;
    if (playlistId != null) {
      widgets.add(
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                playlistCoverUrl(playlistId),
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox(width: 48, height: 48),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                en ? 'Attached playlist #$playlistId' : 'Вложен плейлист #$playlistId',
                style: TextStyle(color: palette.textSecondary, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final bust = DateTime.now().millisecondsSinceEpoch;
    final uid = item.isAdminMessage ? null : (item.actorUserId ?? item.entityId);
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
              if (item.isAdminMessage) ...[
                const SizedBox(height: 10),
                ..._adminAttachments(context, item, palette),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  if (!item.isAdminMessage)
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
                  if (item.normalizedType == 'friend_request' &&
                      onAccept != null &&
                      onDecline != null) ...[
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
                          backgroundColor: palette.accent.withValues(
                            alpha: 0.78,
                          ),
                          disabledBackgroundColor: palette.primaryDark
                              .withValues(alpha: 0.45),
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
