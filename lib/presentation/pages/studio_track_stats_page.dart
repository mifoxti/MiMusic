import 'package:flutter/material.dart';

import '../../core/l10n/app_localization.dart';
import '../../core/network/server_connectivity.dart';
import '../../core/network/studio_stats_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/glass_bar_chart.dart';
import '../widgets/glass_panel.dart';

/// Статистика одного трека в студии.
class StudioTrackStatsPage extends StatefulWidget {
  const StudioTrackStatsPage({
    super.key,
    required this.trackId,
    required this.trackTitle,
    this.artist,
  });

  final int trackId;
  final String trackTitle;
  final String? artist;

  @override
  State<StudioTrackStatsPage> createState() => _StudioTrackStatsPageState();
}

class _StudioTrackStatsPageState extends State<StudioTrackStatsPage> {
  TrackStudioStatsDto? _stats;
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
      final stats = await StudioStatsApi().fetchTrackStats(widget.trackId, days: 14);
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

  String _formatPlays(int n, BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    if (n >= 1000) {
      return isEn ? '${(n / 1000).toStringAsFixed(1)}K' : '${(n / 1000).toStringAsFixed(1)} тыс.';
    }
    return '$n';
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
          title: Text(context.t('studio.stats.trackTitle')),
          backgroundColor: Colors.transparent,
        ),
        body: _loading
            ? Center(child: CircularProgressIndicator(color: palette.accent))
            : _error != null
                ? Center(child: Text(_error!, style: TextStyle(color: palette.textSecondary)))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      children: [
                        Text(
                          widget.trackTitle,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: palette.textPrimary,
                          ),
                        ),
                        if ((widget.artist ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.artist!,
                            style: TextStyle(fontSize: 14, color: palette.textSecondary),
                          ),
                        ],
                        const SizedBox(height: 16),
                        _buildMetrics(context, palette, _stats!),
                        const SizedBox(height: 16),
                        _buildChart(context, palette, _stats!),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildMetrics(BuildContext context, AppColorPalette palette, TrackStudioStatsDto s) {
    return GlassPanel(
      child: Row(
        children: [
          Expanded(
            child: GlassStatTile(
              icon: Icons.play_circle_outline_rounded,
              label: context.t('studio.stats.totalPlays'),
              value: _formatPlays(s.totalPlays, context),
              accentColor: palette.accent,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: GlassStatTile(
              icon: Icons.person_outline_rounded,
              label: context.t('studio.stats.listeners'),
              value: '${s.uniqueListeners}',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(BuildContext context, AppColorPalette palette, TrackStudioStatsDto s) {
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
}
