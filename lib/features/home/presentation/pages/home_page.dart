import 'dart:async' show Timer, unawaited;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/audio/audio_player_service.dart';
import '../../../../core/audio/local_tracks.dart';
import '../../../../core/audio/track.dart';
import '../../../../core/auth/auth_session_store.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/history/listening_history_repository.dart';
import '../../../../core/l10n/app_localization.dart';
import '../../../../core/network/server_connectivity.dart';
import '../../../../core/network/charts_api.dart';
import '../../../../core/network/recommendations_api.dart';
import '../../../../core/network/tracks_api.dart';
import '../../../../core/widgets/dual_track_cover_cluster.dart';
import '../../domain/entities/home_recommended_track.dart';
import '../../../../core/player/player_dock_host.dart';
import '../../../../core/player/shell_route_back_guard.dart';
import '../../../../core/social/colisten_controller.dart';
import '../../../../core/social/listening_room_session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_glass.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/track_cover.dart';
import '../../../../presentation/pages/artist_page.dart';
import '../../../../presentation/pages/listening_history_page.dart';
import '../../../../features/playlists/domain/repositories/playlists_repository.dart';
import '../../../../presentation/pages/playlists_page.dart';
import '../../../../presentation/pages/release_page.dart';
import '../../../../presentation/pages/charts_page.dart';
import '../../../../presentation/pages/for_you_page.dart';
import '../../domain/entities/home_section.dart';
import '../../domain/use_cases/get_home_section_use_case.dart';
import '../widgets/friends_section.dart';
import '../widgets/home_recommendations.dart';
import '../widgets/history_section.dart';
import '../widgets/nav_card_button.dart';
import '../widgets/releases_section.dart';

