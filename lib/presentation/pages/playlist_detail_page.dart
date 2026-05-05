import 'package:flutter/material.dart';

import '../../core/audio/audio_player_service.dart';
import '../../core/audio/local_tracks.dart';
import '../../core/audio/track.dart';
import '../../core/auth/auth_session_store.dart';
import '../../core/network/api_config.dart';
import '../../core/network/playlists_api.dart';
import '../../core/network/tracks_api.dart';
import '../../core/constants/app_constants.dart';
import '../../core/l10n/app_localization.dart';
import '../../core/platform/cover_pick_save.dart';
import '../../core/platform/platform.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/track_cover.dart';
import '../../features/playlists/domain/entities/playlist.dart';
import '../../features/playlists/data/repositories/local_playlists_repository.dart';
import '../../features/playlists/domain/repositories/playlists_repository.dart';
import '../../features/player/presentation/widgets/full_player_track_menu.dart';
import '../../core/player/shell_route_back_guard.dart';
import 'artist_page.dart';

/// Детальная страница плейлиста: обложка, название, список треков и меню «три точки».
class PlaylistDetailPage extends StatefulWidget {
  const PlaylistDetailPage({
    super.key,
    required this.playlistId,
    required this.audioPlayerService,
    PlaylistsRepository? repository,
  }) : _repository = repository;

