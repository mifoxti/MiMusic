import 'dart:async' show unawaited;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/audio/audio_player_service.dart';
import '../../core/audio/track.dart';
import '../../core/auth/auth_session_store.dart';
import '../../core/network/server_connectivity.dart';
import '../../core/network/tracks_api.dart';
import '../../core/player/player_dock_host.dart';
import '../../core/player/shell_route_back_guard.dart';
import '../../core/constants/app_constants.dart';
import '../../core/l10n/app_localization.dart';
import '../../core/platform/platform.dart';
import '../../core/studio/album.dart';
import '../../core/studio/local_studio_repository.dart';
import '../../core/studio/studio_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/track_cover.dart';
import '../widgets/glass_bottom_menu_sheet.dart';
import '../widgets/glass_snack_bar.dart';
import 'studio_album_detail_page.dart';
import 'studio_artist_stats_page.dart';
import 'studio_editor_pages.dart';
import 'studio_track_stats_page.dart';
import 'studio_ui_helpers.dart';

/// Страница «Студия»: создание, редактирование и удаление альбомов и треков.
class StudioPage extends StatefulWidget {
  const StudioPage({
    super.key,
    required this.audioPlayerService,
    this.repository,
    this.currentUserNickname,
  });

  final AudioPlayerService audioPlayerService;
  final StudioRepository? repository;

  /// Ник текущего пользователя для кнопки «Я автор».
  final String? currentUserNickname;

  @override
  State<StudioPage> createState() => _StudioPageState();
}

class _StudioPageState extends State<StudioPage> {
  late final StudioRepository _repo = widget.repository ?? LocalStudioRepository();
  static const List<String> _artistSeedHints = [
    'alexwave',
    'lofi_nora',
    'nightcore_anna',
    'dockfr10',
    'synthfox',
    'mifoxti',
  ];

  List<Album> _albums = [];
  List<Track> _tracks = [];
  List<String> _customPaths = [];
  Map<String, TrackMetadataOverride> _overrides = {};
  Map<int, int> _playCountByServerId = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _loadFromUser() async {
    if (!mounted) return;
    if (!await ServerConnectivity.instance.guardUserNetworkAction(context)) {
      setState(() => _loading = false);
      return;
    }
    await _load();
  }

  void _addLinkedServerId(Set<int> linked, int? serverId) {
    if (serverId != null) linked.add(serverId);
  }

  /// Локальный `custom_*`, привязанный к id на сервере (обложка и файл живут здесь).
  String? _customAssetPathForServerId(int serverId) {
    for (final id in _customPaths) {
      if (_overrides[id]?.serverTrackId == serverId) return id;
    }
    return null;
  }

