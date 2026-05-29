import 'dart:ui';
import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/audio/audio_player_service.dart';
import '../../core/auth/auth_session_store.dart';
import '../../core/network/server_connectivity.dart';
import '../../core/constants/app_constants.dart';
import '../../core/l10n/app_localization.dart';
import '../../core/player/player_dock_host.dart';
import '../../core/player/shell_route_back_guard.dart';
import '../../core/social/colisten_controller.dart';
import '../../core/social/listening_room_session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../features/friends/data/repositories/mock_friends_repository.dart';
import '../../features/friends/data/repositories/remote_friends_repository.dart';
import '../../features/friends/domain/entities/friend_incoming_request.dart';
import '../../features/friends/domain/entities/friend_listening_state.dart';
import '../../features/friends/domain/repositories/friends_repository.dart';
import 'user_public_profile_page.dart';

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
  bool _loading = true;
  String? _error;
  List<FriendListeningState> _friends = const [];
  List<FriendIncomingRequest> _incoming = const [];
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!mounted) return;
      unawaited(_load(silent: true));
    });
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      if (!mounted) return;
      if (!await ServerConnectivity.instance.guardUserNetworkAction(context)) {
        setState(() => _loading = false);
        return;
      }
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      if (widget.repository != null) {
        final repo = widget.repository!;
        final f = await repo.getFriendsListening();
        final inc = await repo.getIncomingRequests();
        if (!mounted) return;
        setState(() {
          _friends = f;
          _incoming = inc;
          _loading = false;
        });
        return;
      }
      final acc = await AuthSessionStore.readAccount();
      if (acc?.sessionToken.trim().isEmpty ?? true) {
        final mock = MockFriendsRepository();
        final data = await mock.getFriendsListening();
        if (!mounted) return;
        setState(() {
          _friends = data;
          _incoming = const [];
          _loading = false;
        });
        return;
      }
      final FriendsRepository repo = RemoteFriendsRepository();
      final f = await repo.getFriendsListening();
      final inc = await repo.getIncomingRequests();
      if (!mounted) return;
      setState(() {
        _friends = f;
        _incoming = inc;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (!silent) {
        await ServerConnectivity.instance.reportNetworkErrorIfOffline(context, e);
      }
      setState(() {
        _error = context.t('common.errorLoading');
        _loading = false;
      });
    }
  }

  Future<void> _accept(FriendIncomingRequest r) async {
    try {
      final repo = widget.repository ?? RemoteFriendsRepository();
      await repo.acceptFriendRequest(r.fromUserId);
      if (!mounted) return;
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('common.errorLoading'))),
      );
    }
  }

  Future<void> _decline(FriendIncomingRequest r) async {
    try {
      final repo = widget.repository ?? RemoteFriendsRepository();
      await repo.declineFriendRequest(r.fromUserId);
      if (!mounted) return;
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('common.errorLoading'))),
      );
    }
  }

  Future<void> _connectToFriendListening(FriendListeningState friend) async {
    final roomId = friend.activeColistenRoomId;
    if (roomId != null && roomId.isNotEmpty) {
      try {
        ListeningRoomSession.instance.start(
          roomTitle: '@${friend.username}',
          listeners: [widget.currentUsername, friend.username],
          hostUsername: friend.username,
          currentUsername: widget.currentUsername,
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
        PlayerDockHost.expand();
        return;
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('common.errorLoading'))),
        );
        return;
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(context.t('friends.listenHint')),
      ),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
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
          title: Text(context.t('friends.title')),
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
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset),
                      children: [
                        if (_incoming.isNotEmpty) ...[
                          Text(
                            context.t('friends.incomingTitle'),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: palette.textPrimary,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ..._incoming.map(
                            (r) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _IncomingCard(
                                palette: palette,
                                nickname: r.nickname,
                                onAccept: () => _accept(r),
                                onDecline: () => _decline(r),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (_friends.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 24),
                            child: Center(
                              child: Text(
                                context.t('friends.emptyFriends'),
                                style: TextStyle(color: palette.textSecondary),
                              ),
                            ),
                          )
                        else
                          ..._friends.map(
                            (f) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _FriendCard(
                                friend: f,
                                onOpenProfile: () {
                                  Navigator.of(context).push(
                                    ShellMaterialPageRoute<void>(
                                      builder: (_) => UserPublicProfilePage(
                                        userId: f.userId,
                                        nickname: f.username,
                                        audioPlayerService: widget.audioPlayerService,
                                      ),
                                    ),
                                  );
                                },
                                onOpenRoom: () => _connectToFriendListening(f),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _IncomingCard extends StatelessWidget {
  const _IncomingCard({
    required this.palette,
    required this.nickname,
    required this.onAccept,
    required this.onDecline,
  });

  final AppColorPalette palette;
  final String nickname;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

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
            border: Border.all(color: palette.textPrimary.withValues(alpha: 0.14)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '@$nickname',
                  style: TextStyle(fontWeight: FontWeight.w700, color: palette.textPrimary),
                ),
              ),
              TextButton(onPressed: onDecline, child: Text(context.t('friends.decline'))),
              FilledButton(onPressed: onAccept, child: Text(context.t('friends.accept'))),
            ],
          ),
        ),
      ),
    );
  }
}

class _FriendCard extends StatelessWidget {
  const _FriendCard({
    required this.friend,
    required this.onOpenProfile,
    required this.onOpenRoom,
  });

  final FriendListeningState friend;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenRoom;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    final initial = friend.username.isNotEmpty ? friend.username[0].toUpperCase() : '?';
    final hasActiveRoom =
        friend.activeColistenRoomId != null &&
        friend.activeColistenRoomId!.trim().isNotEmpty;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.cardBackground.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
            border: Border.all(color: palette.textPrimary.withValues(alpha: 0.14)),
          ),
          child: Row(
            children: [
              InkWell(
                onTap: onOpenProfile,
                borderRadius: BorderRadius.circular(24),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: palette.accent.withValues(alpha: 0.24),
                  backgroundImage: friend.avatarUrl.isNotEmpty ? NetworkImage(friend.avatarUrl) : null,
                  child: friend.avatarUrl.isNotEmpty
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
                      '@${friend.username}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      friend.online
                          ? (Localizations.localeOf(context).languageCode == 'en'
                                ? 'Online'
                                : 'В сети')
                          : (Localizations.localeOf(context).languageCode == 'en'
                                ? 'Offline'
                                : 'Не в сети'),
                      style: TextStyle(
                        color: friend.online
                            ? palette.accent
                            : palette.textMuted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      friend.trackTitle.isEmpty
                          ? (Localizations.localeOf(context).languageCode == 'en'
                                ? 'Not listening now'
                                : 'Сейчас ничего не слушает')
                          : (friend.trackArtist.isNotEmpty
                                ? '${friend.trackArtist} — ${friend.trackTitle}'
                                : friend.trackTitle),
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
                onPressed: hasActiveRoom ? onOpenRoom : null,
                icon: const Icon(Icons.headphones_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: palette.accent.withValues(alpha: 0.2),
                  foregroundColor: palette.accent,
                ),
                tooltip: hasActiveRoom
                    ? context.t('friends.listenHint')
                    : (Localizations.localeOf(context).languageCode == 'en'
                          ? 'Not in co-listen room'
                          : 'Сейчас не в комнате совместного прослушивания'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