  final String playlistId;
  final AudioPlayerService audioPlayerService;
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
  int? _ownerUserId;
  String? _ownerNickname;
  bool _detailIsPublic = false;
  bool _isPlaylistOwner = true;
  bool _sessionLoggedIn = false;
  int _playlistLikesCount = 0;
  bool _playlistLiked = false;
  bool _likeBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _ownerUserId = null;
      _ownerNickname = null;
      _detailIsPublic = false;
      _isPlaylistOwner = true;
      _playlistLikesCount = 0;
      _playlistLiked = false;
    });
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
    final sid = parseServerPlaylistId(widget.playlistId);
    if (sid != null) {
      try {
        final d = await PlaylistsApi().fetchPlaylistDetail(sid);
        final base = ApiConfig.baseUrl.replaceAll(RegExp(r'/+$'), '');
        final serverTracks = d.tracks.map((t) {
          final id = t.trackId;
          return Track(
            assetPath: 'server_track_$id',
            title: (t.title ?? '').trim().isEmpty ? '—' : t.title!.trim(),
            artist: t.artist,
            audioFilePath: '$base/tracks/$id/stream',
            coverAssetPath: '$base/tracks/$id/cover',
          );
        }).toList();
        final acc = await AuthSessionStore.readAccount();
        final uid = acc?.userId;
        final loggedIn = acc != null && acc.sessionToken.trim().isNotEmpty;
        var liked = false;
        var likesCount = d.likesCount;
        if (d.isPublic && loggedIn) {
          try {
            final st = await PlaylistsApi().getPlaylistLike(sid);
            liked = st.liked;
            likesCount = st.likesCount;
          } catch (_) {}
        }
        if (mounted) {
          setState(() {
            _playlist = playlist;
            _tracks = serverTracks;
            _loading = false;
            _ownerUserId = d.ownerUserId;
            _ownerNickname = d.ownerNickname;
            _detailIsPublic = d.isPublic;
            _sessionLoggedIn = loggedIn;
            _isPlaylistOwner = uid != null && uid == d.ownerUserId;
            _playlistLiked = liked;
            _playlistLikesCount = likesCount;
          });
        }
        return;
      } catch (_) {
        /* fallback local */
      }
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
    if (!_isPlaylistOwner) return;
    final current = _playlist;
    if (current == null) return;
    final updated = await _showEditDialog(context, existing: current);
    if (updated == null) return;
    await _repo.savePlaylist(updated);
    if (mounted) await _load();
  }

  Future<void> _addTracks() async {
    if (!_isPlaylistOwner) return;
    final current = _playlist;
    if (current == null) return;
    final acc = await AuthSessionStore.readAccount();
    final useServer = acc != null &&
        acc.sessionToken.trim().isNotEmpty &&
        acc.userId != null &&
        _repo is! LocalPlaylistsRepository;
    if (useServer) {
      List<ServerTrackListItem> catalog;
      try {
        catalog = await TracksApi().fetchTracks(limit: 200);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(Localizations.localeOf(context).languageCode == 'en' ? 'Could not load tracks' : 'Не удалось загрузить треки')),
          );
        }
        return;
      }
      if (!mounted) return;
      final currentIds = current.trackAssetPaths.toSet();
      var selected = <String>{...currentIds};
      final picked = await showDialog<List<String>>(
        context: context,
        useRootNavigator: true,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setSt) {
              return AlertDialog(
                title: Text(context.t('playlists.addTracksDialog')),
                content: SizedBox(
                  width: double.maxFinite,
                  child: catalog.isEmpty
                      ? Text(context.t('playlists.noLocalTracks'))
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: catalog.length,
                          itemBuilder: (context, index) {
                            final e = catalog[index];
                            final path = 'server_track_${e.id}';
                            final added = selected.contains(path);
                            return CheckboxListTile(
                              title: Text(e.title, style: const TextStyle(fontSize: 13)),
                              subtitle: (e.artist ?? '').isNotEmpty
                                  ? Text(e.artist!, style: const TextStyle(fontSize: 12))
                                  : null,
                              value: added,
                              onChanged: (v) {
                                setSt(() {
                                  if (v == true) {
                                    selected.add(path);
                                  } else {
                                    selected.remove(path);
                                  }
                                });
                              },
                            );
                          },
                        ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.t('common.cancel'))),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, selected.toList()),
                    child: Text(Localizations.localeOf(context).languageCode == 'en' ? 'Done' : 'Готово'),
                  ),
                ],
              );
            },
          );
        },
      );
      if (picked == null) return;
      final updated = current.copyWith(trackAssetPaths: picked);
      await _repo.savePlaylist(updated);
      if (mounted) await _load();
      return;
    }

    final allTracks = await loadLocalTracks();
    if (!mounted) return;
    final currentIds = Set<String>.from(current.trackAssetPaths);
    final selected = await showDialog<List<String>>(
      context: context,
      useRootNavigator: true,
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
    } else if (value == 'delete') {
      await _deletePlaylist();
    }
  }

  Future<void> _deletePlaylist() async {
    final current = _playlist;
    if (current == null || !_isPlaylistOwner) return;
    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('playlists.deletePlaylist')),
        content: Text(context.t('playlists.deletePlaylistConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.t('common.cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.t('playlists.deletePlaylist')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _repo.deletePlaylist(widget.playlistId);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      final en = Localizations.localeOf(context).languageCode == 'en';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(en ? 'Could not delete playlist' : 'Не удалось удалить плейлист')),
      );
    }
  }

  Future<void> _removeTrackFromPlaylist(Track track) async {
    final current = _playlist;
    if (current == null || !_isPlaylistOwner) return;
    final nextPaths = _tracks
        .where((x) => x.assetPath != track.assetPath)
        .map((x) => x.assetPath)
        .toList();
    await _repo.savePlaylist(current.copyWith(trackAssetPaths: nextPaths));
    if (mounted) await _load();
  }

  Future<void> _togglePlaylistLike() async {
    final id = parseServerPlaylistId(widget.playlistId);
    if (id == null || !_detailIsPublic || !_sessionLoggedIn || _likeBusy) return;
    setState(() => _likeBusy = true);
    try {
      final st = await PlaylistsApi().postPlaylistLike(id);
      if (!mounted) return;
      setState(() {
        _playlistLiked = st.liked;
        _playlistLikesCount = st.likesCount;
      });
    } catch (_) {
      if (!mounted) return;
      final en = Localizations.localeOf(context).languageCode == 'en';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(en ? 'Could not update like' : 'Не удалось обновить лайк')),
      );
    } finally {
      if (mounted) setState(() => _likeBusy = false);
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
            if (_playlist != null && _detailIsPublic && _sessionLoggedIn)
              IconButton(
                tooltip: Localizations.localeOf(context).languageCode == 'en' ? 'Like' : 'Лайк',
                onPressed: _likeBusy ? null : _togglePlaylistLike,
                icon: _likeBusy
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: palette.accent,
                        ),
                      )
                    : Icon(
                        _playlistLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: _playlistLiked ? palette.accent : palette.textPrimary,
                      ),
              ),
            if (_playlist != null && _isPlaylistOwner)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: _onMenuSelected,
                itemBuilder: (context) => [
                  PopupMenuItem<String>(
                    value: 'edit',
                    child: Text(context.t('studio.edit')),
                  ),
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Text(
                      context.t('playlists.deletePlaylist'),
                      style: const TextStyle(color: Colors.redAccent),
                    ),
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
                        if (_tracks.isNotEmpty && _isPlaylistOwner) ...[
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
                                      if (_isPlaylistOwner) ...[
                                        _buildAddTracksButton(palette),
                                        const SizedBox(height: 12),
                                      ],
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
                                    return _PlaylistTrackTile(
                                      track: t,
                                      audioPlayerService: widget.audioPlayerService,
                                      playlistsRepository: _repo,
                                      currentPlaylistId: widget.playlistId,
                                      showRemoveFromPlaylist: _isPlaylistOwner,
                                      onRemoveFromPlaylist: _removeTrackFromPlaylist,
                                      onTap: () {
                                        final queue = List<Track>.from(_tracks);
                                        widget.audioPlayerService.playTrack(
                                          t,
                                          queue: queue,
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

  String _trackCountLine(BuildContext context) {
    if (_tracks.isEmpty) return context.t('playlists.noTracks');
    final en = Localizations.localeOf(context).languageCode == 'en';
    final base = en
        ? '${_tracks.length} tracks'
        : '${_tracks.length} трек${_tracks.length == 1 ? '' : _tracks.length >= 2 && _tracks.length <= 4 ? 'а' : 'ов'}';
    if (_detailIsPublic) return '$base · ♥ $_playlistLikesCount';
    return base;
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
              if (_ownerUserId != null) ...[
                const SizedBox(height: 8),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      final uid = _ownerUserId!;
                      final nick = (_ownerNickname ?? '').trim();
                      final enUi = Localizations.localeOf(context).languageCode == 'en';
                      final label = nick.isNotEmpty ? '@$nick' : (enUi ? 'Author' : 'Автор');
                      Navigator.of(context).push(
                        ShellMaterialPageRoute<void>(
                          builder: (_) => ArtistPage(
                            artistName: nick.isNotEmpty ? nick : label,
                            coverImageUrl: userAvatarUrl(uid),
                            audioPlayerService: widget.audioPlayerService,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          ClipOval(
                            child: Image.network(
                              userAvatarUrl(_ownerUserId!),
                              width: 26,
                              height: 26,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                width: 26,
                                height: 26,
                                color: palette.primaryDark.withValues(alpha: 0.5),
                                alignment: Alignment.center,
                                child: Icon(Icons.person_rounded, size: 16, color: palette.textMuted),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              () {
                                final nick = (_ownerNickname ?? '').trim();
                                if (nick.isNotEmpty) return '@$nick';
                                return Localizations.localeOf(context).languageCode == 'en'
                                    ? 'Author'
                                    : 'Автор';
                              }(),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: palette.accent,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
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
                _trackCountLine(context),
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
      useRootNavigator: true,
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
                              final copied =
                                  await pickAndSaveCoverImage(existing.id);
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
    required this.onTap,
    required this.audioPlayerService,
    required this.playlistsRepository,
    required this.currentPlaylistId,
    this.showRemoveFromPlaylist = false,
    this.onRemoveFromPlaylist,
  });

  final Track track;
  final VoidCallback onTap;
  final AudioPlayerService audioPlayerService;
  final PlaylistsRepository playlistsRepository;
  final String currentPlaylistId;
  final bool showRemoveFromPlaylist;
  final Future<void> Function(Track track)? onRemoveFromPlaylist;

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

    final radius = BorderRadius.circular(AppConstants.radiusLarge);
    return ListenableBuilder(
      listenable: audioPlayerService,
      builder: (context, _) {
        final path = AudioPlayerService.playablePath(track);
        final liked = audioPlayerService.isPathLiked(path);
        final downloading = audioPlayerService.isTrackDownloading(path);
        final downloaded = audioPlayerService.isTrackDownloaded(path);

        return Material(
          color: palette.cardBackground.withValues(alpha: 0.9),
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 2, 4),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: radius,
                    onTap: onTap,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(6, 4, 8, 4),
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
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: palette.textSecondary,
                  ),
                  onSelected: (value) async {
                    if (value == 'fav') {
                      if (path.isEmpty) return;
                      await audioPlayerService.toggleLikePath(path);
                      return;
                    }
                    if (value == 'dl') {
                      if (path.isEmpty || downloading || downloaded) return;
                      await audioPlayerService.cacheTrackMock(track);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          behavior: SnackBarBehavior.floating,
                          content: Text(context.t('playlists.track.cachedMock')),
                        ),
                      );
                      return;
                    }
                    if (value == 'pl') {
                      await showTrackPlaylistPicker(
                        context,
                        track: track,
                        repository: playlistsRepository,
                        omitPlaylistId: currentPlaylistId,
                      );
                    }
                    if (value == 'removePl') {
                      await onRemoveFromPlaylist?.call(track);
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem<String>(
                      value: 'fav',
                      enabled: path.isNotEmpty,
                      child: Text(
                        liked
                            ? context.t('playlists.track.removeFromFavorites')
                            : context.t('playlists.track.addToFavorites'),
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'dl',
                      enabled:
                          path.isNotEmpty && !downloading && !downloaded,
                      child: Text(context.t('playlists.track.download')),
                    ),
                    PopupMenuItem<String>(
                      value: 'pl',
                      child: Text(context.t('player.menu.addToPlaylist')),
                    ),
                    if (showRemoveFromPlaylist && onRemoveFromPlaylist != null)
                      PopupMenuItem<String>(
                        value: 'removePl',
                        child: Text(context.t('playlists.track.removeFromPlaylist')),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
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

