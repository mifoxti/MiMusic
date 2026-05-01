import 'package:flutter/material.dart';

import '../../core/audio/audio_player_service.dart';
import '../../core/audio/local_tracks.dart';
import '../../core/audio/track.dart';
import '../../core/constants/app_constants.dart';
import '../../core/l10n/app_localization.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/player/player_dock_host.dart';
import '../widgets/favorite_track_item.dart';

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
  int? _lastLikedCount;

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
    final count = widget.audioPlayerService.likedPaths.length;
    if (_lastLikedCount != null && _lastLikedCount != count && mounted) {
      _loadFavorites();
    }
    _lastLikedCount = count;
  }

  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);
    final allTracks = await loadLocalTracks();
    if (mounted) {
      final liked = widget.audioPlayerService.likedPaths;
      setState(() {
        _favoriteTracks = allTracks.where((t) => liked.contains(t.assetPath)).toList();
        _isLoading = false;
        _lastLikedCount = liked.length;
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
    await widget.audioPlayerService.removeFromFavorites(track.assetPath);
    if (mounted) _loadFavorites();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    final topPadding = MediaQuery.paddingOf(context).top;

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
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Center(
                        child: Text(
                          context.t('favorites.empty'),
                          style: TextStyle(
                            fontSize: 15,
                            color: palette.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(20, 8, 20, bottomContentInset),
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
                            onMore: () {},
                          );
                        },
                        childCount: _favoriteTracks.length,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(AppColorPalette palette, double topPadding) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 8 + topPadding, 24, 24),
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
