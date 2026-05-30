import 'package:flutter/material.dart';

import '../../core/audio/audio_player_service.dart';
import '../../core/audio/track.dart';
import '../../core/l10n/app_localization.dart';
import '../../core/network/albums_api.dart';
import '../../core/network/api_config.dart';
import '../../core/network/server_connectivity.dart';
import '../../core/player/shell_route_back_guard.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/cover_image.dart';

class MyAlbumsPage extends StatefulWidget {
  const MyAlbumsPage({
    super.key,
    required this.audioPlayerService,
  });

  final AudioPlayerService audioPlayerService;

  @override
  State<MyAlbumsPage> createState() => _MyAlbumsPageState();
}

class _MyAlbumsPageState extends State<MyAlbumsPage> {
  List<MyAlbumListItemRemote> _albums = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted && !await ServerConnectivity.instance.guardUserNetworkAction(context)) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await AlbumsApi().fetchMyAlbums();
      if (!mounted) return;
      setState(() {
        _albums = list;
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
          title: Text(context.t('albums.myTitle')),
          backgroundColor: Colors.transparent,
        ),
        body: _loading
            ? Center(child: CircularProgressIndicator(color: palette.accent))
            : _error != null
                ? Center(child: Text(_error!, style: TextStyle(color: palette.textSecondary)))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _albums.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height: MediaQuery.sizeOf(context).height * 0.3,
                                child: Center(
                                  child: Text(
                                    context.t('albums.empty'),
                                    style: TextStyle(color: palette.textMuted),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _albums.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final a = _albums[index];
                              return _AlbumTile(
                                album: a,
                                palette: palette,
                                onTap: () => _openAlbum(a),
                              );
                            },
                          ),
                  ),
      ),
    );
  }

  Future<void> _openAlbum(MyAlbumListItemRemote album) async {
    await Navigator.of(context).push(
      ShellMaterialPageRoute<void>(
        builder: (_) => MyAlbumDetailPage(
          albumId: album.id,
          title: album.title ?? context.t('playlists.untitled'),
          audioPlayerService: widget.audioPlayerService,
        ),
      ),
    );
  }
}

class _AlbumTile extends StatelessWidget {
  const _AlbumTile({
    required this.album,
    required this.palette,
    required this.onTap,
  });

  final MyAlbumListItemRemote album;
  final AppColorPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final countLabel = context
        .t('albums.tracksCount')
        .replaceAll('{n}', '${album.trackCount}');
    return Material(
      color: palette.cardBackground.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              buildCoverImage(
                imageUrl: albumCoverUrl(album.id),
                width: 56,
                height: 56,
                borderRadius: BorderRadius.circular(10),
                placeholder: Icon(Icons.album, color: palette.textMuted),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      album.title ?? context.t('playlists.untitled'),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: palette.textPrimary,
                      ),
                    ),
                    Text(countLabel, style: TextStyle(color: palette.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: palette.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class MyAlbumDetailPage extends StatefulWidget {
  const MyAlbumDetailPage({
    super.key,
    required this.albumId,
    required this.title,
    required this.audioPlayerService,
  });

  final int albumId;
  final String title;
  final AudioPlayerService audioPlayerService;

  @override
  State<MyAlbumDetailPage> createState() => _MyAlbumDetailPageState();
}

class _MyAlbumDetailPageState extends State<MyAlbumDetailPage> {
  AlbumDetailRemote? _detail;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await AlbumsApi().fetchAlbumDetail(widget.albumId);
      if (!mounted) return;
      setState(() {
        _detail = d;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Track _trackFromEntry(AlbumTrackEntryRemote e) {
    final b = ApiConfig.baseUrl.replaceAll(RegExp(r'/+$'), '');
    return Track(
      assetPath: 'server_track_${e.trackId}',
      title: e.title ?? '',
      artist: e.artist,
      audioFilePath: '$b/tracks/${e.trackId}/stream',
      coverAssetPath: '$b/tracks/${e.trackId}/cover',
    );
  }

  Future<void> _play(AlbumTrackEntryRemote e) async {
    final detail = _detail;
    if (detail == null) return;
    final queue = detail.tracks.map(_trackFromEntry).toList();
    if (queue.isEmpty) return;
    final selected = _trackFromEntry(e);
    await widget.audioPlayerService.playTrack(selected, queue: queue);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    final tracks = _detail?.tracks ?? const [];
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: palette.accent))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: tracks.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final e = tracks[i];
                return ListTile(
                  title: Text(e.title ?? ''),
                  subtitle: Text(e.artist ?? ''),
                  trailing: const Icon(Icons.play_arrow_rounded),
                  onTap: () => _play(e),
                );
              },
            ),
    );
  }
}