/// Фрагмент «Главная»: контент первой вкладки.
/// Featured-трек загружается из локальных assets и воспроизводится через [AudioPlayerService].
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.getHomeSectionUseCase,
    required this.audioPlayerService,
    required this.listeningHistoryRepository,
    required this.playlistsRepository,
    this.catalogReloadToken,
  });

  final GetHomeSectionUseCase getHomeSectionUseCase;
  final AudioPlayerService audioPlayerService;
  final ListeningHistoryRepository listeningHistoryRepository;
  final PlaylistsRepository playlistsRepository;

  /// Счётчик из [MainShell]: при переходе на вкладку «Главная» перечитываем каталог с сервера.
  final ValueNotifier<int>? catalogReloadToken;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  HomeSection? _section;
  List<Track> _localTracks = [];
  List<ServerTrackListItem> _serverTracks = [];
  String? _serverTracksError;
  List<Track> _chartNavTracks = const [];
  bool _isLoading = true;
  Timer? _homeSectionRefreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _startHomeSectionAutoRefresh();
    widget.catalogReloadToken?.addListener(_onCatalogReloadToken);
  }

  @override
  void dispose() {
    _homeSectionRefreshTimer?.cancel();
    widget.catalogReloadToken?.removeListener(_onCatalogReloadToken);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.catalogReloadToken != widget.catalogReloadToken) {
      oldWidget.catalogReloadToken?.removeListener(_onCatalogReloadToken);
      widget.catalogReloadToken?.addListener(_onCatalogReloadToken);
    }
  }

  void _onCatalogReloadToken() {
    unawaited(_reloadServerTracks());
  }

  void _startHomeSectionAutoRefresh() {
    _homeSectionRefreshTimer?.cancel();
    _homeSectionRefreshTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      unawaited(_refreshHomeSectionSilently());
    });
  }

  Future<void> _refreshHomeSectionSilently() async {
    try {
      final next = await widget.getHomeSectionUseCase();
      if (!mounted) return;
      setState(() => _section = next);
    } catch (_) {}
  }

  Future<void> _reloadServerTracks() async {
    try {
      final remote = await TracksApi().fetchTracks(limit: 50);
      if (!mounted) return;
      setState(() {
        _serverTracks = remote;
        _serverTracksError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _serverTracksError = e.toString());
    }
  }

  Future<void> _load({bool fromUser = false}) async {
    if (fromUser && mounted) {
      if (!await ServerConnectivity.instance.guardUserNetworkAction(context)) {
        setState(() => _isLoading = false);
        return;
      }
    }
    setState(() {
      _isLoading = true;
      _serverTracksError = null;
    });
    try {
      final results = await Future.wait([
        widget.getHomeSectionUseCase(),
        loadLocalTracks(),
      ]);
      List<ServerTrackListItem> remote = [];
      String? remoteErr;
      try {
        remote = await TracksApi().fetchTracks(limit: 50);
      } catch (e) {
        remoteErr = e.toString();
        if (fromUser && mounted) {
          await ServerConnectivity.instance.reportNetworkErrorIfOffline(context, e);
        }
      }
      var chartTracks = const <Track>[];
      try {
        final chartRows = await ChartsApi().fetchTopTracks(limit: 12);
        chartTracks = chartRows.map((r) => r.toTrack()).toList();
      } catch (_) {}
      if (mounted) {
        final section = results[0] as HomeSection;
        setState(() {
          _section = section;
          _localTracks = results[1] as List<Track>;
          _serverTracks = remote;
          _serverTracksError = remoteErr;
          _chartNavTracks = chartTracks;
          _isLoading = false;
        });
        unawaited(_postHomeRecommendationImpressions(section));
      }
    } catch (e) {
      if (fromUser && mounted) {
        await ServerConnectivity.instance.reportNetworkErrorIfOffline(context, e);
      }
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleRecommendationStream(List<Track> queue) async {
    if (queue.isEmpty) return;
    final service = widget.audioPlayerService;
    final first = queue.first;
    final same =
        service.currentTrack?.assetPath == first.assetPath &&
        service.currentTrack?.audioFilePath == first.audioFilePath;
    if (same) {
      await service.togglePlayPause();
      return;
    }
    await service.playTrack(first, queue: queue);
  }

  List<dynamic> _navCoverSources(List<Track> tracks) {
    return pickTwoTrackCoverSources(tracks).map((e) => e.source).toList();
  }

  Future<void> _postHomeRecommendationImpressions(HomeSection section) async {
    final acc = await AuthSessionStore.readAccount();
    if (acc == null || acc.sessionToken.isEmpty) return;
    final tracks = section.recommendedServerTracks;
    if (tracks.isEmpty) return;
    try {
      await RecommendationsApi().postEvents(
        tracks
            .map(
              (t) => <String, dynamic>{
                'surface': 'home',
                'targetType': 'track',
                'targetId': t.id,
                'interaction': 'impression',
                'scorePresent': t.score,
              },
            )
            .toList(),
      );
    } catch (_) {}
  }

  List<Track> _resolveRecommendedTracks(HomeSection section) {
    if (section.recommendedServerTracks.isNotEmpty) {
      return section.recommendedServerTracks.map(_trackFromHomeRec).toList();
    }
    if (section.recommendedTrackAssetPaths.isEmpty) {
      return _serverTracks.map(_trackFromServerItem).take(8).toList();
    }
    final byPath = {for (final t in _localTracks) t.assetPath: t};
    final result = <Track>[];
    for (final path in section.recommendedTrackAssetPaths) {
      final track = byPath[path];
      if (track != null) result.add(track);
    }
    if (result.isEmpty) {
      return _serverTracks.map(_trackFromServerItem).take(8).toList();
    }
    return result;
  }

  Track _trackFromHomeRec(HomeRecommendedTrack t) {
    return ServerTrackListItem(
      id: t.id,
      title: t.title,
      artist: t.artist,
    ).toTrack();
  }

  void _openCharts(BuildContext context) {
    Navigator.of(context).push(
      ShellMaterialPageRoute<void>(
        builder: (_) =>
            ChartsPage(audioPlayerService: widget.audioPlayerService),
      ),
    );
  }

  void _openForYou(BuildContext context) {
    Navigator.of(context).push(
      ShellMaterialPageRoute<void>(
        builder: (_) => ForYouPage(
          audioPlayerService: widget.audioPlayerService,
        ),
      ),
    );
  }

  void _openListeningHistory(BuildContext context) {
    Navigator.of(context).push(
      ShellMaterialPageRoute<void>(
        builder: (_) => ListeningHistoryPage(
          audioPlayerService: widget.audioPlayerService,
          listeningHistoryRepository: widget.listeningHistoryRepository,
        ),
      ),
    );
  }

  Future<void> _playRecommendedTrack({
    required Track selected,
    required List<Track> queue,
  }) async {
    if (queue.isEmpty) return;
    await widget.audioPlayerService.playTrack(selected, queue: queue);
  }

  Track _trackFromServerItem(ServerTrackListItem e) {
    return Track(
      assetPath: 'server_track_${e.id}',
      title: e.title,
      artist: e.artist,
      audioFilePath: e.streamUrl(),
      coverBytes: e.coverBytes,
      coverAssetPath: e.coverUrl(),
    );
  }

  Future<void> _playServerTrack(ServerTrackListItem item) async {
    if (_serverTracks.isEmpty) return;
    final queue = _serverTracks.map(_trackFromServerItem).toList();
    final selected = _trackFromServerItem(item);
    final same =
        widget.audioPlayerService.currentTrack?.assetPath == selected.assetPath;
    if (same) {
      await widget.audioPlayerService.togglePlayPause();
      return;
    }
    await widget.audioPlayerService.playTrack(selected, queue: queue);
  }

  String _formatServerDuration(int? sec) {
    if (sec == null || sec <= 0) return '—';
    final m = sec ~/ 60;
    final s = sec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _openRecommendedPlaylists(BuildContext context) {
    Navigator.of(context).push(
      ShellMaterialPageRoute<void>(
        builder: (_) => PlaylistsPage(
          audioPlayerService: widget.audioPlayerService,
          repository: widget.playlistsRepository,
        ),
      ),
    );
  }

  void _openRecommendedArtist(
    BuildContext context, {
    required String username,
    String? avatarUrl,
  }) {
    Navigator.of(context).push(
      ShellMaterialPageRoute<void>(
        builder: (_) => ArtistPage(
          artistName: username,
          coverImageUrl: avatarUrl,
          audioPlayerService: widget.audioPlayerService,
        ),
      ),
    );
  }

  Future<void> _joinGuestListeningRoom(HomeSection section) async {
    final roomId = section.friendPlayback?.activeRoomId;
    if (roomId == null || roomId.trim().isEmpty) return;
    final acc = await AuthSessionStore.readAccount();
    if (acc == null || acc.sessionToken.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('friends.loginToFriend'))),
      );
      return;
    }
    try {
      final currentUsername = acc.nickname.trim().isNotEmpty
          ? acc.nickname.trim()
          : 'mifoxti';
      final host = section.listeningFriends.isNotEmpty
          ? section.listeningFriends.first.username
          : 'MiMusic';
      ListeningRoomSession.instance.start(
        roomTitle: '@$host',
        listeners: [
          currentUsername,
          ...section.listeningFriends.map((friend) => friend.username),
        ],
        hostUsername: host,
        currentUsername: currentUsername,
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
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t('common.errorLoading'))));
    }
  }

  void _openReleaseCard(
    BuildContext context, {
    required String title,
    String? coverUrl,
    String? artistName,
    int? trackId,
  }) {
    Future<void> onListenTap() async {
      if (trackId != null) {
        try {
          final item = await TracksApi().fetchTrackById(trackId);
          final track = _trackFromServerItem(item);
          final queue = _serverTracks.isNotEmpty
              ? _serverTracks.map(_trackFromServerItem).toList()
              : [track];
          await widget.audioPlayerService.playTrack(track, queue: queue);
        } catch (_) {}
        return;
      }
      if (_localTracks.isEmpty) return;
      final normalized = title.toLowerCase().trim();
      final matched = _localTracks.where((t) {
        final tTitle = t.title.toLowerCase();
        return tTitle == normalized ||
            tTitle.contains(normalized) ||
            normalized.contains(tTitle);
      }).toList();
      final queue = matched.isNotEmpty ? matched : _localTracks;
      await widget.audioPlayerService.playTrack(queue.first, queue: queue);
    }

    ReleasePage.show(
      context,
      title: title,
      audioPlayerService: widget.audioPlayerService,
      coverUrl: coverUrl,
      artistName: artistName,
      trackTitle: title,
      onListenTap: onListenTap,
    );
  }

  String _historySubtitle() {
    final h = widget.listeningHistoryRepository.entries;
    if (h.isEmpty) {
      return context.t('history.emptyHint');
    }
    return h.take(3).map((e) => e.title).join(' · ');
  }

  LinearGradient _homeGradient(AppColorPalette palette) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        palette.gradientStart,
        Color.lerp(palette.gradientStart, palette.accent, 0.35)!,
        Color.lerp(palette.gradientMiddle, palette.accent, 0.18)!,
        palette.gradientEnd,
      ],
      stops: const [0.0, 0.28, 0.62, 1.0],
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    if (_isLoading) {
      return Container(
        decoration: BoxDecoration(gradient: _homeGradient(palette)),
        child: Center(child: CircularProgressIndicator(color: palette.accent)),
      );
    }
    if (_section == null) {
      return Container(
        decoration: BoxDecoration(gradient: _homeGradient(palette)),
        child: Center(
          child: Text(
            context.t('common.errorLoading'),
            style: TextStyle(color: palette.textSecondary),
          ),
        ),
      );
    }

    final section = _section!;
    final recommendedTracks = _resolveRecommendedTracks(section);
    final topPadding = MediaQuery.paddingOf(context).top;
    final hasMiniPlayer = widget.audioPlayerService.currentTrack != null;
    final bottomContentInset = hasMiniPlayer
        ? AppConstants.shellBottomInsetWithMiniPlayer
        : AppConstants.shellBottomInset;
    return Container(
      decoration: BoxDecoration(gradient: _homeGradient(palette)),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          CupertinoSliverRefreshControl(onRefresh: () => _load(fromUser: true)),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(0, 16 + topPadding, 0, 0),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'MiMusic',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: palette.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ListenableBuilder(
                    listenable: widget.audioPlayerService,
                    builder: (context, _) {
                      return _TopHeroStream(
                        isPlaying: widget.audioPlayerService.isPlaying,
                        onPlayPauseTap: () =>
                            _toggleRecommendationStream(recommendedTracks),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        NavCardButton(
                          title: context.t('home.forYou'),
                          onTap: () => _openForYou(context),
                          avatarColors: const [
                            Color(0xFF5C4A50),
                            Color(0xFF4A3D42),
                          ],
                          coverSources: _navCoverSources(
                            _resolveRecommendedTracks(section),
                          ),
                        ),
                        const SizedBox(width: 12),
                        NavCardButton(
                          title: context.t('home.charts'),
                          onTap: () => _openCharts(context),
                          avatarColors: const [
                            Color(0xFFC45C3E),
                            Color(0xFF8B3A2E),
                          ],
                          coverSources: _navCoverSources(_chartNavTracks),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ListenableBuilder(
                      listenable: widget.listeningHistoryRepository,
                      builder: (context, _) {
                        return HistorySectionCard(
                          subtitle: _historySubtitle(),
                          listeningHistoryRepository:
                              widget.listeningHistoryRepository,
                          onTap: () => _openListeningHistory(context),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (section.friendPlayback != null &&
                      section.listeningFriends.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: FriendsSection(
                        friendPlayback: section.friendPlayback,
                        listeningFriends: section.listeningFriends,
                        onConnectTap: () => _joinGuestListeningRoom(section),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (recommendedTracks.isNotEmpty)
                    HomeRecommendationSection(
                      title: Localizations.localeOf(context).languageCode == 'en'
                          ? 'Recommended tracks'
                          : 'Рекомендованные треки',
                      height: 72,
                      itemCount: recommendedTracks.length,
                      itemBuilder: (context, index) {
                        final e = recommendedTracks[index];
                        return RecommendedTrackCard(
                          track: e,
                          audioPlayerService: widget.audioPlayerService,
                          onTap: () => _playRecommendedTrack(
                            selected: e,
                            queue: recommendedTracks,
                          ),
                        );
                      },
                    ),
                  if (recommendedTracks.isNotEmpty) const SizedBox(height: 20),
                  if (section.recommendedPlaylists.isNotEmpty)
                    HomeRecommendationSection(
                      title: Localizations.localeOf(context).languageCode == 'en'
                          ? 'Recommended playlists'
                          : 'Рекомендованные плейлисты',
                      height: 148,
                      itemCount: section.recommendedPlaylists.length,
                      itemBuilder: (context, index) {
                        final e = section.recommendedPlaylists[index];
                        return RecommendedPlaylistCard(
                          title: e.title,
                          coverUrl: e.coverUrl,
                          onTap: () => _openRecommendedPlaylists(context),
                        );
                      },
                    ),
                  if (section.recommendedPlaylists.isNotEmpty)
                    const SizedBox(height: 20),
                  if (section.recommendedArtists.isNotEmpty)
                    HomeRecommendationSection(
                      title: context.t('home.uploaders'),
                      height: 152,
                      itemCount: section.recommendedArtists.length,
                      itemBuilder: (context, index) {
                        final e = section.recommendedArtists[index];
                        return RecommendedArtistCard(
                          name: e.username,
                          avatarUrl: e.avatarUrl,
                          onTap: () => _openRecommendedArtist(
                            context,
                            username: e.username,
                            avatarUrl: e.avatarUrl,
                          ),
                        );
                      },
                    ),
                  if (section.recommendedArtists.isNotEmpty)
                    const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ReleasesSection(
                      releases: section.latestReleases,
                      onItemTap: (item) => _openReleaseCard(
                        context,
                        title: item.title,
                        coverUrl: item.coverUrl,
                        artistName: item.artist ??
                            (section.recommendedArtists.isNotEmpty
                                ? section.recommendedArtists.first.username
                                : null),
                        trackId: item.trackId,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _ServerTracksDevSection(
                      tracks: _serverTracks,
                      errorText: _serverTracksError,
                      palette: palette,
                      formatDuration: _formatServerDuration,
                      onTrackTap: _playServerTrack,
                    ),
                  ),
                  SizedBox(height: bottomContentInset),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Нижний блок главной: последние треки с API (для проверки, что отдаёт сервер).
class _ServerTracksDevSection extends StatelessWidget {
  const _ServerTracksDevSection({
    required this.tracks,
    required this.errorText,
    required this.palette,
    required this.formatDuration,
    required this.onTrackTap,
  });

  final List<ServerTrackListItem> tracks;
  final String? errorText;
  final AppColorPalette palette;
  final String Function(int? sec) formatDuration;
  final void Function(ServerTrackListItem) onTrackTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t('home.serverTracks'),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: palette.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
          child: AppGlass.blurredTintLayer(
            isDark: isDark,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppGlass.tint(isDark),
                borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
                border: Border.all(color: AppGlass.border(isDark)),
                boxShadow: AppGlass.cardShadows(isDark),
              ),
              child: _buildBody(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    if (errorText != null) {
      return Text(
        '${context.t('home.serverTracksError')}\n$errorText',
        style: TextStyle(color: palette.textSecondary, fontSize: 13),
      );
    }
    if (tracks.isEmpty) {
      return Text(
        context.t('home.serverTracksEmpty'),
        style: TextStyle(color: palette.textSecondary, fontSize: 13),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < tracks.length; i++) ...[
          if (i > 0)
            Divider(
              height: 1,
              color: palette.textMuted.withValues(alpha: 0.25),
            ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onTrackTap(tracks[i]),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    buildTrackCover(
                      coverSource: tracks[i].coverBytes ?? tracks[i].coverUrl(),
                      width: 44,
                      height: 44,
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusMedium,
                      ),
                      placeholder: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: palette.primaryDark.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusMedium,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.music_note_rounded,
                          color: palette.textMuted,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tracks[i].title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          if ((tracks[i].artist ?? '').isNotEmpty)
                            Text(
                              tracks[i].artist!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          Text(
                            'id ${tracks[i].id} · ${formatDuration(tracks[i].durationSec)}',
                            style: TextStyle(
                              color: palette.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.play_circle_outline_rounded,
                      color: palette.accent,
                      size: 28,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _TopHeroStream extends StatelessWidget {
  const _TopHeroStream({required this.isPlaying, required this.onPlayPauseTap});

  final bool isPlaying;
  final VoidCallback onPlayPauseTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _GlassRoundPlayPauseButton(
        isPlaying: isPlaying,
        onTap: onPlayPauseTap,
      ),
    );
  }
}

class _GlassRoundPlayPauseButton extends StatelessWidget {
  const _GlassRoundPlayPauseButton({
    required this.isPlaying,
    required this.onTap,
  });

  final bool isPlaying;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(46),
        child: Ink(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: palette.cardBackground.withValues(alpha: 0.38),
            border: Border.all(
              color: palette.textPrimary.withValues(alpha: 0.24),
            ),
          ),
          child: Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: palette.textPrimary,
            size: 52,
          ),
        ),
      ),
    );
  }
}
