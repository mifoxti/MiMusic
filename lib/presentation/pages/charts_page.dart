import 'package:flutter/material.dart';

import '../../core/audio/audio_player_service.dart';
import '../../core/audio/local_tracks.dart';
import '../../core/audio/track.dart';
import '../../core/constants/app_constants.dart';
import '../../core/l10n/app_localization.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/track_cover.dart';
import '../../core/player/player_dock_host.dart';

/// Запись в чарте (локальные данные до подключения API).
class ChartEntry {
  const ChartEntry({
    required this.rank,
    required this.track,
    required this.playsLabel,
    this.deltaLabel,
  });

  final int rank;
  final Track track;
  /// Подпись вроде «842 тыс. прослушиваний».
  final String playsLabel;
  /// Только «NEW» для бейджа; иначе null.
  final String? deltaLabel;
}

/// Страница «Чарты»: топ треков, воспроизведение с очередью по порядку чарта.
class ChartsPage extends StatefulWidget {
  const ChartsPage({
    super.key,
    required this.audioPlayerService,
  });

  final AudioPlayerService audioPlayerService;

  @override
  State<ChartsPage> createState() => _ChartsPageState();
}

class _ChartsPageState extends State<ChartsPage> {
  List<ChartEntry> _entries = [];
  List<Track> _chartTracks = [];
  bool _isLoading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final tracks = await loadLocalTracks();
    if (!mounted) return;

    // Пока нет API: порядок = локальный список, подписи — заглушки.
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final playsMocks = [
      isEn ? '1.2M plays' : '1,2 млн прослушиваний',
      isEn ? '982K plays' : '982 тыс. прослушиваний',
      isEn ? '756K plays' : '756 тыс. прослушиваний',
    ];
    const deltaMocks = <String?>[null, null, 'NEW'];

    final entries = <ChartEntry>[];
    for (var i = 0; i < tracks.length; i++) {
      entries.add(
        ChartEntry(
          rank: i + 1,
          track: tracks[i],
          playsLabel: i < playsMocks.length
              ? playsMocks[i]
              : (isEn ? '${(340 - i * 12)}K plays' : '${(340 - i * 12)} тыс. прослушиваний'),
          deltaLabel: i < deltaMocks.length ? deltaMocks[i] : null,
        ),
      );
    }

    setState(() {
      _entries = entries;
      _chartTracks = tracks;
      _isLoading = false;
    });
  }

  void _openFullPlayer() {
    PlayerDockHost.expand();
  }

  Future<void> _onPlayAll() async {
    if (_chartTracks.isEmpty) return;
    await widget.audioPlayerService.playTrack(
      _chartTracks.first,
      queue: _chartTracks,
    );
  }

  Future<void> _onPlayAllPressed() async {
    if (_chartTracks.isEmpty) return;
    final service = widget.audioPlayerService;
    if (service.currentTrack != null) {
      await service.togglePlayPause();
    } else {
      await _onPlayAll();
    }
  }

  Future<void> _onTrackTap(Track track) async {
    final service = widget.audioPlayerService;
    final same = service.currentTrack?.assetPath == track.assetPath &&
        service.currentTrack?.audioFilePath == track.audioFilePath;
    if (same) {
      await service.togglePlayPause();
      return;
    }
    await service.playTrack(track, queue: _chartTracks);
    if (mounted) _openFullPlayer();
  }

  Color _rankColor(AppColorPalette palette, int rank) {
    return switch (rank) {
      1 => const Color(0xFFD4A574),
      2 => const Color(0xFFB8B8C8),
      3 => const Color(0xFFC4956A),
      _ => palette.textMuted,
    };
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
          title: Text(context.t('charts.title')),
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
                if (_entries.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Center(
                        child: Text(
                          context.t('home.addTracksHint'),
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
                          final entry = _entries[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _ChartTrackTile(
                              entry: entry,
                              rankColor: _rankColor(palette, entry.rank),
                              onTap: () => _onTrackTap(entry.track),
                            ),
                          );
                        },
                        childCount: _entries.length,
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
          _buildChartIconCluster(),
          const SizedBox(height: 16),
          Text(
            context.t('charts.topTracks'),
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: palette.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.t('charts.updatedDaily'),
            style: TextStyle(
              fontSize: 14,
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _chartTracks.isEmpty ? null : _onPlayAllPressed,
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
                  color: const Color(0xFFC45C3E).withValues(alpha: 0.35),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFC45C3E).withValues(alpha: 0.22),
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

  Widget _buildChartIconCluster() {
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
                  color: const Color(0xFFC45C3E).withValues(
                    alpha: 0.08 + (3 - i) * 0.07,
                  ),
                  width: 1.5,
                ),
                color: Colors.transparent,
              ),
            ),
          Icon(
            Icons.show_chart_rounded,
            size: size * 0.48,
            color: const Color(0xFFC45C3E).withValues(alpha: 0.85),
          ),
        ],
      ),
    );
  }
}

class _ChartTrackTile extends StatelessWidget {
  const _ChartTrackTile({
    required this.entry,
    required this.rankColor,
    required this.onTap,
  });

  final ChartEntry entry;
  final Color rankColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const coverSize = 56.0;
    final palette = AppPaletteExtension.of(context).palette;
    final track = entry.track;
    final coverSource = track.coverBytes ?? track.coverFallbackPath;

    return Material(
      color: palette.cardBackground.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                child: Text(
                  '${entry.rank}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: rankColor,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                child: SizedBox(
                  width: coverSize,
                  height: coverSize,
                  child: buildTrackCover(
                    coverSource: coverSource,
                    width: coverSize,
                    height: coverSize,
                    borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                    placeholder: Container(
                      color: palette.primaryDark.withValues(alpha: 0.5),
                      child: Icon(
                        Icons.music_note_rounded,
                        color: palette.textMuted,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      track.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: palette.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      track.artistDisplay.isEmpty
                          ? context.t('common.unknownArtist')
                          : track.artistDisplay,
                      style: TextStyle(
                        fontSize: 13,
                        color: palette.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.playsLabel,
                            style: TextStyle(
                              fontSize: 12,
                              color: palette.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (entry.deltaLabel != null &&
                            entry.deltaLabel!.toUpperCase() == 'NEW') ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: palette.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              entry.deltaLabel!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: palette.accent,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: palette.textMuted,
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
