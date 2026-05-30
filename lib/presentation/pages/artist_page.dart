import 'package:flutter/material.dart';

import '../../core/audio/audio_player_service.dart';
import '../../core/audio/track.dart';
import '../../core/auth/auth_session_store.dart';
import '../../core/network/artist_api.dart';
import '../../core/constants/app_constants.dart';
import '../../core/l10n/app_localization.dart';
import '../../core/notifications/local_notifications_service.dart';
import '../../core/player/shell_route_back_guard.dart';
import '../../core/social/friend_request_notifications.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/track_cover.dart';
import 'thoughts_page.dart';

/// Экран автора: обложка, имя, «Мысли», популярные треки и релизы (локальные данные + моки).
class ArtistPage extends StatefulWidget {
  const ArtistPage({
    super.key,
    required this.artistName,
    this.coverAssetPath = 'assets/images/geoxor.png',
    this.coverImageUrl,
    this.audioPlayerService,
  });

  final String artistName;
  final String? coverAssetPath;
  final String? coverImageUrl;
  final AudioPlayerService? audioPlayerService;

  @override
  State<ArtistPage> createState() => _ArtistPageState();
}

class _ArtistPageState extends State<ArtistPage> {
  static const String _currentUser = 'mifoxti';
  List<Track> _tracks = [];
  String _thoughtsPreview = '';
  bool _loading = true;
  bool _friendRequestSent = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final acc = await AuthSessionStore.readAccount();
      final profile = await ArtistApi().fetchByName(
        widget.artistName,
        userId: acc?.userId,
      );
      if (!mounted) return;
      setState(() {
        _tracks = profile.songs.map((s) => s.toTrack()).toList();
        _thoughtsPreview = profile.thoughts;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _tracks = [];
        _thoughtsPreview = '';
        _loading = false;
      });
    }
  }

  Future<void> _playTrack(Track t) async {
    final s = widget.audioPlayerService;
    if (s == null) return;
    await s.playTrack(t, queue: _tracks.isNotEmpty ? _tracks : [t]);
  }

  Future<void> _sendFriendRequest() async {
    final center = FriendRequestNotifications.instance;
    final existing = center.pendingBetween(
      fromUsername: _currentUser,
      toUsername: widget.artistName,
    );
    if (existing != null || _friendRequestSent) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t('artist.requestSent')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    center.sendRequest(
      fromUsername: _currentUser,
      fromAvatarUrl: widget.coverImageUrl,
      toUsername: widget.artistName,
    );
    await LocalNotificationsService.instance.showFriendRequestNotification(
      fromUsername: widget.artistName,
      fromAvatarUrl: widget.coverImageUrl,
      fromAvatarAssetPath: widget.coverAssetPath,
    );
    if (!mounted) return;
    setState(() => _friendRequestSent = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${context.t('artist.requestSent')} @${widget.artistName}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    final cover = widget.coverAssetPath ?? 'assets/images/geoxor.png';
    final networkCover = widget.coverImageUrl;

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
        body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                backgroundColor: Colors.transparent,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back_rounded, color: palette.textPrimary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                    if ((networkCover ?? '').isNotEmpty)
                      Image.network(
                        networkCover!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Image.asset(
                          cover,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: palette.accent.withValues(alpha: 0.5),
                          ),
                        ),
                      )
                    else
                      Image.asset(
                        cover,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: palette.accent.withValues(alpha: 0.5),
                        ),
                      ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.1),
                            Colors.black.withValues(alpha: 0.65),
                          ],
                        ),
                      ),
                    ),
                    SafeArea(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.artistName,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Material(
                                    color: Colors.white.withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(24),
                                    child: InkWell(
                                      onTap: () {
                                        _sendFriendRequest();
                                      },
                                      borderRadius: BorderRadius.circular(24),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        child: Text(
                                          _friendRequestSent
                                              ? context.t('artist.requestSent')
                                              : context.t('artist.addFriend'),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Material(
                                    color: Colors.white.withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(24),
                                    child: InkWell(
                                      onTap: () {
                                        Navigator.of(context).push(
                                          ShellMaterialPageRoute<void>(
                                            builder: (_) => ThoughtsPage(
                                              currentUsername: _currentUser,
                                              audioPlayerService:
                                                  widget.audioPlayerService,
                                            ),
                                          ),
                                        );
                                      },
                                      borderRadius: BorderRadius.circular(24),
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 8,
                                        ),
                                        child: Text(
                                          context.t('profile.thoughts'),
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
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
                    ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Container(
                  decoration: BoxDecoration(
                    color: palette.primaryLight.withValues(alpha: 0.92),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: palette.textMuted.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (_thoughtsPreview.isNotEmpty) ...[
                        Text(
                          _thoughtsPreview,
                          style: TextStyle(
                            fontSize: 14,
                            color: palette.textSecondary,
                            height: 1.4,
                          ),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 16),
                      ],
                      Text(
                        'Популярные треки',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_loading)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: CircularProgressIndicator(
                              color: palette.accent,
                            ),
                          ),
                        )
                      else
                        ..._tracks.take(5).map(
                              (t) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _PopularTrackRow(
                                  track: t,
                                  palette: palette,
                                  onPlay: () => _playTrack(t),
                                  onLike: () {},
                                ),
                              ),
                            ),
                      if (!_loading && _tracks.length > 5)
                        TextButton(
                          onPressed: () {},
                          child: const Text('Ещё…'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
      ),
    );
  }
}

class _PopularTrackRow extends StatelessWidget {
  const _PopularTrackRow({
    required this.track,
    required this.palette,
    required this.onPlay,
    required this.onLike,
  });

  final Track track;
  final AppColorPalette palette;
  final VoidCallback onPlay;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: palette.cardBackground.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
      child: InkWell(
        onTap: onPlay,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: buildTrackCover(
                    coverSource: track.coverBytes ?? track.coverFallbackPath,
                    width: 48,
                    height: 48,
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusMedium),
                    placeholder: Container(
                      color: palette.accent.withValues(alpha: 0.5),
                      child: Icon(
                        Icons.music_note_rounded,
                        color: palette.textMuted,
                      ),
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
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: palette.textPrimary,
                      ),
                    ),
                    Text(
                      track.artistDisplay.isEmpty
                          ? '—'
                          : track.artistDisplay,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.favorite_border_rounded),
                color: palette.textSecondary,
                onPressed: onLike,
              ),
              IconButton(
                icon: const Icon(Icons.more_vert_rounded),
                color: palette.textSecondary,
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}
