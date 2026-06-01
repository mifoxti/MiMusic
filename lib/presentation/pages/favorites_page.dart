import 'package:flutter/material.dart';

import '../../core/audio/audio_player_service.dart';
import '../../core/audio/local_tracks.dart';
import '../../core/audio/track.dart';
import '../../core/network/server_connectivity.dart';
import '../../core/network/tracks_api.dart';
import '../../core/constants/app_constants.dart';
import '../../core/l10n/app_localization.dart';
import '../../core/offline/download_feedback.dart';
import '../../core/offline/offline_download_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_glass.dart';
import '../../core/theme/app_theme.dart';
import '../../core/player/player_dock_host.dart';
import '../../features/playlists/data/repositories/local_playlists_repository.dart';
import '../../features/player/presentation/widgets/full_player_track_menu.dart';
import '../widgets/favorite_track_item.dart';
import '../widgets/glass_bottom_menu_sheet.dart';

/// Страница «Любимые»: заголовок с сердечком, кнопка «Играть всё», список избранных треков.
class FavoritesPage extends StatefulWidget {
  const FavoritesPage({
    super.key,
    required this.audioPlayerService,
  });

  final AudioPlayerService audioPlayerService;

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  List<Track> _favoriteTracks = [];
  bool _isLoading = true;
  bool _downloadingAll = false;
  String? _lastLikedFingerprint;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    widget.audioPlayerService.addListener(_onServiceChanged);
  }

  @override
  void dispose() {
    widget.audioPlayerService.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() {
    final fp = _likesFingerprint(widget.audioPlayerService.likedPaths);
    if (_lastLikedFingerprint != null &&
        _lastLikedFingerprint != fp &&
        mounted) {
      _loadFavorites();
    }
    _lastLikedFingerprint = fp;
  }

  String _likesFingerprint(Set<String> set) {
    final sorted = set.toList()..sort();
    return sorted.join('|');
  }

  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);
    final allTracks = await loadLocalTracks();
    await widget.audioPlayerService.syncTrackLikesFromServer();
    if (mounted) {
      final liked = widget.audioPlayerService.likedPaths;
      final out = <Track>[];
      final seen = <String>{};

      for (final t in allTracks) {
        final p = AudioPlayerService.playablePath(t);
        if (liked.contains(p) || liked.contains(t.assetPath)) {
          if (seen.add(t.assetPath)) out.add(t);
        }
      }

      final serverIds = liked
          .where((p) => p.startsWith('server_track_'))
          .map((p) => int.tryParse(p.replaceFirst('server_track_', '')))
          .whereType<int>()
          .toSet();
      if (serverIds.isNotEmpty) {
        try {
          final remote = await TracksApi().fetchTracks(limit: 200);
          for (final r in remote) {
            if (!serverIds.contains(r.id)) continue;
            final key = 'server_track_${r.id}';
            if (!seen.add(key)) continue;
            out.add(
              Track(
                assetPath: key,
                title: r.title,
                artist: r.artist,
                audioFilePath: r.streamUrl(),
                coverBytes: r.coverBytes,
                coverAssetPath: r.coverUrl(),
              ),
            );
          }
        } catch (_) {}
      }
      setState(() {
        _favoriteTracks = out;
        _isLoading = false;
        _lastLikedFingerprint = _likesFingerprint(liked);
      });
    }
  }

  void _openFullPlayer() {
    PlayerDockHost.expand();
  }

  Future<void> _playAll() async {
    if (_favoriteTracks.isEmpty) return;
    await widget.audioPlayerService.playTrack(
      _favoriteTracks.first,
      queue: _favoriteTracks,
    );
  }

  Future<void> _onPlayAllPressed() async {
    if (_favoriteTracks.isEmpty) return;
    final service = widget.audioPlayerService;
    if (service.currentTrack != null) {
      await service.togglePlayPause();
    } else {
      await _playAll();
    }
  }

  Future<void> _onTrackTap(Track track) async {
    if (widget.audioPlayerService.currentTrack?.assetPath == track.assetPath) {
      await widget.audioPlayerService.togglePlayPause();
    } else {
      await widget.audioPlayerService.playTrack(track, queue: _favoriteTracks);
    }
    if (mounted) _openFullPlayer();
  }

  Future<void> _onRemoveFavorite(Track track) async {
    await widget.audioPlayerService.removeFromFavorites(
      AudioPlayerService.playablePath(track),
    );
    if (mounted) _loadFavorites();
  }

  Future<void> _showTrackMenu(Track track) async {
    final service = widget.audioPlayerService;
    final trackKey = track.assetPath;
    final downloaded = service.isTrackDownloaded(trackKey);
    final downloading = service.isTrackDownloading(trackKey);

    await showGlassBottomMenuSheet(
      context,
      header: GlassMenuTrackHeader(track: track),
      actions: [
        GlassMenuAction(
          icon: Icons.download_rounded,
          label: context.t('playlists.track.download'),
          onTap: () async {
            if (downloading) {
              showTrackDownloadSnackBar(
                context,
                DownloadTrackResult.inProgress,
              );
              return;
            }
            if (downloaded) {
              showTrackDownloadSnackBar(
                context,
                DownloadTrackResult.alreadyDownloaded,
              );
              return;
            }
            if (!trackKey.startsWith('server_track_')) {
              showTrackDownloadSnackBar(
                context,
                DownloadTrackResult.notServerTrack,
              );
              return;
            }
            if (!await ServerConnectivity.instance.ensureOnline(context)) {
              return;
            }
            final result = await service.downloadTrack(track);
            if (!mounted) return;
            showTrackDownloadSnackBar(context, result);
          },
        ),
        GlassMenuAction(
          icon: Icons.playlist_add_rounded,
          label: context.t('player.menu.addToPlaylist'),
          onTap: () {
            showTrackPlaylistPicker(
              context,
              track: track,
              repository: LocalPlaylistsRepository(),
            );
          },
        ),
        GlassMenuAction(
          icon: Icons.favorite_rounded,
          label: context.t('playlists.track.removeFromFavorites'),
          iconColor: AppPaletteExtension.of(context).palette.accent,
          onTap: () => _onRemoveFavorite(track),
        ),
      ],
    );
  }

  Future<void> _downloadAllFavorites() async {
    if (_favoriteTracks.isEmpty || _downloadingAll) return;
    if (!await ServerConnectivity.instance.ensureOnline(context)) {
      return;
    }

    setState(() => _downloadingAll = true);
    final service = widget.audioPlayerService;

    var downloadedAny = false;
    var attemptedAny = false;
    var limitHit = false;

    for (final track in _favoriteTracks) {
      final key = track.assetPath;
      if (!key.startsWith('server_track_')) continue;
      if (service.isTrackDownloaded(key) || service.isTrackDownloading(key)) {
        continue;
      }
      attemptedAny = true;
      final result = await service.downloadTrack(track);
      if (result == DownloadTrackResult.cacheLimitExceeded) {
        limitHit = true;
        break;
      }
      if (result == DownloadTrackResult.success ||
          result == DownloadTrackResult.alreadyDownloaded) {
        downloadedAny = true;
      }
    }

    if (!mounted) return;
    setState(() => _downloadingAll = false);

    final result = !attemptedAny
        ? DownloadFavoritesResult.nothingToDownload
        : limitHit
            ? (downloadedAny
                ? DownloadFavoritesResult.partial
                : DownloadFavoritesResult.cacheLimitExceeded)
            : downloadedAny
                ? DownloadFavoritesResult.success
                : DownloadFavoritesResult.failed;
    showFavoritesDownloadSnackBar(context, result);
  }

  Widget _buildDownloadAllAction(AppColorPalette palette) {
    final muted = palette.textMuted;
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        onPressed: _downloadingAll ? null : _downloadAllFavorites,
        style: TextButton.styleFrom(
          foregroundColor: muted,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: _downloadingAll
            ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: muted.withValues(alpha: 0.7),
                ),
              )
            : Icon(
                Icons.download_outlined,
                size: 16,
                color: muted.withValues(alpha: 0.85),
              ),
        label: Text(
          context.t('favorites.downloadAll'),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: muted.withValues(alpha: 0.9),
          ),
        ),
      ),
    );
  }

  /// Как на главной: диагональный градиент с акцентом.
  LinearGradient _pageGradient(AppColorPalette palette) {
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
    final topPadding = MediaQuery.paddingOf(context).top;

    return Container(
      decoration: BoxDecoration(
        gradient: _pageGradient(palette),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(context.t('favorites.title')),
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
            if (_isLoading) {
              return Center(
                child: CircularProgressIndicator(color: palette.accent),
              );
            }
            final hasMiniPlayer = widget.audioPlayerService.currentTrack != null;
            final bottomContentInset = hasMiniPlayer
                ? AppConstants.shellBottomInsetWithMiniPlayer
                : AppConstants.shellBottomInset;
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _buildHeader(palette, topPadding),
                ),
                if (_favoriteTracks.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 32, 16, 48),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
                            child: Builder(
                              builder: (ctx) {
                                final isDark = Theme.of(ctx).brightness == Brightness.dark;
                                final p = AppPaletteExtension.of(ctx).palette;
                                return AppGlass.blurredTintLayer(
                                  isDark: isDark,
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                                    decoration: BoxDecoration(
                                      color: AppGlass.tint(isDark),
                                      borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
                                      border: Border.all(color: AppGlass.border(isDark)),
                                      boxShadow: AppGlass.cardShadows(isDark),
                                    ),
                                    child: Text(
                                      context.t('favorites.empty'),
                                      style: TextStyle(
                                        fontSize: 14,
                                        height: 1.35,
                                        color: p.textSecondary,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                else ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 12, 4),
                      child: _buildDownloadAllAction(palette),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(16, 4, 16, bottomContentInset),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final track = _favoriteTracks[index];
                          return FavoriteTrackItem(
                            track: track,
                            isDownloaded: widget.audioPlayerService.isTrackDownloaded(
                              track.assetPath,
                            ),
                            onTap: () => _onTrackTap(track),
                            onRemoveFavorite: () => _onRemoveFavorite(track),
                            onMore: () => _showTrackMenu(track),
                          );
                        },
                        childCount: _favoriteTracks.length,
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(AppColorPalette palette, double topPadding) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8 + topPadding, 16, 20),
      child: Column(
        children: [
          _buildHeartWithRings(palette),
          const SizedBox(height: 16),
          Text(
            context.t('favorites.header'),
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: palette.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 20),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _favoriteTracks.isEmpty ? null : _onPlayAllPressed,
              borderRadius: BorderRadius.circular(32),
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.9),
                    width: 2,
                  ),
                  color: palette.accent.withValues(alpha: 0.35),
                  boxShadow: [
                    BoxShadow(
                      color: palette.accent.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  widget.audioPlayerService.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: 36,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeartWithRings(AppColorPalette palette) {
    const size = 88.0;
    return SizedBox(
      width: size + 48,
      height: size + 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (var i = 3; i >= 0; i--)
            Container(
              width: size + (i * 16.0),
              height: size + (i * 16.0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: palette.accent.withValues(
                    alpha: 0.08 + (3 - i) * 0.06,
                  ),
                  width: 1.5,
                ),
                color: Colors.transparent,
              ),
            ),
          Icon(
            Icons.favorite_rounded,
            size: size * 0.5,
            color: palette.accent.withValues(alpha: 0.75),
          ),
        ],
      ),
    );
  }
}