  String _editorAssetPathForTrack(Track? track) {
    if (track == null) {
      return 'custom_${DateTime.now().millisecondsSinceEpoch}';
    }
    final sid = TracksApi().resolveServerTrackId(
      assetPath: track.assetPath,
      audioFilePath: track.audioFilePath,
      metadataServerTrackId: _overrides[track.assetPath]?.serverTrackId,
    );
    if (sid != null) {
      final linked = _customAssetPathForServerId(sid);
      if (linked != null) return linked;
    }
    return track.assetPath;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final albums = await _repo.getAlbums();
    var overrides = await _repo.getTrackMetadataOverrides();
    final customPaths = await _repo.getCustomTrackPaths();
    if (!mounted) return;

    final linkedServerIds = <int>{};
    for (final o in overrides.values) {
      _addLinkedServerId(linkedServerIds, o.serverTrackId);
    }
    for (final id in customPaths) {
      _addLinkedServerId(linkedServerIds, TracksApi().parseServerTrackId(id));
    }

    final customTracks = <Track>[];
    for (final id in customPaths) {
      final o = overrides[id];
      final artistStr =
          (o != null && o.displayArtist.isNotEmpty) ? o.displayArtist : o?.artist;
      customTracks.add(Track(
        assetPath: id,
        title: o?.title ?? context.t('playlists.untitled'),
        artist: artistStr,
        coverAssetPath: o?.coverPath,
        audioFilePath: o?.audioFilePath,
      ));
    }

    final serverTracks = <Track>[];
    final playCounts = <int, int>{};
    final acc = await AuthSessionStore.readAccount();
    final loggedIn = acc != null && acc.sessionToken.trim().isNotEmpty;
    if (loggedIn && mounted) {
      final remote = await ServerConnectivity.instance.runOnline(
        context,
        () => TracksApi().fetchMyUploadedTracks(),
        showOfflineSheet: false,
      );
      if (remote != null) {
        final unmatched = <ServerTrackListItem>[];
        for (final item in remote) {
          playCounts[item.id] = item.playCount;
          if (linkedServerIds.contains(item.id)) continue;
          unmatched.add(item);
        }

        final orphanCustomIds = customPaths
            .where((id) => overrides[id]?.serverTrackId == null)
            .toList();
        if (orphanCustomIds.length == 1 && unmatched.length == 1) {
          final customId = orphanCustomIds.first;
          final o = overrides[customId];
          final serverItem = unmatched.first;
          final localTitle = (o?.title ?? '').trim().toLowerCase();
          final remoteTitle = serverItem.title.trim().toLowerCase();
          if (localTitle.isNotEmpty &&
              localTitle == remoteTitle &&
              o != null) {
            final repaired = o.copyWith(serverTrackId: serverItem.id);
            await _repo.saveTrackMetadataOverride(customId, repaired);
            overrides = {...overrides, customId: repaired};
            linkedServerIds.add(serverItem.id);
            unmatched.clear();
          }
        }

        for (final item in unmatched) {
          serverTracks.add(item.toTrack());
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _albums = albums;
      _overrides = overrides;
      _customPaths = customPaths;
      _playCountByServerId = playCounts;
      _tracks = [...serverTracks, ...customTracks];
      _loading = false;
    });
  }

  void _openArtistStats() {
    Navigator.of(context).push(
      ShellMaterialPageRoute<void>(
        builder: (_) => StudioArtistStatsPage(
          nickname: widget.currentUserNickname,
        ),
      ),
    );
  }

  int? _serverTrackId(Track track) {
    return TracksApi().resolveServerTrackId(
      assetPath: track.assetPath,
      audioFilePath: track.audioFilePath,
      metadataServerTrackId: _overrides[track.assetPath]?.serverTrackId,
    );
  }

  /// Свежие overrides + поиск по привязанному custom и по названию (если upload прошёл без serverTrackId).
  Future<int?> _resolveServerIdForDelete(Track track) async {
    final direct = _serverTrackId(track);
    if (direct != null) return direct;

    final overrides = await _repo.getTrackMetadataOverrides();
    final customPaths = await _repo.getCustomTrackPaths();
    final api = TracksApi();
    var sid = api.resolveServerTrackId(
      assetPath: track.assetPath,
      audioFilePath: track.audioFilePath,
      metadataServerTrackId: overrides[track.assetPath]?.serverTrackId,
    );
    if (sid != null) return sid;
    sid = api.parseServerTrackId(track.assetPath);
    if (sid != null) return sid;
    for (final id in customPaths) {
      final linked = overrides[id]?.serverTrackId;
      if (linked != null && id == track.assetPath) return linked;
    }
    if (track.assetPath.startsWith('custom_')) {
      final o = overrides[track.assetPath];
      final title = (o?.title ?? track.title).trim().toLowerCase();
      if (title.isNotEmpty) {
        try {
          final mine = await TracksApi().fetchMyUploadedTracks(limit: 200);
          final matches =
              mine.where((t) => t.title.trim().toLowerCase() == title).toList();
          if (matches.length == 1) return matches.first.id;
        } catch (_) {}
      }
    }
    return null;
  }

  String? _customAssetPathForServerIdIn(
    Map<String, TrackMetadataOverride> overrides,
    Iterable<String> customPaths,
    int serverId,
  ) {
    for (final id in customPaths) {
      if (overrides[id]?.serverTrackId == serverId) return id;
    }
    return null;
  }

  void _openTrackStats(Track track) {
    final id = _serverTrackId(track);
    if (id == null) return;
    Navigator.of(context).push(
      ShellMaterialPageRoute<void>(
        builder: (_) => StudioTrackStatsPage(
          trackId: id,
          trackTitle: track.title,
          artist: track.artistDisplay.isEmpty ? null : track.artistDisplay,
        ),
      ),
    );
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

  List<String> _artistSuggestions(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final names = <String>{
      ..._artistSeedHints,
      if ((widget.currentUserNickname ?? '').trim().isNotEmpty)
        widget.currentUserNickname!.trim(),
      ..._albums.map((e) => (e.artist ?? '').trim()).where((e) => e.isNotEmpty),
      ..._tracks.map((e) => e.artistDisplay.trim()).where((e) => e.isNotEmpty),
    };
    final filtered = names.where((e) => e.toLowerCase().contains(q)).toList()..sort();
    return filtered.take(6).toList(growable: false);
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
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(context.t('studio.title')),
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
            actions: [
              IconButton(
                tooltip: context.t('studio.stats.open'),
                icon: const Icon(Icons.insights_rounded),
                onPressed: _openArtistStats,
                color: palette.textPrimary,
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(54),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: palette.cardBackground.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
                    border: Border.all(
                      color: palette.textPrimary.withValues(alpha: 0.12),
                    ),
                  ),
                  child: TabBar(
                    dividerColor: Colors.transparent,
                    labelColor: palette.textPrimary,
                    unselectedLabelColor: palette.textMuted,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: palette.accent.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusLarge - 2,
                      ),
                    ),
                    tabs: [
                      Tab(text: context.t('studio.tracks')),
                      Tab(text: context.t('studio.albums')),
                    ],
                  ),
                ),
              ),
            ),
          ),
          body: _loading
              ? Center(child: CircularProgressIndicator(color: palette.accent))
              : TabBarView(
                  children: [
                    _TracksTab(
                      palette: palette,
                      audioPlayerService: widget.audioPlayerService,
                      tracks: _tracks,
                      overrides: _overrides,
                      customPaths: _customPaths,
                      playCountByServerId: _playCountByServerId,
                      trackWithOverrides: _trackWithOverrides,
                      serverTrackId: _serverTrackId,
                      onRefresh: () => unawaited(_loadFromUser()),
                      onAddTrack: _addTrack,
                      onEditTrack: _editTrack,
                      onDeleteTrack: _deleteTrack,
                      onOpenTrackStats: _openTrackStats,
                      repo: _repo,
                    ),
                    _AlbumsTab(
                      palette: palette,
                      albums: _albums,
                      allTracks: _tracks,
                      onRefresh: () => unawaited(_loadFromUser()),
                      onAddAlbum: _addAlbum,
                      onOpenAlbumDetail: _openAlbumDetail,
                      onEditAlbum: _editAlbum,
                      onDeleteAlbum: _deleteAlbum,
                      repo: _repo,
                    ),
                  ],
                ),
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

  Future<String?> _createStudioTrackReturnId() async {
    final result = await _showTrackDialog();
    if (result == null || !mounted) return null;
    final customPaths = List<String>.from(_customPaths);
    if (!customPaths.contains(result.assetPath)) customPaths.add(result.assetPath);
    await _repo.saveCustomTrackPaths(customPaths);
    await _repo.saveTrackMetadataOverride(result.assetPath, result.metadata);
    await _load();
    return result.assetPath;
  }

  void _openAlbumDetail(Album album) {
    Navigator.of(context).push<void>(
      ShellMaterialPageRoute<void>(
        builder: (ctx) => StudioAlbumDetailPage(
          albumId: album.id,
          studioRepository: _repo,
          audioPlayerService: widget.audioPlayerService,
          onStudioDataChanged: _load,
          showAlbumEditDialog: (a) => _showAlbumDialog(album: a),
          onCreateNewStudioTrackReturnId: _createStudioTrackReturnId,
          showEditTrackDialog: (t) => _showTrackDialog(track: t),
          onDeleteAlbum: _deleteAlbum,
        ),
      ),
    );
  }

  Future<void> _deleteAlbum(Album album) async {
    final confirm = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('studio.deleteAlbum')),
        content: Text('«${album.title}» будет удалён.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.t('common.cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.t('studio.delete'), style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final albums = _albums.where((a) => a.id != album.id).toList();
    await _repo.saveAlbums(albums);
    _load();
  }

  /// Редактор альбома — отдельный маршрут корневого [Navigator], иначе слой
  /// дока в [MainShell] перекрывает диалоги.
  Future<Album?> _showAlbumDialog({Album? album}) {
    return Navigator.of(context, rootNavigator: true).push<Album>(
      ShellMaterialPageRoute<Album>(
        builder: (_) => StudioAlbumEditorPage(
          initialAlbum: album,
          allTracks: _tracks,
          suggestArtists: _artistSuggestions,
        ),
      ),
    );
  }

  Future<void> _addTrack() async {
    final result = await _showTrackDialog();
    if (result == null || !mounted) return;
    final customPaths = List<String>.from(_customPaths);
    if (!customPaths.contains(result.assetPath)) customPaths.add(result.assetPath);
    await _repo.saveCustomTrackPaths(customPaths);
    await _repo.saveTrackMetadataOverride(result.assetPath, result.metadata);
    _load();
  }

  Future<void> _editTrack(Track track) async {
    final result = await _showTrackDialog(track: track);
    if (result == null || !mounted) return;
    final meta = result.metadata;
    final sid = TracksApi().resolveServerTrackId(
      assetPath: result.assetPath,
      audioFilePath: meta.audioFilePath ?? track.audioFilePath,
      metadataServerTrackId: meta.serverTrackId,
    );
    if (sid != null) {
      try {
        await TracksApi().updateTrackMetadata(
          trackId: sid,
          title: meta.title,
          artist: meta.displayArtist.isNotEmpty ? meta.displayArtist : meta.artist,
        );
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('studio.serverUploadFail'))),
        );
        return;
      }
      await _repo.saveTrackMetadataOverride(
        result.assetPath,
        TrackMetadataOverride(
          coverPath: meta.coverPath,
          genres: meta.genres,
          audioFilePath: meta.audioFilePath,
          coAuthors: meta.coAuthors,
          serverTrackId: sid,
        ),
      );
    } else {
      await _repo.saveTrackMetadataOverride(result.assetPath, meta);
    }
    _load();
  }

  Future<void> _deleteTrack(Track track) async {
    final confirm = await showGlassHoldToConfirmSheet(
      context,
      title: context.t('studio.deleteTrack'),
      message: '«${track.title}»\n${context.t('studio.deleteConfirm')}',
      confirmLabel: context.t('studio.delete'),
      cancelLabel: context.t('common.cancel'),
      holdHint: context.t('studio.deleteHoldHint'),
    );
    if (confirm != true || !mounted) return;

    final sid = await _resolveServerIdForDelete(track);
    final acc = await AuthSessionStore.readAccount();
    final hasToken = acc != null && acc.sessionToken.trim().isNotEmpty;
    if (sid != null && !hasToken) {
      if (mounted) {
        showGlassSnackBar(context, context.t('studio.serverNeedLogin'));
      }
      return;
    }
    if (sid != null && hasToken) {
      try {
        await TracksApi().deleteServerTrack(sid);
      } on DioException catch (e) {
        final code = e.response?.statusCode;
        if (kDebugMode) {
          debugPrint('Studio delete track $sid failed: $code ${e.message}');
        }
        if (!mounted) return;
        if (code == 403) {
          showGlassSnackBar(
            context,
            Localizations.localeOf(context).languageCode == 'en'
                ? 'You can only delete tracks you uploaded.'
                : 'Можно удалить только свои загруженные треки.',
          );
          return;
        }
        if (code != 404) {
          showGlassSnackBar(context, context.t('studio.deleteServerFailed'));
          return;
        }
      } catch (e) {
        if (kDebugMode) debugPrint('Studio delete track $sid failed: $e');
        if (!mounted) return;
        showGlassSnackBar(context, context.t('studio.deleteServerFailed'));
        return;
      }
    }
    if (sid != null) {
      await widget.audioPlayerService.removeFromFavorites('server_track_$sid');
    }

    final freshOverrides = await _repo.getTrackMetadataOverrides();
    var customPaths = await _repo.getCustomTrackPaths();
    customPaths = customPaths.where((p) => p != track.assetPath).toList();
    final keysToClear = <String>{track.assetPath};
    if (sid != null) {
      final linkedCustom = _customAssetPathForServerIdIn(
        freshOverrides,
        customPaths,
        sid,
      ) ??
          _customAssetPathForServerId(sid);
      if (linkedCustom != null) {
        keysToClear.add(linkedCustom);
        customPaths = customPaths.where((p) => p != linkedCustom).toList();
      }
      keysToClear.add('server_track_$sid');
    }
    await _repo.saveCustomTrackPaths(customPaths);
    for (final key in keysToClear) {
      await _repo.saveTrackMetadataOverride(key, null);
    }
    final albums = _albums.map((a) => a.copyWith(
      trackAssetPaths: a.trackAssetPaths.where((p) => !keysToClear.contains(p)).toList(),
    )).toList();
    await _repo.saveAlbums(albums);
    _load();
  }

  Future<({String assetPath, TrackMetadataOverride metadata})?> _showTrackDialog({Track? track}) {
    final id = _editorAssetPathForTrack(track);
    final o = _overrides[id] ??
        (track != null ? _overrides[track.assetPath] : null);
    final editorTrack = track != null && track.assetPath == id
        ? track
        : (track != null
            ? Track(
                assetPath: id,
                title: o?.title ?? track.title,
                artist: o?.displayArtist.isNotEmpty == true
                    ? o!.displayArtist
                    : (o?.artist ?? track.artist),
                coverAssetPath: o?.coverPath ?? track.coverAssetPath,
                audioFilePath: o?.audioFilePath ?? track.audioFilePath,
              )
            : null);
    return Navigator.of(context, rootNavigator: true).push(
      ShellMaterialPageRoute<({String assetPath, TrackMetadataOverride metadata})>(
        builder: (_) => StudioTrackEditorPage(
          assetPath: id,
          track: editorTrack,
          metadataOverride: o,
          nickname: widget.currentUserNickname,
          suggestArtists: _artistSuggestions,
        ),
      ),
    );
  }
}

