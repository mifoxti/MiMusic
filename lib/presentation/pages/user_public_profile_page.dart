import 'dart:async';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/audio/audio_player_service.dart';
import '../../core/audio/track.dart';
import '../../core/auth/auth_session_store.dart';
import '../../core/constants/app_constants.dart';
import '../../core/l10n/app_localization.dart';
import '../../core/network/api_config.dart';
import '../../core/network/friends_api.dart';
import '../../core/network/playlists_api.dart';
import '../../core/network/user_profile_api.dart';
import '../../core/player/shell_route_back_guard.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/track_cover.dart';
import 'playlist_detail_page.dart';
import 'thoughts_page.dart';

/// Публичный профиль пользователя с сервера: как «Профиль», но данные чужого аккаунта.
class UserPublicProfilePage extends StatefulWidget {
  const UserPublicProfilePage({
    super.key,
    required this.userId,
    required this.nickname,
    required this.audioPlayerService,
  });

  final int userId;
  final String nickname;
  final AudioPlayerService audioPlayerService;

  static const double _coverAspectRatio = 1.25;
  static const double _avatarMaxSize = 84;
  static const double _avatarMinSize = 40;

  @override
  State<UserPublicProfilePage> createState() => _UserPublicProfilePageState();
}

class _UserPublicProfilePageState extends State<UserPublicProfilePage> {
  UserPublicProfileDto? _profile;
  String? _error;
  bool _loading = true;
  bool _friendBusy = false;
  bool _isFriend = false;
  int? _myUserId;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final acc = await AuthSessionStore.readAccount();
      _myUserId = acc?.userId;
      final p = await UserProfileApi().fetchPublicProfile(widget.userId);
      final friends = await _safeFriendsList();
      if (!mounted) return;
      setState(() {
        _profile = p;
        _isFriend = friends.contains(widget.userId);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<Set<int>> _safeFriendsList() async {
    try {
      final list = await FriendsApi().fetchFriends();
      return list.map((e) => e.id).toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> _toggleFriend() async {
    final acc = await AuthSessionStore.readAccount();
    if (acc?.sessionToken.trim().isEmpty ?? true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('friends.loginToFriend'))),
      );
      return;
    }
    setState(() => _friendBusy = true);
    try {
      if (_isFriend) {
        await FriendsApi().removeFriend(widget.userId);
        if (!mounted) return;
        setState(() {
          _isFriend = false;
          _friendBusy = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('friends.removedOk'))),
        );
      } else {
        await FriendsApi().sendFriendRequest(widget.userId);
        if (!mounted) return;
        setState(() => _friendBusy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('friends.requestSent'))),
        );
      }
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _friendBusy = false);
      final code = e.response?.statusCode;
      final msg = code == 409 ? context.t('friends.alreadyPendingOrFriends') : context.t('common.errorLoading');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _friendBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('common.errorLoading'))),
      );
    }
  }

  Future<void> _playNowOrTrack(UserUploadedTrackDto t) async {
    final tr = Track(
      assetPath: 'server_track_${t.id}',
      title: t.title,
      artist: t.artist,
      audioFilePath: t.streamUrl(),
      coverBytes: t.coverBytes,
    );
    await widget.audioPlayerService.playTrack(tr, queue: [tr]);
  }

  Future<void> _playNowPlaying() async {
    final np = _profile?.nowPlaying;
    if (np == null) return;
    final b = ApiConfig.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final tr = Track(
      assetPath: 'server_track_${np.trackId}',
      title: np.title,
      artist: np.artist,
      audioFilePath: '$b/tracks/${np.trackId}/stream',
    );
    await widget.audioPlayerService.playTrack(tr, queue: [tr]);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    final size = MediaQuery.sizeOf(context);
    final topPadding = MediaQuery.paddingOf(context).top;
    final coverHeight = (size.width * UserPublicProfilePage._coverAspectRatio).clamp(260.0, size.height * 0.58);
    final expandedHeight = coverHeight + 96;
    final collapsedHeight = kToolbarHeight + topPadding + 12;
    final hasMini = widget.audioPlayerService.currentTrack != null;
    final bottomInset = hasMini ? AppConstants.shellBottomInsetWithMiniPlayer : AppConstants.shellBottomInset;
    final bust = DateTime.now().millisecondsSinceEpoch;
    final avatarUrl = userAvatarUrl(widget.userId, cacheBust: bust);
    final nick = _profile?.nickname ?? widget.nickname;
    final self = _myUserId != null && _myUserId == widget.userId;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.gradientStart, palette.gradientMiddle, palette.gradientEnd],
        ),
      ),
      child: _loading
          ? Center(child: CircularProgressIndicator(color: palette.accent))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, style: TextStyle(color: palette.textSecondary)),
                  ),
                )
              : CustomScrollView(
                  physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                  slivers: [
                    SliverAppBar(
                      pinned: true,
                      expandedHeight: expandedHeight,
                      backgroundColor: Colors.transparent,
                      surfaceTintColor: Colors.transparent,
                      elevation: 0,
                      forceMaterialTransparency: true,
                      flexibleSpace: LayoutBuilder(
                        builder: (context, constraints) {
                          final currentHeight = constraints.maxHeight;
                          final t = ((currentHeight - collapsedHeight) / (expandedHeight - collapsedHeight)).clamp(0.0, 1.0);
                          final easedT = Curves.easeInOut.transform(t);
                          final avatarSize = lerpDouble(UserPublicProfilePage._avatarMinSize, UserPublicProfilePage._avatarMaxSize, t)!;
                          final titleSize = lerpDouble(18, 28, t)!;
                          final alignment = Alignment.lerp(
                            const Alignment(-0.9, -0.2),
                            const Alignment(0, 0.7),
                            t,
                          )!;
                          final buttonVisibility = easedT;
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRect(
                                child: SizedBox(
                                  width: size.width,
                                  height: coverHeight,
                                  child: Image.network(
                                    avatarUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Container(
                                      color: palette.accent.withValues(alpha: 0.45),
                                      alignment: Alignment.center,
                                      child: const Icon(Icons.person_rounded, color: Colors.white, size: 64),
                                    ),
                                  ),
                                ),
                              ),
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withValues(alpha: 0.35),
                                      Colors.transparent,
                                      palette.cardBackground.withValues(alpha: 0.98),
                                    ],
                                    stops: const [0.0, 0.45, 1.0],
                                  ),
                                ),
                              ),
                              Align(
                                alignment: alignment,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: lerpDouble(16, 24, t)!),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      CircleAvatar(
                                        radius: avatarSize / 2,
                                        backgroundImage: NetworkImage(avatarUrl),
                                        onBackgroundImageError: (_, _) {},
                                        child: const SizedBox.shrink(),
                                      ),
                                      const SizedBox(width: 14),
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            nick,
                                            style: TextStyle(
                                              fontSize: titleSize,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              shadows: [
                                                Shadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 2)),
                                              ],
                                            ),
                                          ),
                                          SizedBox(height: 8 * buttonVisibility),
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            heightFactor: buttonVisibility == 0 ? 0.001 : buttonVisibility,
                                            child: Opacity(
                                              opacity: buttonVisibility,
                                              child: Material(
                                                color: Colors.white.withValues(alpha: 0.25),
                                                borderRadius: BorderRadius.circular(24),
                                                child: InkWell(
                                                  onTap: () async {
                                                    final acc = await AuthSessionStore.readAccount();
                                                    if (!context.mounted) return;
                                                    await Navigator.of(context).push(
                                                      ShellMaterialPageRoute<void>(
                                                        builder: (_) => ThoughtsPage(
                                                          currentUsername: acc?.nickname ?? '',
                                                          viewedUserId: widget.userId,
                                                          viewedUserNickname: nick,
                                                          audioPlayerService: widget.audioPlayerService,
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                  borderRadius: BorderRadius.circular(24),
                                                  child: Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                                    child: Text(
                                                      context.t('profile.thoughts'),
                                                      style: const TextStyle(
                                                        fontSize: 15,
                                                        fontWeight: FontWeight.w600,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Container(
                        decoration: BoxDecoration(
                          color: palette.cardBackground,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppConstants.radiusXLarge)),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, -4)),
                          ],
                        ),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (!self) ...[
                                FilledButton.icon(
                                  onPressed: _friendBusy ? null : _toggleFriend,
                                  icon: _friendBusy
                                      ? SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: palette.cardBackground),
                                        )
                                      : Icon(_isFriend ? Icons.person_remove_rounded : Icons.person_add_rounded),
                                  label: Text(_isFriend ? context.t('friends.removeFriend') : context.t('friends.addFriend')),
                                  style: FilledButton.styleFrom(backgroundColor: palette.accent),
                                ),
                                const SizedBox(height: 16),
                              ],
                              if (_profile?.bio != null && _profile!.bio!.trim().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: Text(_profile!.bio!, style: TextStyle(color: palette.textSecondary, height: 1.35)),
                                ),
                              Text(context.t('userProfile.nowPlaying'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: palette.textPrimary)),
                              const SizedBox(height: 8),
                              _glassCard(
                                palette,
                                child: _profile?.nowPlaying == null
                                    ? Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Text(context.t('userProfile.nothingPlaying'), style: TextStyle(color: palette.textSecondary)),
                                      )
                                    : ListTile(
                                        leading: Icon(Icons.graphic_eq_rounded, color: palette.accent),
                                        title: Text(_profile!.nowPlaying!.title),
                                        subtitle: Text(_profile!.nowPlaying!.artist ?? ''),
                                        trailing: IconButton(
                                          onPressed: _playNowPlaying,
                                          icon: Icon(Icons.play_circle_fill_rounded, color: palette.accent, size: 36),
                                        ),
                                      ),
                              ),
                              const SizedBox(height: 20),
                              Text(context.t('userProfile.recentThoughts'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: palette.textPrimary)),
                              const SizedBox(height: 8),
                              if (_profile!.recentThoughts.isEmpty)
                                Text(context.t('userProfile.emptyThoughts'), style: TextStyle(color: palette.textSecondary))
                              else
                                ..._profile!.recentThoughts.map(
                                  (t) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: _glassCard(
                                      palette,
                                      child: ListTile(
                                        title: Text(
                                          (t.bodyText ?? '').trim().isEmpty ? '—' : t.bodyText!.trim(),
                                          maxLines: 4,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle: _thoughtAttachmentSubtitle(context, palette, t),
                                      ),
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 20),
                              Text(context.t('userProfile.publicPlaylists'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: palette.textPrimary)),
                              const SizedBox(height: 8),
                              if (_profile!.publicPlaylists.isEmpty)
                                Text(context.t('userProfile.emptyPlaylists'), style: TextStyle(color: palette.textSecondary))
                              else
                                ..._profile!.publicPlaylists.map(
                                  (p) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: _glassCard(
                                      palette,
                                      child: ListTile(
                                        leading: SizedBox(
                                          width: 56,
                                          height: 56,
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: (p.coverStorageKey != null && p.coverStorageKey!.trim().isNotEmpty)
                                                ? Image.network(
                                                    playlistCoverUrl(p.id),
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, _, _) => Container(
                                                      color: palette.primaryDark.withValues(alpha: 0.35),
                                                      alignment: Alignment.center,
                                                      child: Icon(Icons.queue_music_rounded, color: palette.textSecondary, size: 28),
                                                    ),
                                                  )
                                                : Container(
                                                    color: palette.primaryDark.withValues(alpha: 0.35),
                                                    alignment: Alignment.center,
                                                    child: Icon(Icons.queue_music_rounded, color: palette.textSecondary, size: 28),
                                                  ),
                                          ),
                                        ),
                                        title: Text(p.title ?? 'Playlist'),
                                        subtitle: Text('${p.trackCount} ${context.t('userProfile.tracksWord')}'),
                                        trailing: const Icon(Icons.chevron_right_rounded),
                                        onTap: () {
                                          Navigator.of(context).push(
                                            ShellMaterialPageRoute<void>(
                                              builder: (_) => PlaylistDetailPage(
                                                playlistId: 'srv:${p.id}',
                                                audioPlayerService: widget.audioPlayerService,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 16),
                              Text(context.t('userProfile.uploads'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: palette.textPrimary)),
                              const SizedBox(height: 8),
                              if (_profile!.uploadedTracks.isEmpty)
                                Text(context.t('userProfile.emptyTracks'), style: TextStyle(color: palette.textSecondary))
                              else
                                ..._profile!.uploadedTracks.map(
                                  (t) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: _glassCard(
                                      palette,
                                      child: ListTile(
                                        leading: SizedBox(
                                          width: 48,
                                          height: 48,
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(8),
                                            child: buildTrackCover(
                                              coverSource: t.coverBytes ?? t.coverUrl(),
                                              width: 48,
                                              height: 48,
                                              borderRadius: BorderRadius.circular(8),
                                              placeholder: Container(color: palette.primaryDark.withValues(alpha: 0.35)),
                                            ),
                                          ),
                                        ),
                                        title: Text(t.title),
                                        subtitle: Text(t.artist ?? ''),
                                        trailing: IconButton(
                                          icon: Icon(Icons.play_arrow_rounded, color: palette.accent),
                                          onPressed: () => _playNowOrTrack(t),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget? _thoughtAttachmentSubtitle(BuildContext context, AppColorPalette palette, UserProfileThoughtDto t) {
    final track = t.attachmentTrackTitle?.trim();
    final artist = t.attachmentTrackArtist?.trim();
    final pl = t.attachmentPlaylistTitle?.trim();
    if (track != null && track.isNotEmpty) {
      final line = artist != null && artist.isNotEmpty ? '$track — $artist' : track;
      return Text(
        '${context.t('userProfile.thoughtAttachmentTrack')}: $line',
        style: TextStyle(color: palette.textSecondary, fontSize: 13),
      );
    }
    if (pl != null && pl.isNotEmpty) {
      return Text(
        '${context.t('userProfile.thoughtAttachmentPlaylist')}: $pl',
        style: TextStyle(color: palette.textSecondary, fontSize: 13),
      );
    }
    return null;
  }

  Widget _glassCard(AppColorPalette palette, {required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: palette.cardBackground.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
            border: Border.all(color: palette.textPrimary.withValues(alpha: 0.12)),
          ),
          child: child,
        ),
      ),
    );
  }
}
