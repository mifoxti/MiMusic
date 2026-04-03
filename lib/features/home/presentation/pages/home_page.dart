import 'package:flutter/material.dart';

import '../../../../core/audio/audio_player_service.dart';
import '../../../../core/audio/local_tracks.dart';
import '../../../../core/audio/track.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../presentation/pages/charts_page.dart';
import '../../domain/entities/home_section.dart';
import '../../domain/use_cases/get_home_section_use_case.dart';
import '../widgets/featured_track_card.dart';
import '../widgets/friends_section.dart';
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
  });

  final GetHomeSectionUseCase getHomeSectionUseCase;
  final AudioPlayerService audioPlayerService;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  HomeSection? _section;
  List<Track> _localTracks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        widget.getHomeSectionUseCase(),
        loadLocalTracks(),
      ]);
      if (mounted) {
        setState(() {
          _section = results[0] as HomeSection;
          _localTracks = results[1] as List<Track>;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onFeaturedTrackTap(Track track) async {
    if (widget.audioPlayerService.currentTrack?.assetPath == track.assetPath) {
      await widget.audioPlayerService.togglePlayPause();
    } else {
      await widget.audioPlayerService.playTrack(track, queue: _localTracks);
    }
  }

  void _openCharts(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChartsPage(
          audioPlayerService: widget.audioPlayerService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: palette.accent));
    }
    if (_section == null) {
      return Center(
        child: Text('Ошибка загрузки', style: TextStyle(color: palette.textSecondary)),
      );
    }

    final featuredTrack = _localTracks.isNotEmpty ? _localTracks.first : null;

    final topPadding = MediaQuery.paddingOf(context).top;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 16 + topPadding, 24, 0),
            child: Column(
              children: [
                Text(
                  'MiMusic',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: palette.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 20),
                if (featuredTrack != null)
                  ListenableBuilder(
                    listenable: widget.audioPlayerService,
                    builder: (context, _) {
                      final isCurrent = widget.audioPlayerService.currentTrack?.assetPath == featuredTrack.assetPath;
                      final dur = widget.audioPlayerService.duration;
                      final pos = widget.audioPlayerService.position;
                      final progress = isCurrent && dur != null && dur.inMilliseconds > 0
                          ? pos.inMilliseconds / dur.inMilliseconds
                          : 0.0;
                      return FeaturedTrackCard(
                        track: featuredTrack,
                        isPlaying: isCurrent && widget.audioPlayerService.isPlaying,
                        progress: progress,
                        onTap: () => _onFeaturedTrackTap(featuredTrack),
                      );
                    },
                  )
                else
                  _buildNoTracksPlaceholder(palette),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    NavCardButton(
                      title: 'Для вас',
                      onTap: () {},
                      avatarColors: const [
                        Color(0xFF5C4A50),
                        Color(0xFF4A3D42),
                      ],
                    ),
                    const SizedBox(width: 12),
                    NavCardButton(
                      title: 'Чарты',
                      onTap: () => _openCharts(context),
                      avatarColors: const [
                        Color(0xFFC45C3E),
                        Color(0xFF8B3A2E),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                HistorySection.fromSection(_section!),
                const SizedBox(height: 20),
                FriendsSection(
                  friendPlayback: _section!.friendPlayback,
                  listeningFriends: _section!.listeningFriends,
                ),
                const SizedBox(height: 20),
                ReleasesSection(releases: _section!.latestReleases),
                const SizedBox(height: 88),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoTracksPlaceholder(AppColorPalette palette) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: palette.cardBackground.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.music_off_rounded, size: 32, color: palette.textMuted),
          const SizedBox(width: 12),
          Text(
            'Добавьте треки в assets/music/',
            style: TextStyle(fontSize: 14, color: palette.textSecondary),
          ),
        ],
      ),
    );
  }
}
