import 'package:flutter/material.dart';

import '../../core/audio/audio_player_service.dart';
import '../../core/audio/track.dart';
import '../../core/constants/app_constants.dart';
import '../../core/l10n/app_localization.dart';
import 'dart:async';

import '../../core/history/api_listening_history_repository.dart';
import '../../core/history/listening_history_entry.dart';
import '../../core/history/listening_history_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/track_cover.dart';
import '../../core/player/player_dock_host.dart';

/// Экран истории прослушивания (сейчас данные из [ListeningHistoryRepository] в памяти).
class ListeningHistoryPage extends StatefulWidget {
  const ListeningHistoryPage({
    super.key,
    required this.audioPlayerService,
    required this.listeningHistoryRepository,
  });

  final AudioPlayerService audioPlayerService;
  final ListeningHistoryRepository listeningHistoryRepository;

  @override
  State<ListeningHistoryPage> createState() => _ListeningHistoryPageState();
}

class _ListeningHistoryPageState extends State<ListeningHistoryPage> {
  @override
  void initState() {
    super.initState();
    final repo = widget.listeningHistoryRepository;
    if (repo is ApiListeningHistoryRepository) {
      unawaited(repo.ensureLoaded());
    }
  }

  void _openFullPlayer() {
    PlayerDockHost.expand();
  }

  bool _isSameTrack(Track? current, Track t) {
    if (current == null) return false;
    final cFile = current.audioFilePath;
    final tFile = t.audioFilePath;
    if (cFile != null && tFile != null) return cFile == tFile;
    return current.assetPath == t.assetPath;
  }

  Future<void> _onEntryTap(ListeningHistoryEntry entry) async {
    final tracks = widget.listeningHistoryRepository.entries
        .map((e) => e.toTrack())
        .toList();
    final track = entry.toTrack();
    final service = widget.audioPlayerService;
    if (_isSameTrack(service.currentTrack, track)) {
      await service.togglePlayPause();
      return;
    }
    await service.playTrack(track, queue: tracks);
    if (mounted) _openFullPlayer();
  }

  String _groupLabel(DateTime playedAt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(playedAt.year, playedAt.month, playedAt.day);
    if (d == today) return context.t('history.today');
    if (d == today.subtract(const Duration(days: 1))) return context.t('history.yesterday');
    return context.t('history.earlier');
  }

  List<({String label, List<ListeningHistoryEntry> items})> _grouped(
    List<ListeningHistoryEntry> entries,
  ) {
    final keys = <String>[];
    final map = <String, List<ListeningHistoryEntry>>{};
    for (final e in entries) {
      final label = _groupLabel(e.playedAt);
      if (!map.containsKey(label)) {
        keys.add(label);
        map[label] = [];
      }
      map[label]!.add(e);
    }
    return [
      for (final k in keys) (label: k, items: map[k]!),
    ];
  }

  String _formatTime(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
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
          title: Text(context.t('history.title')),
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
          listenable: widget.listeningHistoryRepository,
          builder: (context, _) {
            final entries = widget.listeningHistoryRepository.entries;
            if (entries.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 56,
                        color: palette.textMuted.withValues(alpha: 0.7),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        context.t('history.empty'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: palette.textPrimary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final groups = _grouped(entries);

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
              itemCount: groups.length,
              itemBuilder: (context, gi) {
                final g = groups[gi];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: gi > 0 ? 20 : 0, bottom: 10),
                      child: Text(
                        g.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: palette.textMuted,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    for (final entry in g.items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _HistoryTrackTile(
                          entry: entry,
                          palette: palette,
                          timeLabel: _formatTime(entry.playedAt),
                          onTap: () => _onEntryTap(entry),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

}

class _HistoryTrackTile extends StatelessWidget {
  const _HistoryTrackTile({
    required this.entry,
    required this.palette,
    required this.timeLabel,
    required this.onTap,
  });

  final ListeningHistoryEntry entry;
  final AppColorPalette palette;
  final String timeLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const coverSize = 56.0;
    final track = entry.toTrack();
    final coverSource = track.coverBytes ?? track.coverFallbackPath;

    return Material(
      color: palette.cardBackground.withValues(alpha: 0.88),
      borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
              ClipRRect(
                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                child: SizedBox(
                  width: coverSize,
                  height: coverSize,
                  child: buildTrackCover(
                    coverSource: coverSource,
                    width: coverSize,
                    height: coverSize,
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusMedium),
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
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
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
                      entry.artistDisplay.isEmpty
                          ? context.t('common.notSpecifiedArtist')
                          : entry.artistDisplay,
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
              Text(
                timeLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: palette.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
