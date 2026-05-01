import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/audio/local_tracks.dart';
import '../../core/audio/track.dart';
import '../../core/constants/app_constants.dart';
import '../../core/l10n/app_localization.dart';
import '../../core/platform/platform.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/track_cover.dart';
import '../../features/playlists/domain/entities/playlist.dart';
import '../../features/playlists/domain/repositories/playlists_repository.dart';
import '../../features/playlists/data/repositories/local_playlists_repository.dart';

/// Детальная страница плейлиста: обложка, название, список треков и меню «три точки».
class PlaylistDetailPage extends StatefulWidget {
  const PlaylistDetailPage({
    super.key,
    required this.playlistId,
    PlaylistsRepository? repository,
  }) : _repository = repository;

  final String playlistId;
  final PlaylistsRepository? _repository;

  @override
  State<PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends State<PlaylistDetailPage> {
  late final PlaylistsRepository _repo =
      widget._repository ?? LocalPlaylistsRepository();

  Playlist? _playlist;
  List<Track> _tracks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final playlist = await _repo.getPlaylist(widget.playlistId);
    if (playlist == null) {
      if (mounted) {
        setState(() {
          _playlist = null;
          _tracks = [];
          _loading = false;
        });
      }
      return;
    }
    final allTracks = await loadLocalTracks();
    final ids = playlist.trackAssetPaths.toSet();
    final inPlaylist = allTracks.where((t) => ids.contains(t.assetPath)).toList();
    if (mounted) {
      setState(() {
        _playlist = playlist;
        _tracks = inPlaylist;
        _loading = false;
      });
    }
  }

  Future<void> _edit() async {
    final current = _playlist;
    if (current == null) return;
    final updated = await _showEditDialog(context, existing: current);
    if (updated == null) return;
    await _repo.savePlaylist(updated);
    if (mounted) await _load();
  }