class _AlbumsTab extends StatelessWidget {
  const _AlbumsTab({
    required this.palette,
    required this.albums,
    required this.allTracks,
    required this.onRefresh,
    required this.onAddAlbum,
    required this.onOpenAlbumDetail,
    required this.onEditAlbum,
    required this.onDeleteAlbum,
    required this.repo,
  });

  final AppColorPalette palette;
  final List<Album> albums;
  final List<Track> allTracks;
  final VoidCallback onRefresh;
  final Future<void> Function() onAddAlbum;
  final void Function(Album album) onOpenAlbumDetail;
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
              Text('${context.t('studio.albums')} (${albums.length})', style: TextStyle(fontSize: 14, color: palette.textSecondary)),
              const Spacer(),
              FilledButton.icon(
                onPressed: onAddAlbum,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: Text(context.t('studio.addAlbum')),
                style: FilledButton.styleFrom(backgroundColor: palette.accent),
              ),
            ],
          ),
        ),
        Expanded(
          child: albums.isEmpty
              ? Center(child: Text(context.t('studio.noAlbums'), style: TextStyle(color: palette.textMuted)))
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
                                  label: Text(studioGenreChipLabel(context, g), style: TextStyle(fontSize: 10, color: palette.textSecondary)),
                                  padding: EdgeInsets.zero,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                )).toList(),
                              ),
                            ],
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) async {
                            if (v == 'edit') await onEditAlbum(album);
                            if (v == 'delete') await onDeleteAlbum(album);
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(value: 'edit', child: Text(context.t('studio.edit'))),
                            PopupMenuItem(value: 'delete', child: Text(context.t('studio.delete'))),
                          ],
                        ),
                        onTap: () => onOpenAlbumDetail(album),
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
    required this.audioPlayerService,
    required this.tracks,
    required this.overrides,
    required this.customPaths,
    required this.playCountByServerId,
    required this.trackWithOverrides,
    required this.serverTrackId,
    required this.onRefresh,
    required this.onAddTrack,
    required this.onEditTrack,
    required this.onDeleteTrack,
    required this.onOpenTrackStats,
    required this.repo,
  });

  final AppColorPalette palette;
  final AudioPlayerService audioPlayerService;
  final List<Track> tracks;
  final Map<String, TrackMetadataOverride> overrides;
  final List<String> customPaths;
  final Map<int, int> playCountByServerId;
  final Track Function(Track) trackWithOverrides;
  final int? Function(Track) serverTrackId;
  final VoidCallback onRefresh;
  final Future<void> Function() onAddTrack;
  final Future<void> Function(Track) onEditTrack;
  final Future<void> Function(Track) onDeleteTrack;
  final void Function(Track) onOpenTrackStats;
  final StudioRepository repo;

  String _playsLabel(BuildContext context, Track track) {
    final sid = serverTrackId(track);
    if (sid == null) return '—';
    final n = playCountByServerId[sid] ?? 0;
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    if (n >= 1000) {
      final k = (n / 1000).toStringAsFixed(1);
      return isEn ? '${k}K plays' : '$k тыс. прослушиваний';
    }
    return isEn ? '$n plays' : '$n прослушиваний';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text('${context.t('studio.tracks')} (${tracks.length})', style: TextStyle(fontSize: 14, color: palette.textSecondary)),
              const Spacer(),
              FilledButton.icon(
                onPressed: onAddTrack,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: Text(context.t('studio.addTrack')),
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
                      if (track.assetPath.startsWith('server_track_')) ...[
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.cloud_done_rounded, size: 12, color: palette.accent),
                            const SizedBox(width: 4),
                            Text(
                              context.t('studio.onServer'),
                              style: TextStyle(fontSize: 11, color: palette.accent),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.headphones_rounded, size: 12, color: palette.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            _playsLabel(context, track),
                            style: TextStyle(fontSize: 11, color: palette.textSecondary),
                          ),
                        ],
                      ),
                      if (overrides[track.assetPath]?.genres.isNotEmpty ?? false) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 4,
                          runSpacing: 2,
                          children: (overrides[track.assetPath]!.genres).map((g) => Chip(
                            label: Text(studioGenreChipLabel(context, g), style: TextStyle(fontSize: 10, color: palette.textSecondary)),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          )).toList(),
                        ),
                      ],
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'stats') onOpenTrackStats(track);
                      if (v == 'edit') await onEditTrack(track);
                      if (v == 'delete') await onDeleteTrack(track);
                    },
                    itemBuilder: (_) => [
                      if (serverTrackId(track) != null)
                        PopupMenuItem(
                          value: 'stats',
                          child: Text(context.t('studio.stats.trackMenu')),
                        ),
                      PopupMenuItem(value: 'edit', child: Text(context.t('studio.edit'))),
                      PopupMenuItem(value: 'delete', child: Text(context.t('studio.delete'))),
                    ],
                  ),
                  onTap: () async {
                    final queue = tracks.map(trackWithOverrides).toList();
                    final service = audioPlayerService;
                    final same = service.currentTrack?.assetPath == track.assetPath &&
                        service.currentTrack?.audioFilePath == track.audioFilePath;
                    if (same) {
                      await service.togglePlayPause();
                      return;
                    }
                    await service.playTrack(track, queue: queue);
                    if (!context.mounted) return;
                    PlayerDockHost.expand();
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
