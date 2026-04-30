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
import 'playlist_detail_page.dart';

/// Страница «Плейлисты»: список плейлистов и кнопка «Создать плейлист».
class PlaylistsPage extends StatefulWidget {
  const PlaylistsPage({
    super.key,
    PlaylistsRepository? repository,
  }) : _repository = repository;

  final PlaylistsRepository? _repository;

  @override
  State<PlaylistsPage> createState() => _PlaylistsPageState();
}

class _PlaylistsPageState extends State<PlaylistsPage> {
  late final PlaylistsRepository _repo =
      widget._repository ?? LocalPlaylistsRepository();

  List<Playlist> _playlists = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await _repo.getPlaylists();
    if (mounted) {
      setState(() {
        _playlists = items;
        _loading = false;
      });
    }
  }

  Future<void> _createPlaylist() async {
    final created = await _showEditDialog(context);
    if (created == null) return;
    await _repo.savePlaylist(created);
    if (mounted) await _load();
  }

  Future<void> _openPlaylist(Playlist playlist) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PlaylistDetailPage(
          playlistId: playlist.id,
          repository: _repo,
        ),
      ),
    );
    if (mounted) await _load();
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
        ),
        body: Padding(
          padding: EdgeInsets.fromLTRB(20, 8 + topPadding, 20, 20),
          child: _loading
              ? Center(
                  child: CircularProgressIndicator(color: palette.accent),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          context.t('playlists.yours'),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: palette.textPrimary,
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: _createPlaylist,
                          style: FilledButton.styleFrom(
                            backgroundColor: palette.accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                          icon: const Icon(Icons.add_rounded, size: 20),
                          label: Text(context.t('playlists.create')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_playlists.isEmpty)
                      Expanded(
                        child: Center(
                          child: Text(
                            context.t('playlists.empty'),
                            style: TextStyle(
                              fontSize: 15,
                              color: palette.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.separated(
                          itemCount: _playlists.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final p = _playlists[index];
                            return _PlaylistTile(
                              playlist: p,
                              onTap: () => _openPlaylist(p),
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

  Future<Playlist?> _showEditDialog(BuildContext context,
      {Playlist? existing}) async {
    final palette = AppPaletteExtension.of(context).palette;
    final id = existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
    var title = existing?.title ?? '';
    var isPrivate = existing?.isPrivate ?? false;
    var coverPath = existing?.coverPath ?? '';

    return showDialog<Playlist>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(existing == null ? context.t('playlists.new') : context.t('playlists.edit')),
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
                                id,
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
                    final playlist = Playlist(
                      id: id,
                      title: title.isEmpty ? context.t('playlists.untitled') : title,
                      isPrivate: isPrivate,
                      coverPath: coverPath.isEmpty ? null : coverPath,
                      trackAssetPaths: existing?.trackAssetPaths ?? const [],
                    );
                    Navigator.pop(ctx, playlist);
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

class _PlaylistTile extends StatelessWidget {
  const _PlaylistTile({
    required this.playlist,
    required this.onTap,
  });

  final Playlist playlist;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    final placeholder = Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: palette.primaryDark.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
      ),
      child: Icon(
        Icons.queue_music_rounded,
        color: palette.textMuted,
      ),
    );

    Widget cover;
    if (playlist.coverPath != null && playlist.coverPath!.isNotEmpty) {
      cover = buildTrackCover(
        coverSource: playlist.coverPath!,
        width: 56,
        height: 56,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        placeholder: placeholder,
      );
    } else {
      cover = placeholder;
    }

    final trackCount = playlist.trackAssetPaths.length;
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final subtitle = trackCount == 0
        ? context.t('playlists.emptyPlaylist')
        : isEn
            ? '$trackCount tracks'
            : '$trackCount трек${trackCount == 1 ? '' : trackCount >= 2 && trackCount <= 4 ? 'а' : 'ов'}';

    return Material(
      color: palette.cardBackground.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              cover,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: palette.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (playlist.isPrivate)
                Icon(
                  Icons.lock_rounded,
                  size: 18,
                  color: palette.textMuted,
                ),
            ],
          ),
        ),
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

