import 'package:flutter/material.dart';

import '../../core/audio/audio_player_service.dart';
import '../../core/audio/track.dart';
import '../../core/constants/app_constants.dart';
import '../../core/l10n/app_localization.dart';
import '../../core/platform/platform.dart';
import '../../core/player/player_dock_host.dart';
import '../../core/studio/album.dart';
import '../../core/studio/studio_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/track_cover.dart';
import 'studio_editor_pages.dart';
import 'studio_ui_helpers.dart';

/// Экран альбома студии: треки, добавление из библиотеки, загрузка нового трека.
class StudioAlbumDetailPage extends StatefulWidget {
  const StudioAlbumDetailPage({
    super.key,
    required this.albumId,
    required this.studioRepository,
    required this.audioPlayerService,
    required this.onStudioDataChanged,
    required this.showAlbumEditDialog,
    required this.onCreateNewStudioTrackReturnId,
    required this.showEditTrackDialog,
    required this.onDeleteAlbum,
  });

  final String albumId;
  final StudioRepository studioRepository;
  final AudioPlayerService audioPlayerService;
  final Future<void> Function() onStudioDataChanged;
  final Future<Album?> Function(Album album) showAlbumEditDialog;
  final Future<String?> Function() onCreateNewStudioTrackReturnId;
  final Future<({String assetPath, TrackMetadataOverride metadata})?> Function(
    Track track,
  ) showEditTrackDialog;
  final Future<void> Function(Album album) onDeleteAlbum;

  @override
  State<StudioAlbumDetailPage> createState() => _StudioAlbumDetailPageState();
}

