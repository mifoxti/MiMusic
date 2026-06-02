import 'package:flutter/material.dart';

import '../../core/audio/audio_player_service.dart';
import '../../core/audio/track.dart';
import '../../core/auth/auth_session_store.dart';
import '../../core/network/recommendations_api.dart';
import '../../core/constants/app_constants.dart';
import '../../core/l10n/app_localization.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/dual_track_cover_cluster.dart';
import '../../core/widgets/track_cover.dart' show buildTrackCover;
import '../../core/player/player_dock_host.dart';
import '../widgets/track_playback_trailing_icon.dart';

/// Экран «Для вас»: только [GET /recommendations/tracks] и события impression/click.
class ForYouPage extends StatefulWidget {
  const ForYouPage({
    super.key,
    required this.audioPlayerService,
  });

  final AudioPlayerService audioPlayerService;

  @override
  State<ForYouPage> createState() => _ForYouPageState();
}

class _ForYouPageState extends State<ForYouPage> {
  List<Track> _serverRecTracks = [];
  String? _serverRecError;
  bool _loading = true;
  bool _loggedIn = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final acc = await AuthSessionStore.readAccount();
    final loggedIn = acc != null && acc.sessionToken.isNotEmpty && acc.userId != null;
    List<Track> serverQueue = [];
    String? serverErr;
    if (loggedIn) {
      try {
        final dto = await RecommendationsApi().fetchRecommendedTracks(limit: 24);
        serverQueue = dto.map((e) => e.toTrack()).toList();
        await RecommendationsApi().postEvents(
          dto
              .map(
                (e) => <String, dynamic>{
                  'surface': 'for_you',
                  'targetType': 'track',
                  'targetId': e.id,
                  'interaction': 'impression',
                  'scorePresent': e.score,
                },
              )
              .toList(),
        );
      } catch (e) {
        serverErr = e.toString();
      }
    }
    if (!mounted) return;
    setState(() {
      _loggedIn = loggedIn;
      _serverRecTracks = serverQueue;
      _serverRecError = serverErr;
      _loading = false;
    });
  }

  void _openFullPlayer() {
    PlayerDockHost.expand();
  }

  Future<void> _onServerRecTap(Track track) async {
    final idStr = track.assetPath.replaceFirst('server_track_', '');
    final id = int.tryParse(idStr);
    if (id != null) {
      try {
        await RecommendationsApi().postEvents([
          {
            'surface': 'for_you',
            'targetType': 'track',
            'targetId': id,
            'interaction': 'click',
          },
        ]);
      } catch (_) {}
    }
    await _onTrackTap(track);
  }

  Future<void> _onTrackTap(Track track) async {
    final queue = _serverRecTracks;
    if (queue.isEmpty) return;
    final service = widget.audioPlayerService;
    final same = service.currentTrack?.assetPath == track.assetPath &&
        service.currentTrack?.audioFilePath == track.audioFilePath;
    if (same) {
      await service.togglePlayPause();
      return;
    }
    await service.playTrack(track, queue: queue);
    if (mounted) _openFullPlayer();
  }

  Future<void> _onPlayMixPressed() async {
    final queue = _serverRecTracks;
    if (queue.isEmpty) return;
    final service = widget.audioPlayerService;
    final first = queue.first;
    final same = service.currentTrack?.assetPath == first.assetPath &&
        service.currentTrack?.audioFilePath == first.audioFilePath;
    if (same) {
      await service.togglePlayPause();
      return;
    }
    await service.playTrack(first, queue: queue);
    if (mounted) _openFullPlayer();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    final queue = _serverRecTracks;

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
          title: Text(context.t('forYou.title')),
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: palette.textPrimary,
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: palette.textPrimary),
        ),
        body: ListenableBuilder(
          listenable: widget.audioPlayerService,
          builder: (context, _) {
            if (_loading) {
              return Center(
                child: CircularProgressIndicator(color: palette.accent),
              );
            }
            final hasMiniPlayer = widget.audioPlayerService.currentTrack != null;
            final bottomContentInset = hasMiniPlayer
                ? AppConstants.shellBottomInsetWithMiniPlayer
                : AppConstants.shellBottomInset;

            return RefreshIndicator(
              onRefresh: _load,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: DualTrackCoverCluster(
                              covers: pickTwoTrackCoverSources(queue),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            context.t('forYou.subtitle'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: palette.textSecondary,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 22),
                          Center(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: queue.isEmpty ? null : _onPlayMixPressed,
                                borderRadius: BorderRadius.circular(40),
                                child: Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.85),
                                      width: 2,
                                    ),
                                    color: palette.accent.withValues(alpha: 0.32),
                                  ),
                                  child: Icon(
                                    widget.audioPlayerService.isPlaying
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    size: 40,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          if (!_loggedIn)
                            Text(
                              context.t('forYou.loginRequired'),
                              textAlign: TextAlign.center,
                              style: TextStyle(color: palette.textSecondary),
                            )
                          else if (_serverRecError != null)
                            Text(
                              _serverRecError!,
                              style: TextStyle(fontSize: 12, color: palette.textMuted),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (queue.isEmpty && _loggedIn)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Text(
                                context.t('forYou.empty'),
                                textAlign: TextAlign.center,
                                style: TextStyle(color: palette.textMuted),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (queue.isNotEmpty)
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(20, 0, 20, bottomContentInset),
                      sliver: SliverList.separated(
                        itemCount: queue.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final t = queue[index];
                          return _ForYouTrackRow(
                            track: t,
                            palette: palette,
                            audioPlayerService: widget.audioPlayerService,
                            onTap: () => _onServerRecTap(t),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ForYouTrackRow extends StatelessWidget {
  const _ForYouTrackRow({
    required this.track,
    required this.palette,
    required this.audioPlayerService,
    required this.onTap,
  });

  final Track track;
  final AppColorPalette palette;
  final AudioPlayerService audioPlayerService;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: palette.cardBackground.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: buildTrackCover(
                  coverSource: track.coverBytes ?? track.coverAssetPath,
                  width: 52,
                  height: 52,
                  borderRadius: BorderRadius.circular(10),
                  placeholder: Icon(Icons.music_note, color: palette.textMuted),
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
                    if (track.artistDisplay.isNotEmpty)
                      Text(
                        track.artistDisplay,
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
              TrackPlaybackTrailingIcon(
                audioPlayerService: audioPlayerService,
                track: track,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
