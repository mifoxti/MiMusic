import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/audio/track.dart';
import '../../core/studio/copy_audio_to_app.dart';
import '../../core/studio/copy_cover_to_app.dart';
import '../../core/constants/app_constants.dart';
import '../../core/studio/album.dart';
import '../../core/studio/local_studio_repository.dart';
import '../../core/studio/studio_constants.dart';
import '../../core/studio/studio_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/track_cover.dart';
import 'studio_cover_image.dart';

/// Страница «Студия»: создание, редактирование и удаление альбомов и треков.
class StudioPage extends StatefulWidget {
  const StudioPage({
    super.key,
    this.repository,
    this.currentUserNickname,
  });

  final StudioRepository? repository;

  /// Ник текущего пользователя для кнопки «Я автор».
  final String? currentUserNickname;

  @override
  State<StudioPage> createState() => _StudioPageState();
}

class _StudioPageState extends State<StudioPage> {
  late final StudioRepository _repo = widget.repository ?? LocalStudioRepository();

  List<Album> _albums = [];
  List<Track> _tracks = [];
  List<String> _customPaths = [];
  Map<String, TrackMetadataOverride> _overrides = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final albums = await _repo.getAlbums();
    final overrides = await _repo.getTrackMetadataOverrides();
    final customPaths = await _repo.getCustomTrackPaths();
    final customTracks = <Track>[];
    for (final id in customPaths) {
      final o = overrides[id];
      final artistStr = (o != null && o.displayArtist.isNotEmpty) ? o.displayArtist : o?.artist;
      customTracks.add(Track(
        assetPath: id,
        title: o?.title ?? 'Без названия',
        artist: artistStr,
        coverAssetPath: o?.coverPath,
        audioFilePath: o?.audioFilePath,
      ));
    }
    if (mounted) {
      setState(() {
        _albums = albums;
        _overrides = overrides;
        _customPaths = customPaths;
        _tracks = customTracks;
        _loading = false;
      });
    }
  }

  Track _trackWithOverrides(Track t) {
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

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Студия'),
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: palette.textPrimary,
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(),
            color: palette.textPrimary,
          ),
          bottom: TabBar(
            labelColor: palette.accent,
            unselectedLabelColor: palette.textMuted,
            indicatorColor: palette.accent,
            tabs: const [
              Tab(text: 'Альбомы'),
              Tab(text: 'Треки'),
            ],
          ),
        ),
        body: _loading
            ? Center(child: CircularProgressIndicator(color: palette.accent))
            : TabBarView(
                children: [
                  _AlbumsTab(
                    palette: palette,
                    albums: _albums,
                    allTracks: _tracks,
                    onRefresh: _load,
                    onAddAlbum: _addAlbum,
                    onEditAlbum: _editAlbum,
                    onDeleteAlbum: _deleteAlbum,
                    repo: _repo,
                  ),
                  _TracksTab(
                    palette: palette,
                    tracks: _tracks,
                    overrides: _overrides,
                    customPaths: _customPaths,
                    trackWithOverrides: _trackWithOverrides,
                    onRefresh: _load,
                    onAddTrack: _addTrack,
                    onEditTrack: _editTrack,
                    onDeleteTrack: _deleteTrack,
                    repo: _repo,
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _addAlbum() async {
    final result = await _showAlbumDialog();
    if (result == null || !mounted) return;
    final albums = List<Album>.from(_albums)..add(result);
    await _repo.saveAlbums(albums);
    _load();
  }

  Future<void> _editAlbum(Album album) async {
    final result = await _showAlbumDialog(album: album);
    if (result == null || !mounted) return;
    final albums = _albums.map((a) => a.id == result.id ? result : a).toList();
    await _repo.saveAlbums(albums);
    _load();
  }

  Future<void> _deleteAlbum(Album album) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить альбом?'),
        content: Text('«${album.title}» будет удалён.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final albums = _albums.where((a) => a.id != album.id).toList();
    await _repo.saveAlbums(albums);
    _load();
  }

  Future<Album?> _showAlbumDialog({Album? album}) async {
    final albumId = album?.id ?? 'album_${DateTime.now().millisecondsSinceEpoch}';
    var title = album?.title ?? '';
    var artist = album?.artist ?? '';
    var coverPath = album?.coverPath ?? '';
    var trackIds = List<String>.from(album?.trackAssetPaths ?? []);
    var genres = List<String>.from(album?.genres ?? []);

    return showDialog<Album>(
      context: context,
      builder: (ctx) {
        final dialogPalette = AppPaletteExtension.of(ctx).palette;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(album == null ? 'Новый альбом' : 'Редактировать альбом'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      decoration: const InputDecoration(labelText: 'Название'),
                      controller: TextEditingController(text: title)..selection = TextSelection.collapsed(offset: title.length),
                      onChanged: (v) => title = v,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(labelText: 'Исполнитель'),
                      controller: TextEditingController(text: artist)..selection = TextSelection.collapsed(offset: artist.length),
                      onChanged: (v) => artist = v,
                    ),
                    const SizedBox(height: 12),
                    Text('Обложка', style: TextStyle(fontSize: 12, color: dialogPalette.textSecondary)),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _coverPreview(dialogPalette, coverPath, 72),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextButton.icon(
                            onPressed: () async {
                              final result = await FilePicker.platform.pickFiles(type: FileType.image);
                              if (result == null || result.files.isEmpty || result.files.single.path == null) return;
                              final copied = await copyPickedCoverToApp(result.files.single.path!, albumId);
                              if (copied != null && ctx.mounted) setDialogState(() => coverPath = copied);
                            },
                            icon: const Icon(Icons.image_rounded, size: 20),
                            label: Text(coverPath.isEmpty ? 'Выбрать файл' : 'Заменить'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('Жанры', style: TextStyle(fontSize: 12, color: dialogPalette.textSecondary)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ...studioGenreOptions.map((g) {
                          final selected = genres.contains(g);
                          return FilterChip(
                            label: Text(g),
                            selected: selected,
                            onSelected: (v) => setDialogState(() {
                              if (v) {
                                genres.add(g);
                              } else {
                                genres.remove(g);
                              }
                            }),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Треки в альбоме', style: TextStyle(fontSize: 14, color: dialogPalette.textSecondary)),
                        TextButton.icon(
                          onPressed: _tracks.isEmpty ? null : () async {
                            final picked = await _showTrackPicker(ctx, _tracks, trackIds);
                            if (picked != null) setDialogState(() => trackIds = picked);
                          },
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Добавить'),
                        ),
                      ],
                    ),
                    ...trackIds.map((id) {
                      Track? t;
                      for (final x in _tracks) {
                        if (x.assetPath == id) { t = x; break; }
                      }
                      return ListTile(
                        title: Text(t?.title ?? id, style: const TextStyle(fontSize: 13)),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle_outline, size: 20),
                          onPressed: () => setDialogState(() => trackIds = trackIds.where((p) => p != id).toList()),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, Album(
                    id: albumId,
                    title: title.isEmpty ? 'Без названия' : title,
                    artist: artist.isEmpty ? null : artist,
                    coverPath: coverPath.isEmpty ? null : coverPath,
                    trackAssetPaths: trackIds,
                    genres: genres,
                  )),
                  child: const Text('Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _coverPreview(AppColorPalette palette, String path, double size) {
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: palette.primaryDark.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
      ),
      child: Icon(Icons.image_rounded, color: palette.textMuted, size: size * 0.5),
    );
    final brokenPlaceholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: palette.primaryDark.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
      ),
      child: Icon(Icons.broken_image_rounded, color: palette.textMuted),
    );
    if (path.isEmpty) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
      child: SizedBox(
        width: size,
        height: size,
        child: path.startsWith('assets/')
            ? Image.asset(path, fit: BoxFit.cover, errorBuilder: (_, e, st) => brokenPlaceholder)
            : studioCoverImageFromFile(path, size, brokenPlaceholder),
      ),
    );
  }

  Future<List<String>?> _showTrackPicker(BuildContext context, List<Track> allTracks, List<String> currentIds) async {
    return showDialog<List<String>>(
      context: context,
      builder: (ctx) {
        var selected = List<String>.from(currentIds);
        return StatefulBuilder(
          builder: (context, setPickerState) => AlertDialog(
            title: const Text('Добавить треки'),
            content: SizedBox(
              width: double.maxFinite,
              child: allTracks.isEmpty
                  ? const Text('Нет треков. Сначала добавьте треки во вкладке «Треки».')
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: allTracks.length,
                      itemBuilder: (context, i) {
                        final track = allTracks[i];
                        final added = selected.contains(track.assetPath);
                        return CheckboxListTile(
                          title: Text(track.title, style: const TextStyle(fontSize: 13)),
                          subtitle: track.artist != null ? Text(track.artist!, style: const TextStyle(fontSize: 12)) : null,
                          value: added,
                          onChanged: (v) {
                            if (v == true) {
                              selected.add(track.assetPath);
                            } else {
                              selected.remove(track.assetPath);
                            }
                            setPickerState(() {});
                          },
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
              FilledButton(onPressed: () => Navigator.pop(ctx, selected), child: const Text('Готово')),
            ],
          ),
        );
      },
    );
  }

  Future<void> _addTrack() async {
    final result = await _showTrackDialog();
    if (result == null || !mounted) return;
    final customPaths = List<String>.from(_customPaths);
    if (!customPaths.contains(result.assetPath)) customPaths.add(result.assetPath);
    await _repo.saveCustomTrackPaths(customPaths);
    await _repo.saveTrackMetadataOverride(result.assetPath, result.override);
    _load();
  }

  Future<void> _editTrack(Track track) async {
    final result = await _showTrackDialog(track: track);
    if (result == null || !mounted) return;
    await _repo.saveTrackMetadataOverride(result.assetPath, result.override);
    _load();
  }

  Future<void> _deleteTrack(Track track) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить трек?'),
        content: Text('«${track.title}» будет удалён из библиотеки.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Удалить', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final customPaths = _customPaths.where((p) => p != track.assetPath).toList();
    await _repo.saveCustomTrackPaths(customPaths);
    await _repo.saveTrackMetadataOverride(track.assetPath, null);
    final albums = _albums.map((a) => a.copyWith(
      trackAssetPaths: a.trackAssetPaths.where((p) => p != track.assetPath).toList(),
    )).toList();
    await _repo.saveAlbums(albums);
    _load();
  }

  Future<({String assetPath, TrackMetadataOverride override})?> _showTrackDialog({Track? track}) async {
    final id = track?.assetPath ?? 'custom_${DateTime.now().millisecondsSinceEpoch}';
    var title = track?.title ?? '';
    var artist = track != null ? (_overrides[track.assetPath]?.artist ?? '') : '';
    var coverPath = track != null ? (_overrides[track.assetPath]?.coverPath ?? '') : '';
    var audioFilePath = track != null ? (_overrides[track.assetPath]?.audioFilePath ?? '') : '';
    var genres = List<String>.from(track != null ? (_overrides[track.assetPath]?.genres ?? []) : []);
    var coAuthors = List<String>.from(track != null ? (_overrides[track.assetPath]?.coAuthors ?? []) : []);
    final nickname = widget.currentUserNickname ?? '';
    var authorIsMe = nickname.isNotEmpty && artist == nickname;
    final newCoAuthorController = TextEditingController();

    try {
      return await showDialog<({String assetPath, TrackMetadataOverride override})>(
        context: context,
        builder: (ctx) {
          final dialogPalette = AppPaletteExtension.of(ctx).palette;
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: Text(track == null ? 'Новый трек' : 'Редактировать трек'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      decoration: const InputDecoration(labelText: 'Название'),
                      controller: TextEditingController(text: title)..selection = TextSelection.collapsed(offset: title.length),
                      onChanged: (v) => title = v,
                    ),
                    const SizedBox(height: 12),
                    if (nickname.isNotEmpty)
                      CheckboxListTile(
                        value: authorIsMe,
                        onChanged: (v) => setDialogState(() {
                          authorIsMe = v ?? false;
                          artist = authorIsMe ? nickname : artist;
                        }),
                        title: const Text('Я автор'),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                    TextField(
                      decoration: const InputDecoration(labelText: 'Исполнитель'),
                      controller: TextEditingController(text: artist)..selection = TextSelection.collapsed(offset: artist.length),
                      onChanged: (v) => artist = v,
                      readOnly: authorIsMe,
                    ),
                    const SizedBox(height: 8),
                    Text('Соавторы', style: TextStyle(fontSize: 12, color: dialogPalette.textSecondary)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: coAuthors.map((name) => Chip(
                        label: Text(name),
                        onDeleted: () => setDialogState(() => coAuthors.remove(name)),
                        deleteIconColor: dialogPalette.textMuted,
                      )).toList(),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: newCoAuthorController,
                            decoration: const InputDecoration(hintText: 'Имя соавтора', isDense: true),
                            onSubmitted: (value) {
                              final name = value.trim();
                              if (name.isNotEmpty && !coAuthors.contains(name)) {
                                coAuthors.add(name);
                                newCoAuthorController.clear();
                                setDialogState(() {});
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () {
                            final name = newCoAuthorController.text.trim();
                            if (name.isNotEmpty && !coAuthors.contains(name)) {
                              coAuthors.add(name);
                              newCoAuthorController.clear();
                              setDialogState(() {});
                            }
                          },
                          child: const Text('Добавить'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('Аудиофайл', style: TextStyle(fontSize: 12, color: dialogPalette.textSecondary)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            audioFilePath.isEmpty ? 'Не выбран' : audioFilePath.split(RegExp(r'[/\\]')).last,
                            style: TextStyle(fontSize: 13, color: dialogPalette.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            final result = await FilePicker.platform.pickFiles(type: FileType.audio);
                            if (result == null || result.files.isEmpty || result.files.single.path == null) return;
                            final pickedPath = result.files.single.path!;
                            final copied = await copyPickedAudioToApp(pickedPath, id);
                            if (copied != null && ctx.mounted) setDialogState(() => audioFilePath = copied);
                          },
                          icon: const Icon(Icons.upload_file_rounded, size: 20),
                          label: const Text('Выбрать файл'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Обложка', style: TextStyle(fontSize: 12, color: dialogPalette.textSecondary)),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _coverPreview(dialogPalette, coverPath, 64),
                        const SizedBox(width: 12),
                        TextButton.icon(
                          onPressed: () async {
                            final result = await FilePicker.platform.pickFiles(type: FileType.image);
                            if (result == null || result.files.isEmpty || result.files.single.path == null) return;
                            final copied = await copyPickedCoverToApp(result.files.single.path!, id);
                            if (copied != null && ctx.mounted) setDialogState(() => coverPath = copied);
                          },
                          icon: const Icon(Icons.image_rounded, size: 20),
                          label: Text(coverPath.isEmpty ? 'Выбрать файл' : 'Заменить'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Жанры', style: TextStyle(fontSize: 12, color: dialogPalette.textSecondary)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: studioGenreOptions.map((g) {
                        final selected = genres.contains(g);
                        return FilterChip(
                          label: Text(g),
                          selected: selected,
                          onSelected: (v) => setDialogState(() {
                            if (v) {
                              genres.add(g);
                            } else {
                              genres.remove(g);
                            }
                          }),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, (
                    assetPath: id,
                    override: TrackMetadataOverride(
                      title: title.isEmpty ? null : title,
                      artist: artist.isEmpty ? null : artist,
                      coverPath: coverPath.isEmpty ? null : coverPath,
                      genres: genres,
                      audioFilePath: audioFilePath.isEmpty ? null : audioFilePath,
                      coAuthors: coAuthors,
                    ),
                  )),
                  child: const Text('Сохранить'),
                ),
              ],
              );
            },
          );
        },
      );
    } finally {
      newCoAuthorController.dispose();
    }
  }
}

class _AlbumsTab extends StatelessWidget {
  const _AlbumsTab({
    required this.palette,
    required this.albums,
    required this.allTracks,
    required this.onRefresh,
    required this.onAddAlbum,
    required this.onEditAlbum,
    required this.onDeleteAlbum,
    required this.repo,
  });

  final AppColorPalette palette;
  final List<Album> albums;
  final List<Track> allTracks;
  final VoidCallback onRefresh;
  final Future<void> Function() onAddAlbum;
  final Future<void> Function(Album) onEditAlbum;
  final Future<void> Function(Album) onDeleteAlbum;
  final StudioRepository repo;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text('Альбомы (${albums.length})', style: TextStyle(fontSize: 14, color: palette.textSecondary)),
              const Spacer(),
              FilledButton.icon(
                onPressed: onAddAlbum,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('Добавить альбом'),
                style: FilledButton.styleFrom(backgroundColor: palette.accent),
              ),
            ],
          ),
        ),
        Expanded(
          child: albums.isEmpty
              ? Center(child: Text('Нет альбомов. Нажмите «Добавить альбом».', style: TextStyle(color: palette.textMuted)))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  itemCount: albums.length,
                  itemBuilder: (context, i) {
                    final album = albums[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: palette.cardBackground.withValues(alpha: 0.9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusLarge)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: album.coverPath != null && album.coverPath!.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                                child: SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: album.coverPath!.startsWith('assets/')
                                      ? Image.asset(album.coverPath!, width: 48, height: 48, fit: BoxFit.cover, errorBuilder: (_, e, st) => _albumPlaceholder(palette))
                                      : studioCoverImageFromFile(album.coverPath!, 48, _albumPlaceholder(palette)),
                                ),
                              )
                            : _albumPlaceholder(palette),
                        title: Text(album.title, style: TextStyle(fontWeight: FontWeight.w600, color: palette.textPrimary)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${album.artist ?? "—"} · ${album.trackAssetPaths.length} треков', style: TextStyle(fontSize: 12, color: palette.textSecondary)),
                            if (album.genres.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 4,
                                runSpacing: 2,
                                children: album.genres.map((g) => Chip(
                                  label: Text(g, style: TextStyle(fontSize: 10, color: palette.textSecondary)),
                                  padding: EdgeInsets.zero,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                )).toList(),
                              ),
                            ],
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'edit') {
                              onEditAlbum(album);
                            }
                            if (v == 'delete') {
                              onDeleteAlbum(album);
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(value: 'edit', child: Text('Редактировать')),
                            const PopupMenuItem(value: 'delete', child: Text('Удалить')),
                          ],
                        ),
                        onTap: () => onEditAlbum(album),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _albumPlaceholder(AppColorPalette palette) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: palette.primaryDark.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
      ),
      child: Icon(Icons.album_rounded, color: palette.textMuted, size: 28),
    );
  }
}

class _TracksTab extends StatelessWidget {
  const _TracksTab({
    required this.palette,
    required this.tracks,
    required this.overrides,
    required this.customPaths,
    required this.trackWithOverrides,
    required this.onRefresh,
    required this.onAddTrack,
    required this.onEditTrack,
    required this.onDeleteTrack,
    required this.repo,
  });

  final AppColorPalette palette;
  final List<Track> tracks;
  final Map<String, TrackMetadataOverride> overrides;
  final List<String> customPaths;
  final Track Function(Track) trackWithOverrides;
  final VoidCallback onRefresh;
  final Future<void> Function() onAddTrack;
  final Future<void> Function(Track) onEditTrack;
  final Future<void> Function(Track) onDeleteTrack;
  final StudioRepository repo;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text('Треки (${tracks.length})', style: TextStyle(fontSize: 14, color: palette.textSecondary)),
              const Spacer(),
              FilledButton.icon(
                onPressed: onAddTrack,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('Добавить трек'),
                style: FilledButton.styleFrom(backgroundColor: palette.accent),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            itemCount: tracks.length,
            itemBuilder: (context, i) {
              final track = trackWithOverrides(tracks[i]);
              final coverSource = track.coverBytes ?? track.coverFallbackPath;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: palette.cardBackground.withValues(alpha: 0.9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusLarge)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: buildTrackCover(
                        coverSource: coverSource,
                        width: 48,
                        height: 48,
                        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                        placeholder: Container(color: palette.primaryDark.withValues(alpha: 0.5), child: Icon(Icons.music_note_rounded, color: palette.textMuted, size: 24)),
                      ),
                    ),
                  ),
                  title: Text(track.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: palette.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(track.artistDisplay.isEmpty ? '—' : track.artistDisplay, style: TextStyle(fontSize: 12, color: palette.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (overrides[track.assetPath]?.genres.isNotEmpty ?? false) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 4,
                          runSpacing: 2,
                          children: (overrides[track.assetPath]!.genres).map((g) => Chip(
                            label: Text(g, style: TextStyle(fontSize: 10, color: palette.textSecondary)),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          )).toList(),
                        ),
                      ],
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'edit') {
                        onEditTrack(track);
                      }
                      if (v == 'delete') {
                        onDeleteTrack(track);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('Редактировать')),
                      const PopupMenuItem(value: 'delete', child: Text('Удалить')),
                    ],
                  ),
                  onTap: () => onEditTrack(track),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