  Future<void> _addTracks() async {
    final current = _playlist;
    if (current == null) return;
    final allTracks = await loadLocalTracks();
    if (!mounted) return;
    final currentIds = Set<String>.from(current.trackAssetPaths);
    final selected = await showDialog<List<String>>(
      context: context,
      builder: (ctx) {
        var localSelected = Set<String>.from(currentIds);
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(context.t('playlists.addTracksDialog')),
              content: SizedBox(
                width: double.maxFinite,
                child: allTracks.isEmpty
                    ? Text(
                        context.t('playlists.noLocalTracks'),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: allTracks.length,
                        itemBuilder: (context, index) {
                          final t = allTracks[index];
                          final added = localSelected.contains(t.assetPath);
                          return CheckboxListTile(
                            title: Text(
                              t.title,
                              style: const TextStyle(fontSize: 13),
                            ),
                            subtitle: t.artistDisplay.isNotEmpty
                                ? Text(
                                    t.artistDisplay,
                                    style: const TextStyle(fontSize: 12),
                                  )
                                : null,
                            value: added,
                            onChanged: (v) {
                              if (v == true) {
                                localSelected.add(t.assetPath);
                              } else {
                                localSelected.remove(t.assetPath);
                              }
                              setState(() {});
                            },
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(context.t('common.cancel')),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(
                    ctx,
                    localSelected.toList(growable: false),
                  ),
                  child: Text(Localizations.localeOf(context).languageCode == 'en' ? 'Done' : 'Готово'),
                ),
              ],
            );
          },
        );
      },
    );
    if (selected == null) return;
    final updated = current.copyWith(trackAssetPaths: selected);
    await _repo.savePlaylist(updated);
    if (mounted) await _load();
  }

  Future<void> _onMenuSelected(String value) async {
    if (value == 'edit') {
      await _edit();
    }
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
          title: Text(context.t('playlists.title')),
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: palette.textPrimary,
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: palette.textPrimary),
          actions: [
            if (_playlist != null)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: _onMenuSelected,
                itemBuilder: (context) => [
                  PopupMenuItem<String>(
                    value: 'edit',
                    child: Text(context.t('studio.edit')),
                  ),
                ],
              ),
          ],
        ),
        body: _loading
            ? Center(
                child: CircularProgressIndicator(color: palette.accent),
              )
            : _playlist == null
                ? Center(
                    child: Text(
                      context.t('playlists.notFound'),
                      style: TextStyle(
                        fontSize: 16,
                        color: palette.textSecondary,
                      ),
                    ),
                  )
                : Padding(
                    padding: EdgeInsets.fromLTRB(20, 8 + topPadding, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(palette),
                        const SizedBox(height: 16),
                        if (_tracks.isNotEmpty) ...[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: _buildAddTracksButton(palette),
                          ),
                          const SizedBox(height: 16),
                        ],
                        Expanded(
                          child: _tracks.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildAddTracksButton(palette),
                                      const SizedBox(height: 12),
                                      Text(
                                        context.t('playlists.emptyInPlaylist'),
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: palette.textSecondary,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: _tracks.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final t = _tracks[index];
                                    return _PlaylistTrackTile(track: t);
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildAddTracksButton(AppColorPalette palette) {
    return OutlinedButton.icon(
      onPressed: _addTracks,
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.accent,
        side: BorderSide(color: palette.accent.withValues(alpha: 0.8)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        ),
      ),
      icon: const Icon(Icons.add_rounded, size: 20),
      label: Text(context.t('playlists.addTracks')),
    );
  }

  Widget _buildHeader(AppColorPalette palette) {
    final p = _playlist!;
    final coverPlaceholder = Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: palette.primaryDark.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
      ),
      child: Icon(
        Icons.queue_music_rounded,
        color: palette.textMuted,
        size: 56,
      ),
    );

    Widget cover;
    if (p.coverPath != null && p.coverPath!.isNotEmpty) {
      cover = buildTrackCover(
        coverSource: p.coverPath!,
        width: 120,
        height: 120,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        placeholder: coverPlaceholder,
      );
    } else {
      cover = coverPlaceholder;
    }

    return Row(
      children: [
        cover,
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p.title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: palette.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (p.isPrivate)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: palette.primaryDark.withValues(alpha: 0.7),
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusSmall),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lock_rounded,
                            size: 14,
                            color: palette.textPrimary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            context.t('playlists.privateBadge'),
                            style: TextStyle(
                              fontSize: 11,
                              color: palette.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _tracks.isEmpty
                    ? context.t('playlists.noTracks')
                    : Localizations.localeOf(context).languageCode == 'en'
                        ? '${_tracks.length} tracks'
                        : '${_tracks.length} трек${_tracks.length == 1 ? '' : _tracks.length >= 2 && _tracks.length <= 4 ? 'а' : 'ов'}',
                style: TextStyle(
                  fontSize: 13,
                  color: palette.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<Playlist?> _showEditDialog(BuildContext context,
      {required Playlist existing}) async {
    final palette = AppPaletteExtension.of(context).palette;
    var title = existing.title;
    var isPrivate = existing.isPrivate;
    var coverPath = existing.coverPath ?? '';

    return showDialog<Playlist>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(context.t('playlists.edit')),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      decoration: InputDecoration(labelText: context.t('playlists.name')),
                      controller: TextEditingController(text: title)
                        ..selection = TextSelection.collapsed(
                          offset: title.length,
                        ),
                      onChanged: (v) => title = v,
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text(context.t('playlists.private')),
                      subtitle: Text(
                        context.t('playlists.privateHint'),
                        style: TextStyle(color: palette.textSecondary, fontSize: 12),
                      ),
                      value: isPrivate,
                      onChanged: (v) => setDialogState(() => isPrivate = v),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.t('playlists.cover'),
                      style: TextStyle(
                        fontSize: 12,
                        color: palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PlaylistCoverPreview(
                          size: 72,
                          coverPath: coverPath,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextButton.icon(
                            onPressed: () async {
                              final result = await FilePicker.platform
                                  .pickFiles(type: FileType.image);
                              if (result == null ||
                                  result.files.isEmpty ||
                                  result.files.single.path == null) {
                                return;
                              }
                              final copied = await copyPickedCoverToApp(
                                result.files.single.path!,
                                existing.id,
                              );
                              if (copied != null && ctx.mounted) {
                                setDialogState(() => coverPath = copied);
                              }
                            },
                            icon:
                                const Icon(Icons.image_rounded, size: 20),
                            label: Text(
                              coverPath.isEmpty
                                  ? context.t('playlists.chooseFile')
                                  : context.t('playlists.replace'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(context.t('common.cancel')),
                ),
                FilledButton(
                  onPressed: () {
                    final updated = existing.copyWith(
                      title: title.isEmpty ? context.t('playlists.untitled') : title,
                      isPrivate: isPrivate,
                      coverPath: coverPath.isEmpty ? null : coverPath,
                    );
                    Navigator.pop(ctx, updated);
                  },
                  child: Text(context.t('common.save')),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _PlaylistTrackTile extends StatelessWidget {
  const _PlaylistTrackTile({
    required this.track,
  });

  final Track track;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    final placeholder = Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: palette.primaryDark.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
      ),
      child: Icon(
        Icons.music_note_rounded,
        color: palette.textMuted,
      ),
    );

    final cover = buildTrackCover(
      coverSource: track.coverBytes ?? track.coverFallbackPath,
      width: 48,
      height: 48,
      borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
      placeholder: placeholder,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: palette.cardBackground.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
      ),
      child: Row(
        children: [
          cover,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: palette.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (track.artistDisplay.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    track.artistDisplay,
                    style: TextStyle(
                      fontSize: 12,
                      color: palette.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaylistCoverPreview extends StatelessWidget {
  const _PlaylistCoverPreview({
    required this.size,
    required this.coverPath,
  });

  final double size;
  final String coverPath;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: palette.primaryDark.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
      ),
      child: Icon(
        Icons.image_rounded,
        color: palette.textMuted,
        size: size * 0.5,
      ),
    );
    if (coverPath.isEmpty) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
      child: SizedBox(
        width: size,
        height: size,
        child: coverPath.startsWith('assets/')
            ? Image.asset(
                coverPath,
                fit: BoxFit.cover,
                errorBuilder: (_, error, stack) => placeholder,
              )
            : studioCoverImageFromFile(
                coverPath,
                size,
                placeholder,
              ),
      ),
    );
  }
}

