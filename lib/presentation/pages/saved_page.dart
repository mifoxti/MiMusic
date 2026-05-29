import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/audio/audio_player_service.dart';
import '../../core/constants/app_constants.dart';
import '../../core/l10n/app_localization.dart';
import '../../core/network/playlists_api.dart';
import '../../core/offline/offline_download_repository.dart';
import '../../core/player/shell_route_back_guard.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/cover_image.dart';
import 'playlist_detail_page.dart';

enum _SavedTab { tracks, playlists }

class SavedPage extends StatefulWidget {
  const SavedPage({
    super.key,
    required this.audioPlayerService,
    required this.offlineDownloads,
  });

  final AudioPlayerService audioPlayerService;
  final OfflineDownloadRepository offlineDownloads;

  @override
  State<SavedPage> createState() => _SavedPageState();
}

class _SavedPageState extends State<SavedPage> {
  _SavedTab _tab = _SavedTab.tracks;

  @override
  void initState() {
    super.initState();
    widget.offlineDownloads.addListener(_onOfflineChanged);
    unawaited(widget.offlineDownloads.ensureLoaded());
  }

  @override
  void dispose() {
    widget.offlineDownloads.removeListener(_onOfflineChanged);
    super.dispose();
  }

  void _onOfflineChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    final tracks = widget.offlineDownloads.downloadedTracks;
    final playlists = widget.offlineDownloads.savedPlaylists;

    return Scaffold(
      backgroundColor: palette.gradientStart,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(context.t('profile.saved')),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SegmentedButton<_SavedTab>(
              segments: [
                ButtonSegment(
                  value: _SavedTab.tracks,
                  label: Text(context.t('profile.savedTracks')),
                  icon: const Icon(Icons.music_note_rounded),
                ),
                ButtonSegment(
                  value: _SavedTab.playlists,
                  label: Text(context.t('profile.savedPlaylists')),
                  icon: const Icon(Icons.playlist_play_rounded),
                ),
              ],
              selected: {_tab},
              onSelectionChanged: (s) => setState(() => _tab = s.first),
            ),
          ),
          Expanded(
            child: _tab == _SavedTab.tracks
                ? _TracksTab(
                    tracks: tracks,
                    audioPlayerService: widget.audioPlayerService,
                    offlineDownloads: widget.offlineDownloads,
                    palette: palette,
                  )
                : _PlaylistsTab(
                    playlists: playlists,
                    offlineDownloads: widget.offlineDownloads,
                    audioPlayerService: widget.audioPlayerService,
                    palette: palette,
                  ),
          ),
        ],
      ),
    );
  }
}

class _TracksTab extends StatelessWidget {
  const _TracksTab({
    required this.tracks,
    required this.audioPlayerService,
    required this.offlineDownloads,
    required this.palette,
  });

  final List<OfflineTrackRecord> tracks;
  final AudioPlayerService audioPlayerService;
  final OfflineDownloadRepository offlineDownloads;
  final AppColorPalette palette;

  @override
  Widget build(BuildContext context) {
    if (tracks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            context.t('profile.savedTracksEmpty'),
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.textSecondary),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
      itemCount: tracks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final record = tracks[index];
        final track = record.toTrack();
        return Material(
          color: palette.cardBackground.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: buildCoverImage(
                imageUrl: track.coverFallbackPath,
                width: 48,
                height: 48,
                borderRadius: BorderRadius.circular(8),
                placeholder: Container(
                  width: 48,
                  height: 48,
                  color: palette.accent.withValues(alpha: 0.2),
                  child: Icon(Icons.music_note_rounded, color: palette.accent),
                ),
              ),
            ),
            title: Text(
              track.title,
              style: TextStyle(
                color: palette.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              track.artistDisplay,
              style: TextStyle(color: palette.textSecondary, fontSize: 13),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              color: palette.textSecondary,
              onPressed: () => unawaited(
                offlineDownloads.removeTrack(record.assetKey),
              ),
            ),
            onTap: () => unawaited(
              audioPlayerService.playTrack(
                track,
                queue: tracks.map((t) => t.toTrack()).toList(),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PlaylistsTab extends StatelessWidget {
  const _PlaylistsTab({
    required this.playlists,
    required this.offlineDownloads,
    required this.audioPlayerService,
    required this.palette,
  });

  final List<OfflinePlaylistRecord> playlists;
  final OfflineDownloadRepository offlineDownloads;
  final AudioPlayerService audioPlayerService;
  final AppColorPalette palette;

  @override
  Widget build(BuildContext context) {
    if (playlists.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            context.t('profile.savedPlaylistsEmpty'),
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.textSecondary),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
      itemCount: playlists.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final playlist = playlists[index];
        return Material(
          color: palette.cardBackground.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: buildCoverImage(
                imageUrl: playlistCoverUrl(playlist.playlistId),
                width: 48,
                height: 48,
                borderRadius: BorderRadius.circular(8),
                placeholder: Container(
                  width: 48,
                  height: 48,
                  color: palette.accent.withValues(alpha: 0.2),
                  child: Icon(
                    Icons.playlist_play_rounded,
                    color: palette.accent,
                  ),
                ),
              ),
            ),
            title: Text(
              playlist.title,
              style: TextStyle(
                color: palette.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              context.t('profile.savedPlaylistTracks')
                  .replaceAll('{count}', '${playlist.trackIds.length}'),
              style: TextStyle(color: palette.textSecondary, fontSize: 13),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              color: palette.textSecondary,
              onPressed: () => unawaited(
                offlineDownloads.removePlaylist(playlist.playlistId),
              ),
            ),
            onTap: () {
              Navigator.of(context).push(
                ShellMaterialPageRoute<void>(
                  builder: (_) => PlaylistDetailPage(
                    playlistId: 'srv:${playlist.playlistId}',
                    audioPlayerService: audioPlayerService,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