class _StudioAlbumDetailPageState extends State<StudioAlbumDetailPage> {
  Album? _album;
  List<Track> _libraryTracks = [];
  Map<String, TrackMetadataOverride> _overrides = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final albums = await widget.studioRepository.getAlbums();
    final overrides = await widget.studioRepository.getTrackMetadataOverrides();
    final customPaths = await widget.studioRepository.getCustomTrackPaths();
    if (!mounted) return;
    Album? found;
    for (final a in albums) {
      if (a.id == widget.albumId) {
        found = a;
        break;
      }
    }
    final untitled = context.t('playlists.untitled');
    final customTracks = <Track>[];
    for (final id in customPaths) {
      final o = overrides[id];
      final artistStr = (o != null && o.displayArtist.isNotEmpty) ? o.displayArtist : o?.artist;
      customTracks.add(Track(
        assetPath: id,
        title: o?.title ?? untitled,
        artist: artistStr,
        coverAssetPath: o?.coverPath,
        audioFilePath: o?.audioFilePath,
      ));
    }
    setState(() {
      _album = found;
      _overrides = overrides;
      _libraryTracks = customTracks;
      _loading = false;
    });
  }

  Track _withOverrides(Track t) {
    final o = _overrides[t.assetPath];
    if (o == null) return t;
    final artistStr = o.displayArtist.isNotEmpty ? o.displayArtist : o.artist ?? t.artist;
    return Track(
      assetPath: t.assetPath,
      title: o.title ?? t.title,
      artist: artistStr,
      coverBytes: t.coverBytes,
      coverAssetPath: o.coverPath ?? t.coverAssetPath,
      audioFilePath: o.audioFilePath ?? t.audioFilePath,
    );
  }

  List<Track> _albumTracksOrdered() {
    final album = _album;
    if (album == null) return [];
    final byId = {for (final t in _libraryTracks) t.assetPath: t};
    final out = <Track>[];
    for (final id in album.trackAssetPaths) {
      final t = byId[id];
      if (t != null) out.add(_withOverrides(t));
    }
    return out;
  }

  Future<void> _saveAlbum(Album next) async {
    final all = await widget.studioRepository.getAlbums();
    final updated = all.map((a) => a.id == next.id ? next : a).toList();
    await widget.studioRepository.saveAlbums(updated);
    if (mounted) {
      await widget.onStudioDataChanged();
      await _load();
    }
  }

  Future<void> _addFromLibrary() async {
    final album = _album;
    if (album == null) return;
    final picked = await showStudioTrackIdsPickerDialog(
      context,
      allTracks: _libraryTracks.map(_withOverrides).toList(),
      currentIds: List<String>.from(album.trackAssetPaths),
    );
    if (picked == null || !mounted) return;
    await _saveAlbum(album.copyWith(trackAssetPaths: picked));
  }

  Future<void> _uploadNewTrack() async {
    final album = _album;
    if (album == null) return;
    final id = await widget.onCreateNewStudioTrackReturnId();
    if (id == null || !mounted) return;
    final nextPaths = [...album.trackAssetPaths];
    if (!nextPaths.contains(id)) nextPaths.add(id);
    await _saveAlbum(album.copyWith(trackAssetPaths: nextPaths));
  }

  Future<void> _removeTrackFromAlbum(Track track) async {
    final album = _album;
    if (album == null) return;
    final next = album.trackAssetPaths.where((p) => p != track.assetPath).toList();
    await _saveAlbum(album.copyWith(trackAssetPaths: next));
  }

  Future<void> _editAlbumInfo() async {
    final album = _album;
    if (album == null) return;
    final result = await widget.showAlbumEditDialog(album);
    if (result == null || !mounted) return;
    await widget.onStudioDataChanged();
    await _load();
  }

  Future<void> _editTrack(Track track) async {
    final result = await widget.showEditTrackDialog(track);
    if (result == null || !mounted) return;
    await widget.studioRepository.saveTrackMetadataOverride(result.assetPath, result.metadata);
    await widget.onStudioDataChanged();
    await _load();
  }

  Future<void> _deleteAlbum() async {
    final album = _album;
    if (album == null) return;
    await widget.onDeleteAlbum(album);
    if (!mounted) return;
    await widget.onStudioDataChanged();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Widget _albumCover(AppColorPalette palette, Album album) {
    final ph = Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: palette.primaryDark.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
      ),
      child: Icon(Icons.album_rounded, color: palette.textMuted, size: 56),
    );
    if (album.coverPath != null && album.coverPath!.isNotEmpty) {
      if (album.coverPath!.startsWith('assets/')) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
          child: Image.asset(
            album.coverPath!,
            width: 120,
            height: 120,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => ph,
          ),
        );
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        child: studioCoverImageFromFile(album.coverPath!, 120, ph),
      );
    }
    return ph;
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    final top = MediaQuery.paddingOf(context).top;

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
          title: Text(
            _album?.title ?? context.t('studio.title'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: palette.textPrimary,
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: palette.textPrimary),
          actions: [
            if (_album != null)
              IconButton(
                icon: const Icon(Icons.edit_rounded),
                tooltip: context.t('studio.albumInfo'),
                onPressed: _editAlbumInfo,
              ),
            if (_album != null)
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'delete') await _deleteAlbum();
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      context.t('studio.delete'),
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
          ],
        ),
        body: _loading
            ? Center(child: CircularProgressIndicator(color: palette.accent))
            : _album == null
                ? Center(
                    child: Text(
                      context.t('studio.albumNotFound'),
                      style: TextStyle(color: palette.textSecondary),
                    ),
                  )
                : Padding(
                    padding: EdgeInsets.fromLTRB(20, 8 + top, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(palette, _album!),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed: _addFromLibrary,
                              icon: const Icon(Icons.library_music_rounded, size: 20),
                              label: Text(context.t('studio.addTracksFromLibrary')),
                              style: FilledButton.styleFrom(backgroundColor: palette.accent),
                            ),
                            OutlinedButton.icon(
                              onPressed: _uploadNewTrack,
                              icon: const Icon(Icons.upload_file_rounded, size: 20),
                              label: Text(context.t('studio.uploadNewTrack')),
                              style: OutlinedButton.styleFrom(foregroundColor: palette.accent),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: Builder(
                            builder: (context) {
                              final tracks = _albumTracksOrdered();
                              if (tracks.isEmpty) {
                                return Center(
                                  child: Text(
                                    context.t('studio.noTracksForAlbum'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: palette.textSecondary),
                                  ),
                                );
                              }
                              return ListView.separated(
                                itemCount: tracks.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 8),
                                itemBuilder: (context, i) {
                                  final t = tracks[i];
                                  return _AlbumTrackRow(
                                    track: t,
                                    palette: palette,
                                    audioPlayerService: widget.audioPlayerService,
                                    albumQueue: tracks,
                                    onRemoveFromAlbum: () => _removeTrackFromAlbum(t),
                                    onEdit: () => _editTrack(t),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildHeader(AppColorPalette palette, Album album) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _albumCover(palette, album),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                album.title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: palette.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                album.artist ?? '—',
                style: TextStyle(fontSize: 14, color: palette.textSecondary),
              ),
              const SizedBox(height: 8),
              Text(
                '${album.trackAssetPaths.length} ${_trackWord(album.trackAssetPaths.length)}',
                style: TextStyle(fontSize: 13, color: palette.textMuted),
              ),
              if (album.genres.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: album.genres
                      .map(
                        (g) => Chip(
                          label: Text(
                            studioGenreChipLabel(context, g),
                            style: TextStyle(fontSize: 10, color: palette.textSecondary),
                          ),
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _trackWord(int n) {
    final en = Localizations.localeOf(context).languageCode == 'en';
    if (en) return n == 1 ? 'track' : 'tracks';
    if (n % 10 == 1 && n % 100 != 11) return 'трек';
    if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) return 'трека';
    return 'треков';
  }
}

class _AlbumTrackRow extends StatelessWidget {
  const _AlbumTrackRow({
    required this.track,
    required this.palette,
    required this.audioPlayerService,
    required this.albumQueue,
    required this.onRemoveFromAlbum,
    required this.onEdit,
  });

  final Track track;
  final AppColorPalette palette;
  final AudioPlayerService audioPlayerService;
  final List<Track> albumQueue;
  final Future<void> Function() onRemoveFromAlbum;
  final Future<void> Function() onEdit;

  @override
  Widget build(BuildContext context) {
    final coverSource = track.coverBytes ?? track.coverFallbackPath;
    final placeholder = Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: palette.primaryDark.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
      ),
      child: Icon(Icons.music_note_rounded, color: palette.textMuted),
    );
    final cover = buildTrackCover(
      coverSource: coverSource,
      width: 48,
      height: 48,
      borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
      placeholder: placeholder,
    );
    final radius = BorderRadius.circular(AppConstants.radiusLarge);
    return Material(
      color: palette.cardBackground.withValues(alpha: 0.9),
      borderRadius: radius,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        leading: cover,
        title: Text(
          track.title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: palette.textPrimary,
            fontSize: 14,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: track.artistDisplay.isEmpty
            ? null
            : Text(
                track.artistDisplay,
                style: TextStyle(fontSize: 12, color: palette.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) async {
            if (v == 'edit') await onEdit();
            if (v == 'remove') await onRemoveFromAlbum();
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'edit', child: Text(context.t('studio.edit'))),
            PopupMenuItem(value: 'remove', child: Text(context.t('studio.removeFromAlbum'))),
          ],
        ),
        onTap: () async {
          final service = audioPlayerService;
          final same = service.currentTrack?.assetPath == track.assetPath &&
              service.currentTrack?.audioFilePath == track.audioFilePath;
          if (same) {
            await service.togglePlayPause();
            return;
          }
          await service.playTrack(track, queue: albumQueue);
          if (!context.mounted) return;
          PlayerDockHost.expand();
        },
      ),
    );
  }
}
