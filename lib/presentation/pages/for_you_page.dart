import 'package:flutter/material.dart';

import '../../core/audio/audio_player_service.dart';
import '../../core/audio/local_tracks.dart';
import '../../core/audio/track.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/track_cover.dart';
import '../../features/home/domain/entities/friend_playback.dart';
import '../../features/home/domain/entities/home_section.dart';
import '../../features/home/domain/use_cases/get_home_section_use_case.dart';
import '../../core/player/player_dock_host.dart';

/// Экран «Для вас»: персональные подборки на основе главной секции и локальных треков.
class ForYouPage extends StatefulWidget {
  const ForYouPage({
    super.key,
    required this.audioPlayerService,
    required this.getHomeSectionUseCase,
  });

  final AudioPlayerService audioPlayerService;
  final GetHomeSectionUseCase getHomeSectionUseCase;

  @override
  State<ForYouPage> createState() => _ForYouPageState();
}

class _ForYouPageState extends State<ForYouPage> {
  HomeSection? _section;
  List<Track> _tracks = [];
  List<Track> _recommendedOrder = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final section = await widget.getHomeSectionUseCase();
      final tracks = await loadLocalTracks();
      if (!mounted) return;
      setState(() {
        _section = section;
        _tracks = tracks;
        _recommendedOrder = _buildRecommendedOrder(section, tracks);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Треки, совпадающие с артистами из истории, выше остальных.
  List<Track> _buildRecommendedOrder(HomeSection section, List<Track> tracks) {
    final hints = section.historyArtists
        .map((e) => e.toLowerCase().trim())
        .where((e) => e.isNotEmpty)
        .toList();
    int score(Track t) {
      final a = t.artistDisplay.toLowerCase();
      final title = t.title.toLowerCase();
      for (final h in hints) {
        if (a.contains(h) || title.contains(h)) return 1;
      }
      return 0;
    }

    final sorted = List<Track>.from(tracks);
    sorted.sort((a, b) => score(b).compareTo(score(a)));
    return sorted;
  }

  void _openFullPlayer() {
    PlayerDockHost.expand();
  }

  Future<void> _onTrackTap(Track track) async {
    final queue = _recommendedOrder.isNotEmpty ? _recommendedOrder : _tracks;
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
    final queue = _recommendedOrder.isNotEmpty ? _recommendedOrder : _tracks;
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
          title: const Text('Для вас'),
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
            if (_loading || _section == null) {
              return Center(
                child: CircularProgressIndicator(color: palette.accent),
              );
            }
            final section = _section!;
            final queue = _recommendedOrder.isNotEmpty ? _recommendedOrder : _tracks;

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeaderCluster(palette),
                        const SizedBox(height: 18),
                        Text(
                          'Подборка по вашим интересам',
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
                                  boxShadow: [
                                    BoxShadow(
                                      color: palette.accent.withValues(alpha: 0.22),
                                      blurRadius: 18,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
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
                        const SizedBox(height: 8),
                        Text(
                          queue.isEmpty
                              ? 'Добавьте треки в assets/music/'
                              : 'Слушать персональный поток',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: palette.textMuted,
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          'Собрано для вас',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: palette.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Из вашей библиотеки',
                          style: TextStyle(
                            fontSize: 13,
                            color: palette.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                    ),
                  ),
                ),
                if (queue.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      child: _buildEmptyTracksHint(palette),
                    ),
                  )
                else
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 196,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        scrollDirection: Axis.horizontal,
                        itemCount: queue.length,
                        separatorBuilder: (context, _) =>
                            const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          return _ForYouTrackCard(
                            track: queue[index],
                            palette: palette,
                            onTap: () => _onTrackTap(queue[index]),
                          );
                        },
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (section.friendPlayback != null) ...[
                          Text(
                            'Сейчас у друзей',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: palette.textPrimary,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _FriendPlaybackCard(
                            playback: section.friendPlayback!,
                            palette: palette,
                          ),
                        ],
                      ],
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

  Widget _buildHeaderCluster(AppColorPalette palette) {
    const size = 80.0;
    return Center(
      child: SizedBox(
        width: size + 40,
        height: size + 40,
        child: Stack(
          alignment: Alignment.center,
          children: [
            for (var i = 3; i >= 0; i--)
              Container(
                width: size + (i * 14.0),
                height: size + (i * 14.0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: palette.accent.withValues(
                      alpha: 0.07 + (3 - i) * 0.06,
                    ),
                    width: 1.5,
                  ),
                ),
              ),
            Icon(
              Icons.auto_awesome_rounded,
              size: size * 0.45,
              color: palette.accent.withValues(alpha: 0.9),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyTracksHint(AppColorPalette palette) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.cardBackground.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
      ),
      child: Row(
        children: [
          Icon(Icons.music_off_rounded, color: palette.textMuted, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Когда появятся файлы в assets/music/, здесь будет персональная лента.',
              style: TextStyle(fontSize: 14, color: palette.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _ForYouTrackCard extends StatelessWidget {
  const _ForYouTrackCard({
    required this.track,
    required this.palette,
    required this.onTap,
  });

  final Track track;
  final AppColorPalette palette;
  final VoidCallback onTap;

  static const double _cover = 120.0;

  @override
  Widget build(BuildContext context) {
    final coverSource = track.coverBytes ?? track.coverFallbackPath;

    return SizedBox(
      width: 132,
      child: Material(
        color: palette.cardBackground.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: buildTrackCover(
                      coverSource: coverSource,
                      width: _cover,
                      height: _cover,
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusMedium),
                      placeholder: Container(
                        color: palette.primaryDark.withValues(alpha: 0.5),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.music_note_rounded,
                          color: palette.textMuted,
                          size: 36,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  track.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: palette.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  track.artistDisplay.isEmpty
                      ? 'Исполнитель'
                      : track.artistDisplay,
                  style: TextStyle(
                    fontSize: 11,
                    color: palette.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FriendPlaybackCard extends StatelessWidget {
  const _FriendPlaybackCard({
    required this.playback,
    required this.palette,
  });

  final FriendPlayback playback;
  final AppColorPalette palette;

  @override
  Widget build(BuildContext context) {
    final cover = playback.coverUrl;

    return Material(
      color: palette.cardBackground,
      borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${playback.artistName} — ${playback.title}'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: cover != null
                      ? Image.asset(
                          cover,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _placeholder(palette),
                        )
                      : _placeholder(palette),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playback.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: palette.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      playback.artistName,
                      style: TextStyle(
                        fontSize: 13,
                        color: palette.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.play_circle_outline_rounded, color: palette.accent),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder(AppColorPalette palette) {
    return Container(
      color: palette.primaryDark.withValues(alpha: 0.45),
      alignment: Alignment.center,
      child: Icon(Icons.person_rounded, color: palette.textMuted),
    );
  }
}
