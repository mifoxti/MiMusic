import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/audio/audio_player_service.dart';
import '../../core/constants/app_constants.dart';
import '../../core/player/shell_route_back_guard.dart';
import '../../core/l10n/app_localization.dart';
import '../../core/platform/cover_pick_save.dart';
import '../../core/platform/platform.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/track_cover.dart';
import '../../core/network/playlists_api.dart';
import '../../features/playlists/data/repositories/local_playlists_repository.dart';
import '../../features/playlists/data/repositories/remote_playlists_repository.dart';
import '../../features/playlists/data/repositories/session_aware_playlists_repository.dart';
import '../../features/playlists/domain/entities/playlist.dart';
import '../../features/playlists/domain/repositories/playlists_repository.dart';
import 'playlist_detail_page.dart';

/// Страница «Плейлисты»: список плейлистов и кнопка «Создать плейлист».
class PlaylistsPage extends StatefulWidget {
  const PlaylistsPage({
    super.key,
    required this.audioPlayerService,
    PlaylistsRepository? repository,
  }) : _repository = repository;

  final AudioPlayerService audioPlayerService;
  final PlaylistsRepository? _repository;

  @override
  State<PlaylistsPage> createState() => _PlaylistsPageState();
}

class _PlaylistsPageState extends State<PlaylistsPage> {
  late final PlaylistsRepository _repo =
      widget._repository ?? LocalPlaylistsRepository();
  _PlaylistsTab _tab = _PlaylistsTab.mine;

