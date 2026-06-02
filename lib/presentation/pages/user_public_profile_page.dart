import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/audio/audio_player_service.dart';
import '../../core/audio/track.dart';
import '../../core/auth/auth_session_store.dart';
import '../../core/l10n/app_localization.dart';
import '../../core/network/api_config.dart';
import '../../core/network/friends_api.dart';
import '../../core/network/playlists_api.dart';
import '../../core/network/user_profile_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/track_cover.dart';
import '../widgets/collapsing_profile_shell.dart';
import '../widgets/glass_panel.dart';
import 'playlist_detail_page.dart';
import 'thoughts_page.dart';
import '../../core/player/shell_route_back_guard.dart';

/// Публичный профиль зарегистрированного пользователя MiMusic.
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
      final msg = code == 409
          ? context.t('friends.alreadyPendingOrFriends')
          : context.t('common.errorLoading');
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

  Future<void> _openThoughts(String nick) async {
    final acc = await AuthSessionStore.readAccount();
    if (!mounted) return;
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
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;

    if (_loading) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              palette.gradientStart,
              palette.gradientMiddle,
              palette.gradientEnd,
            ],
          ),
        ),
        child: Center(child: CircularProgressIndicator(color: palette.accent)),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_error!, style: TextStyle(color: palette.textSecondary)),
          ),
        ),
      );
    }

    final p = _profile!;
    final bust = DateTime.now().millisecondsSinceEpoch;
    final avatarUrl = userAvatarUrl(widget.userId, cacheBust: bust);
    final nick = p.nickname.trim().isNotEmpty ? p.nickname : widget.nickname;
    final self = _myUserId != null && _myUserId == widget.userId;

    return CollapsingProfileShell(
      title: nick,
      audioPlayerService: widget.audioPlayerService,
      onRefresh: _load,
      collapsedHeaderAlignment: const Alignment(-0.92, 0.22),
      expandedHeaderAlignment: const Alignment(0, 0.58),
      cover: Image.network(
        avatarUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          color: palette.accent.withValues(alpha: 0.45),
          alignment: Alignment.center,
          child: const Icon(Icons.person_rounded, color: Colors.white, size: 64),
        ),
      ),
      avatar: CircleAvatar(
        backgroundImage: NetworkImage(avatarUrl),
        onBackgroundImageError: (_, _) {},
      ),
      headerActions: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GlassPillButton(
            label: context.t('profile.thoughts'),
            onTap: () => unawaited(_openThoughts(nick)),
          ),
          if (!self) ...[
            const SizedBox(width: 6),
            Opacity(
              opacity: _friendBusy ? 0.55 : 1,
              child: IgnorePointer(
                ignoring: _friendBusy,
                child: GlassIconButton(
                  icon: _isFriend
                      ? Icons.person_remove_rounded
                      : Icons.person_add_alt_1_rounded,
                  onPressed: () => unawaited(_toggleFriend()),
                ),
              ),
            ),
          ],
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (p.bio != null && p.bio!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                p.bio!,
                style: TextStyle(color: palette.textSecondary, height: 1.35),
              ),
            ),
          ProfileGlassSection(
            title: context.t('userProfile.nowPlaying'),
            child: !p.online || p.nowPlaying == null
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      context.t('userProfile.nothingPlaying'),
                      style: TextStyle(color: palette.textSecondary),
                    ),
                  )
                : ListTile(
                    leading: Icon(Icons.graphic_eq_rounded, color: palette.accent),
                    title: Text(p.nowPlaying!.title),
                    subtitle: Text(p.nowPlaying!.artist ?? ''),
                    trailing: IconButton(
                      onPressed: _playNowPlaying,
                      icon: Icon(
                        Icons.play_circle_fill_rounded,
                        color: palette.accent,
                        size: 36,
                      ),
                    ),
                  ),
          ),
          if (p.recentThoughts.isNotEmpty)
            ProfileGlassSection(
              title: context.t('userProfile.recentThoughts'),
              child: Column(
                children: p.recentThoughts
                    .map(
                      (t) => ListTile(
                        title: Text(
                          (t.bodyText ?? '').trim().isEmpty ? '—' : t.bodyText!.trim(),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: _thoughtAttachmentSubtitle(context, palette, t),
                      ),
                    )
                    .toList(),
              ),
            ),
          ProfileGlassSection(
            title: context.t('userProfile.publicPlaylists'),
            child: p.publicPlaylists.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      context.t('userProfile.emptyPlaylists'),
                      style: TextStyle(color: palette.textSecondary),
                    ),
                  )
                : Column(
                    children: p.publicPlaylists
                        .map(
                          (pl) => ListTile(
                            leading: _playlistCover(palette, pl),
                            title: Text(pl.title ?? 'Playlist'),
                            subtitle: Text(
                              '${pl.trackCount} ${context.t('userProfile.tracksWord')}',
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () {
                              Navigator.of(context).push(
                                ShellMaterialPageRoute<void>(
                                  builder: (_) => PlaylistDetailPage(
                                    playlistId: 'srv:${pl.id}',
                                    audioPlayerService: widget.audioPlayerService,
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                        .toList(),
                  ),
          ),
          ProfileGlassSection(
            title: context.t('userProfile.uploads'),
            margin: EdgeInsets.zero,
            child: p.uploadedTracks.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      context.t('userProfile.emptyTracks'),
                      style: TextStyle(color: palette.textSecondary),
                    ),
                  )
                : Column(
                    children: p.uploadedTracks
                        .map(
                          (t) => ListTile(
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
                                  placeholder: Container(
                                    color: palette.primaryDark.withValues(alpha: 0.35),
                                  ),
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
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _playlistCover(AppColorPalette palette, UserPublicPlaylistDto p) {
    return SizedBox(
      width: 56,
      height: 56,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: (p.coverStorageKey != null && p.coverStorageKey!.trim().isNotEmpty)
            ? Image.network(
                playlistCoverUrl(p.id),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _playlistPlaceholder(palette),
              )
            : _playlistPlaceholder(palette),
      ),
    );
  }

  Widget _playlistPlaceholder(AppColorPalette palette) {
    return Container(
      color: palette.primaryDark.withValues(alpha: 0.35),
      alignment: Alignment.center,
      child: Icon(Icons.queue_music_rounded, color: palette.textSecondary, size: 28),
    );
  }

  Widget? _thoughtAttachmentSubtitle(
    BuildContext context,
    AppColorPalette palette,
    UserProfileThoughtDto t,
  ) {
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
}
