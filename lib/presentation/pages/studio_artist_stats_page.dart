import 'package:flutter/material.dart';

import '../../core/audio/audio_player_service.dart';
import '../../core/l10n/app_localization.dart';
import '../../core/network/server_connectivity.dart';
import '../../core/network/studio_stats_api.dart';
import '../../core/player/shell_route_back_guard.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'studio_stats_format.dart';
import 'studio_track_stats_page.dart';
import '../widgets/glass_bar_chart.dart';
import '../widgets/glass_panel.dart';

/// Статистика автора в студии.
class StudioArtistStatsPage extends StatefulWidget {
  const StudioArtistStatsPage({
    super.key,
    this.nickname,
    this.audioPlayerService,
  });

  final String? nickname;
  final AudioPlayerService? audioPlayerService;

  @override
  State<StudioArtistStatsPage> createState() => _StudioArtistStatsPageState();
}

class _StudioArtistStatsPageState extends State<StudioArtistStatsPage> {
  MeStudioStatsDto? _stats;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    if (!await ServerConnectivity.instance.guardUserNetworkAction(context)) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stats = await StudioStatsApi().fetchArtistStats(days: 14);
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      await ServerConnectivity.instance.reportNetworkErrorIfOffline(context, e);
      setState(() {
        _error = context.t('common.errorLoading');
        _loading = false;
      });
    }
  }

  void _showExact(BuildContext context, String title, int count) {
    showStudioExactCountHint(context, title: title, count: count);
  }

  Widget _statsList(MeStudioStatsDto stats, AppColorPalette palette) {
    final nick = widget.nickname?.trim();
    final playsLabel = context.t('studio.stats.totalPlays');
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: studioStatsListPadding(widget.audioPlayerService),
      children: [
        if (nick != null && nick.isNotEmpty)
          Text(
            '@$nick',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: palette.textPrimary,
            ),
          ),
        if (nick != null && nick.isNotEmpty) const SizedBox(height: 16),
        _buildMetrics(context, palette, stats, playsLabel),
        const SizedBox(height: 16),
        _buildChart(context, palette, stats),
        const SizedBox(height: 16),
        _buildTopTracks(context, palette, stats, playsLabel),
      ],
    );
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
          title: Text(context.t('studio.stats.artistTitle')),
          backgroundColor: Colors.transparent,
        ),
        body: _loading
            ? Center(child: CircularProgressIndicator(color: palette.accent))
            : _error != null
                ? Center(
                    child: Text(
                      _error!,
                      style: TextStyle(color: palette.textSecondary),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: widget.audioPlayerService == null
                        ? _statsList(_stats!, palette)
                        : ListenableBuilder(
                            listenable: widget.audioPlayerService!,
                            builder: (context, _) =>
                                _statsList(_stats!, palette),
                          ),
                  ),
      ),
    );
  }

  Widget _buildMetrics(
    BuildContext context,
    AppColorPalette palette,
    MeStudioStatsDto s,
    String playsLabel,
  ) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Center(
                child: GlassStatTile(
                  icon: Icons.headphones_rounded,
                  label: playsLabel,
                  value: formatStudioCompactCount(s.totalPlays, context),
                  metricValue: s.totalPlays,
                  accentColor: palette.accent,
                  onShowExact: (ctx, n) => _showExact(ctx, playsLabel, n),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: GlassStatTile(
                  icon: Icons.library_music_rounded,
                  label: context.t('studio.stats.tracks'),
                  value: formatStudioCompactCount(s.totalTracks, context),
                  metricValue: s.totalTracks,
                  onShowExact: (ctx, n) =>
                      _showExact(ctx, context.t('studio.stats.tracks'), n),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: GlassStatTile(
                  icon: Icons.people_outline_rounded,
                  label: context.t('studio.stats.listeners'),
                  value: formatStudioCompactCount(s.uniqueListeners, context),
                  metricValue: s.uniqueListeners,
                  onShowExact: (ctx, n) =>
                      _showExact(ctx, context.t('studio.stats.listeners'), n),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(
    BuildContext context,
    AppColorPalette palette,
    MeStudioStatsDto s,
  ) {
    final days = s.playsByDay;
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('studio.stats.playsChart'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.t('studio.stats.last14days'),
            style: TextStyle(fontSize: 12, color: palette.textSecondary),
          ),
          const SizedBox(height: 16),
          GlassBarChart(
            values: days.map((d) => d.count).toList(),
            labels: days.map((d) => shortDayLabel(d.date)).toList(),
            barColor: palette.accent,
          ),
        ],
      ),
    );
  }

  Widget _buildTopTracks(
    BuildContext context,
    AppColorPalette palette,
    MeStudioStatsDto s,
    String playsLabel,
  ) {
    if (s.topTracks.isEmpty) {
      return GlassPanel(
        child: Text(
          context.t('studio.stats.noPlaysYet'),
          style: TextStyle(color: palette.textSecondary),
        ),
      );
    }
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('studio.stats.topTracks'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...s.topTracks.asMap().entries.map((e) {
            final t = e.value;
            final rank = e.key + 1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    Navigator.of(context).push(
                      ShellMaterialPageRoute<void>(
                        builder: (_) => StudioTrackStatsPage(
                          trackId: t.trackId,
                          trackTitle: t.title,
                          audioPlayerService: widget.audioPlayerService,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 4,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 28,
                          child: Text(
                            '$rank',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: rank <= 3
                                  ? palette.accent
                                  : palette.textMuted,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            t.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: palette.textPrimary,
                            ),
                          ),
                        ),
                        StudioPlayCountText(
                          count: t.playCount,
                          hintTitle: playsLabel,
                        ),
                        Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: palette.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