  List<Playlist> _playlists = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<bool> _canLoadPublicCatalog() async {
    final r = widget._repository;
    if (r is SessionAwarePlaylistsRepository) {
      return r.hasRemoteSession;
    }
    if (r is RemotePlaylistsRepository) {
      return true;
    }
    return false;
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

  Future<void> _togglePlaylistLike(Playlist p) async {
    await _repo.savePlaylist(p.copyWith(isLiked: !p.isLiked));
    if (mounted) await _load();
  }

  Future<void> _openPlaylist(Playlist playlist) async {
    await Navigator.of(context).push(
      ShellMaterialPageRoute<void>(
        builder: (context) => PlaylistDetailPage(
          playlistId: playlist.id,
          audioPlayerService: widget.audioPlayerService,
          repository: _repo,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Widget _buildMineTab(AppColorPalette palette) {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: palette.accent));
    }
    return Column(
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
                backgroundColor: palette.accent.withValues(alpha: 0.2),
                foregroundColor: palette.textPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                side: BorderSide(
                  color: palette.accent.withValues(alpha: 0.55),
                ),
                elevation: 0,
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
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final p = _playlists[index];
                return _PlaylistTile(
                  playlist: p,
                  onTap: () => _openPlaylist(p),
                  onToggleLike: () => _togglePlaylistLike(p),
                );
              },
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    final topPadding = MediaQuery.paddingOf(context).top;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTabToggle(palette, isDark),
              const SizedBox(height: 8),
              Expanded(
                child: _tab == _PlaylistsTab.mine
                    ? _buildMineTab(palette)
                    : _PlaylistsDiscoverTab(
                        palette: palette,
                        audioPlayerService: widget.audioPlayerService,
                        repository: _repo,
                        canUseRemote: _canLoadPublicCatalog,
                        onOpenPlaylist: _openPlaylist,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabToggle(AppColorPalette palette, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.cardBackground.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(
          color: palette.primaryLight.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _PlaylistTabChip(
              label: context.t('playlists.tabMine'),
              icon: Icons.library_music_rounded,
              selected: _tab == _PlaylistsTab.mine,
              palette: palette,
              isDark: isDark,
              onTap: () => setState(() => _tab = _PlaylistsTab.mine),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _PlaylistTabChip(
              label: context.t('playlists.tabDiscover'),
              icon: Icons.travel_explore_rounded,
              selected: _tab == _PlaylistsTab.discover,
              palette: palette,
              isDark: isDark,
              onTap: () => setState(() => _tab = _PlaylistsTab.discover),
            ),
          ),
        ],
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
                              final copied = await pickAndSaveCoverImage(id);
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
                      isLiked: existing?.isLiked ?? false,
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
    required this.onToggleLike,
  });

  final Playlist playlist;
  final VoidCallback onTap;
  final VoidCallback onToggleLike;

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

    final trackCount = playlist.displayTrackCount;
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final subtitle = trackCount == 0
        ? context.t('playlists.emptyPlaylist')
        : isEn
            ? '$trackCount tracks'
            : '$trackCount трек${trackCount == 1 ? '' : trackCount >= 2 && trackCount <= 4 ? 'а' : 'ов'}';

    return Material(
      color: palette.cardBackground.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
            border: Border.all(
              color: palette.primaryLight.withValues(alpha: 0.35),
            ),
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
              if (!playlist.isPrivate)
                IconButton(
                  tooltip: context.t('playlists.likePlaylist'),
                  onPressed: onToggleLike,
                  icon: Icon(
                    playlist.isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: playlist.isLiked ? palette.accent : palette.textMuted,
                    size: 22,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
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
    if (coverPath.startsWith('http://') || coverPath.startsWith('https://')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        child: buildTrackCover(
          coverSource: coverPath,
          width: size,
          height: size,
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          placeholder: placeholder,
        ),
      );
    }
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

class _PlaylistsDiscoverTab extends StatefulWidget {
  const _PlaylistsDiscoverTab({
    required this.palette,
    required this.audioPlayerService,
    required this.repository,
    required this.canUseRemote,
    required this.onOpenPlaylist,
  });

  final AppColorPalette palette;
  final AudioPlayerService audioPlayerService;
  final PlaylistsRepository repository;
  final Future<bool> Function() canUseRemote;
  final void Function(Playlist playlist) onOpenPlaylist;

  @override
  State<_PlaylistsDiscoverTab> createState() => _PlaylistsDiscoverTabState();
}

class _PlaylistsDiscoverTabState extends State<_PlaylistsDiscoverTab> {
  final TextEditingController _query = TextEditingController();
  Timer? _debounce;
  List<PublicPlaylistItemRemote> _items = [];
  bool _loading = false;
  String? _error;
  bool? _remoteOk;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final ok = await widget.canUseRemote();
    if (!mounted) return;
    setState(() => _remoteOk = ok);
    if (ok) {
      await _load();
    }
  }

  Future<void> _load() async {
    if (_remoteOk != true) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await PlaylistsApi().fetchPublicPlaylists(
        query: _query.text,
        limit: 50,
      );
      if (!mounted) return;
      setState(() {
        _items = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _scheduleLoad() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) unawaited(_load());
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    if (_remoteOk == false) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            context.t('playlists.discoverLoginRequired'),
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.textSecondary, fontSize: 15),
          ),
        ),
      );
    }
    if (_remoteOk == null) {
      return Center(child: CircularProgressIndicator(color: palette.accent));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _query,
          onChanged: (_) => _scheduleLoad(),
          style: TextStyle(color: palette.textPrimary),
          decoration: InputDecoration(
            hintText: context.t('playlists.publicSearchHint'),
            hintStyle: TextStyle(color: palette.textMuted),
            filled: true,
            fillColor: palette.cardBackground.withValues(alpha: 0.85),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
              borderSide: BorderSide.none,
            ),
            prefixIcon: Icon(Icons.search_rounded, color: palette.textMuted),
          ),
        ),
        const SizedBox(height: 12),
        if (_loading)
          Expanded(
            child: Center(
              child: CircularProgressIndicator(color: palette.accent),
            ),
          )
        else if (_error != null)
          Expanded(
            child: Center(
              child: Text(
                context.t('playlists.publicLoadError'),
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.textSecondary, fontSize: 14),
              ),
            ),
          )
        else if (_items.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                context.t('playlists.publicEmpty'),
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.textSecondary, fontSize: 15),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              itemCount: _items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final e = _items[i];
                final nick = (e.ownerNickname ?? '').trim();
                final ownerLabel = nick.isNotEmpty ? '@$nick' : 'id:${e.ownerUserId}';
                final en = Localizations.localeOf(context).languageCode == 'en';
                final sub = en
                    ? '${e.trackCount} tracks · ♥ ${e.likesCount} · $ownerLabel'
                    : '${e.trackCount} трек${e.trackCount == 1 ? '' : e.trackCount >= 2 && e.trackCount <= 4 ? 'а' : 'ов'} · ♥ ${e.likesCount} · $ownerLabel';
                return Material(
                  color: palette.cardBackground.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
                    onTap: () {
                      final pl = Playlist(
                        id: RemotePlaylistsRepository.idForServer(e.id),
                        title: (e.title ?? '').trim().isEmpty ? '—' : e.title!.trim(),
                        isPrivate: false,
                        coverPath: playlistCoverUrl(e.id),
                        trackAssetPaths: const [],
                        isLiked: false,
                        remoteTrackCount: e.trackCount,
                      );
                      widget.onOpenPlaylist(pl);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
                          border: Border.all(
                            color: palette.primaryLight.withValues(alpha: 0.35),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Row(
                        children: [
                          buildTrackCover(
                            coverSource: playlistCoverUrl(e.id),
                            width: 56,
                            height: 56,
                            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                            placeholder: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: palette.primaryDark.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                              ),
                              child: Icon(Icons.queue_music_rounded, color: palette.textMuted),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (e.title ?? '').trim().isEmpty ? '—' : e.title!.trim(),
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
                                  sub,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: palette.textSecondary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: palette.textMuted),
                        ],
                      ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

enum _PlaylistsTab { mine, discover }

class _PlaylistTabChip extends StatelessWidget {
  const _PlaylistTabChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.palette,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final AppColorPalette palette;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge - 2),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge - 2),
            color: selected
                ? palette.accent.withValues(alpha: isDark ? 0.28 : 0.22)
                : Colors.transparent,
            border: Border.all(
              color: selected
                  ? palette.accent.withValues(alpha: 0.55)
                  : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? palette.accent : palette.textMuted,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? palette.textPrimary : palette.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

