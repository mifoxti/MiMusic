import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/audio/audio_player_service.dart';
import '../../core/audio/local_tracks.dart';
import '../../core/audio/track.dart';
import '../../core/constants/app_constants.dart';
import '../../core/l10n/app_localization.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/track_cover.dart';
import '../../features/home/domain/entities/listening_friend.dart';
import '../../features/home/domain/entities/release_item.dart';
import '../../features/home/domain/use_cases/get_home_section_use_case.dart';
import '../../core/player/player_dock_host.dart';
import '../../core/auth/auth_session_store.dart';
import '../../core/network/playlists_api.dart';
import '../../core/network/users_api.dart';
import '../../core/player/shell_route_back_guard.dart';
import '../../features/playlists/data/repositories/remote_playlists_repository.dart';
import '../../features/playlists/domain/repositories/playlists_repository.dart';
import 'artist_page.dart';
import 'playlist_detail_page.dart';

/// Режим поиска: музыка (треки + релизы как альбомы) или пользователи.
enum _SearchMode { music, people }

/// Вкладка «Поиск»: переключатель музыка / люди, поле ввода, результаты в стиле приложения.
class SearchPage extends StatefulWidget {
  const SearchPage({
    super.key,
    required this.audioPlayerService,
    required this.getHomeSectionUseCase,
    required this.playlistsRepository,
  });

  final AudioPlayerService audioPlayerService;
  final GetHomeSectionUseCase getHomeSectionUseCase;
  final PlaylistsRepository playlistsRepository;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _queryController = TextEditingController();
  _SearchMode _mode = _SearchMode.music;

  List<Track> _allTracks = [];
  List<ReleaseItem> _releases = [];
  List<String> _suggestionArtists = [];
  bool _loading = true;
  Timer? _playlistSearchDebounce;
  List<PublicPlaylistItemRemote> _publicPlaylistResults = [];
  bool _playlistSearchBusy = false;
  Timer? _peopleSearchDebounce;
  List<ListeningFriend> _peopleResults = [];
  bool _peopleSearchBusy = false;
  /// В выдаче был только текущий пользователь — показываем шутку вместо «не найдено».
  bool _peopleSearchOnlySelf = false;

  @override
  void initState() {
    super.initState();
    _load();
    _queryController.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _playlistSearchDebounce?.cancel();
    _peopleSearchDebounce?.cancel();
    _queryController.removeListener(_onQueryChanged);
    _queryController.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    setState(() {});
    _schedulePublicPlaylistSearch();
    _schedulePeopleSearch();
  }

  void _schedulePublicPlaylistSearch() {
    _playlistSearchDebounce?.cancel();
    if (_mode != _SearchMode.music) return;
    if (_query.trim().isEmpty) {
      setState(() {
        _publicPlaylistResults = [];
        _playlistSearchBusy = false;
      });
      return;
    }
    _playlistSearchDebounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      setState(() => _playlistSearchBusy = true);
      try {
        final list = await PlaylistsApi().fetchPublicPlaylists(query: _query.trim(), limit: 40);
        if (!mounted) return;
        setState(() {
          _publicPlaylistResults = list;
          _playlistSearchBusy = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _publicPlaylistResults = [];
          _playlistSearchBusy = false;
        });
      }
    });
  }

  void _schedulePeopleSearch() {
    _peopleSearchDebounce?.cancel();
    if (_mode != _SearchMode.people) return;
    final q = _query.trim();
    if (q.isEmpty) {
      setState(() {
        _peopleResults = [];
        _peopleSearchBusy = false;
        _peopleSearchOnlySelf = false;
      });
      return;
    }
    if (q.length < 2) {
      setState(() {
        _peopleResults = [];
        _peopleSearchBusy = false;
        _peopleSearchOnlySelf = false;
      });
      return;
    }
    _peopleSearchDebounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      setState(() {
        _peopleSearchBusy = true;
        _peopleSearchOnlySelf = false;
      });
      try {
        final rows = await UsersApi().searchUsers(q);
        if (!mounted) return;
        final acc = await AuthSessionStore.readAccount();
        final myId = acc?.userId;
        final bust = DateTime.now().millisecondsSinceEpoch;
        final others =
            myId == null ? rows : rows.where((u) => u.id != myId).toList(growable: false);
        final onlySelf = myId != null &&
            rows.isNotEmpty &&
            others.isEmpty &&
            rows.every((u) => u.id == myId);
        if (!mounted) return;
        setState(() {
          _peopleSearchOnlySelf = onlySelf;
          _peopleResults = others
              .map(
                (u) => ListeningFriend(
                  username: u.nickname,
                  avatarUrl: userAvatarUrl(u.id, cacheBust: bust),
                ),
              )
              .toList();
          _peopleSearchBusy = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _peopleResults = [];
          _peopleSearchBusy = false;
          _peopleSearchOnlySelf = false;
        });
      }
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final section = await widget.getHomeSectionUseCase();
      final tracks = await loadLocalTracks();
      if (!mounted) return;
      setState(() {
        _allTracks = tracks;
        _releases = section.latestReleases;
        _suggestionArtists = section.historyArtists;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _query => _queryController.text.trim();

  List<Track> get _filteredTracks {
    final q = _query.toLowerCase();
    if (q.isEmpty) return [];
    bool matches(Track t) {
      if (t.title.toLowerCase().contains(q)) return true;
      final artist = t.artistDisplay.toLowerCase();
      if (artist.isNotEmpty && artist.contains(q)) return true;
      final file = t.assetPath.split('/').last.toLowerCase();
      if (file.contains(q)) return true;
      final combined = '${t.artistDisplay} ${t.title}'.toLowerCase().trim();
      if (combined.contains(q)) return true;
      return false;
    }

    return _allTracks.where(matches).toList();
  }

  List<ReleaseItem> get _filteredAlbums {
    final q = _query.toLowerCase();
    if (q.isEmpty) return [];
    return _releases
        .where((r) => r.title.toLowerCase().contains(q))
        .toList();
  }

  void _openFullPlayer() {
    PlayerDockHost.expand();
  }

  Future<void> _onTrackTap(Track track, List<Track> queue) async {
    final service = widget.audioPlayerService;
    final same = service.currentTrack?.assetPath == track.assetPath &&
        service.currentTrack?.audioFilePath == track.audioFilePath;
    if (same) {
      await service.togglePlayPause();
      return;
    }
    await service.playTrack(track, queue: queue);
    if (mounted) _openFullPlayer();
  }

  void _onAlbumTap(int releaseIndex) {
    if (_allTracks.isEmpty) return;
    final i = releaseIndex.clamp(0, _allTracks.length - 1);
    final track = _allTracks[i];
    _onTrackTap(track, _allTracks);
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
        body: ListenableBuilder(
          listenable: widget.audioPlayerService,
          builder: (context, _) {
            if (_loading) {
              return Center(
                child: CircularProgressIndicator(color: palette.accent),
              );
            }
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 12 + topPadding, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          context.t('search.title'),
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: palette.textPrimary,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _mode == _SearchMode.music
                              ? context.t('search.musicSub')
                              : context.t('search.peopleSub'),
                          style: TextStyle(
                            fontSize: 14,
                            color: palette.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildModeToggle(palette),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _queryController,
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 16,
                          ),
                          cursorColor: palette.accent,
                          decoration: InputDecoration(
                            isDense: true,
                            filled: true,
                            fillColor:
                                palette.cardBackground.withValues(alpha: 0.92),
                            hintText: _mode == _SearchMode.music
                                ? context.t('search.musicHint')
                                : context.t('search.peopleHint'),
                            hintStyle: TextStyle(
                              color: palette.textMuted,
                              fontSize: 15,
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: palette.textMuted,
                              size: 24,
                            ),
                            suffixIcon: _query.isEmpty
                                ? null
                                : IconButton(
                                    onPressed: () {
                                      _queryController.clear();
                                    },
                                    icon: Icon(
                                      Icons.close_rounded,
                                      color: palette.textMuted,
                                      size: 22,
                                    ),
                                  ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 4,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppConstants.radiusLarge,
                              ),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppConstants.radiusLarge,
                              ),
                              borderSide: BorderSide(
                                color: palette.primaryLight.withValues(
                                  alpha: 0.35,
                                ),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppConstants.radiusLarge,
                              ),
                              borderSide: BorderSide(
                                color: palette.accent.withValues(alpha: 0.55),
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                        if (_mode == _SearchMode.music &&
                            _query.isEmpty &&
                            _suggestionArtists.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          Text(
                            context.t('search.frequent'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: palette.textMuted,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _suggestionArtists
                                .map(
                                  (a) => ActionChip(
                                    label: Text(a),
                                    onPressed: () {
                                      _queryController.text = a;
                                      _queryController.selection =
                                          TextSelection.collapsed(
                                        offset: _queryController.text.length,
                                      );
                                    },
                                    backgroundColor: palette.primaryLight
                                        .withValues(alpha: 0.55),
                                    labelStyle: TextStyle(
                                      fontSize: 13,
                                      color: palette.textPrimary,
                                    ),
                                    side: BorderSide(
                                      color: palette.accent.withValues(
                                        alpha: 0.2,
                                      ),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (_query.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 120),
                      child: Column(
                        children: [
                          Icon(
                            _mode == _SearchMode.music
                                ? Icons.music_note_rounded
                                : Icons.people_outline_rounded,
                            size: 56,
                            color: palette.textMuted.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _mode == _SearchMode.music
                                ? context.t('search.emptyMusic')
                                : context.t('search.emptyPeople'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: palette.textSecondary,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_mode == _SearchMode.music)
                  ..._buildMusicResultsSlivers(palette)
                else
                  ..._buildPeopleResultsSlivers(palette),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildModeToggle(AppColorPalette palette) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
            child: _ModeChip(
              label: context.t('search.musicMode'),
              icon: Icons.library_music_rounded,
              selected: _mode == _SearchMode.music,
              palette: palette,
              isDark: isDark,
              onTap: () {
                setState(() => _mode = _SearchMode.music);
                _peopleSearchDebounce?.cancel();
                _schedulePublicPlaylistSearch();
              },
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _ModeChip(
              label: context.t('search.peopleMode'),
              icon: Icons.person_search_rounded,
              selected: _mode == _SearchMode.people,
              palette: palette,
              isDark: isDark,
              onTap: () {
                setState(() => _mode = _SearchMode.people);
                _playlistSearchDebounce?.cancel();
                _schedulePeopleSearch();
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMusicResultsSlivers(AppColorPalette palette) {
    final albums = _filteredAlbums;
    final tracks = _filteredTracks;
    final playlists = _publicPlaylistResults;
    if (albums.isEmpty && tracks.isEmpty && playlists.isEmpty && !_playlistSearchBusy) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 120),
            child: Center(
              child: Text(
                context.t('search.notFound'),
                style: TextStyle(
                  fontSize: 16,
                  color: palette.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ];
    }

    final children = <Widget>[];

    if (_playlistSearchBusy && _query.isNotEmpty) {
      children.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: LinearProgressIndicator(
              minHeight: 3,
              borderRadius: BorderRadius.circular(99),
              color: palette.accent,
            ),
          ),
        ),
      );
    }

    if (playlists.isNotEmpty) {
      children.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Text(
              context.t('search.playlists'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: palette.textMuted,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      );
      children.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final p = playlists[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PublicPlaylistSearchTile(
                    item: p,
                    palette: palette,
                    audioPlayerService: widget.audioPlayerService,
                    onTap: () {
                      Navigator.of(context).push(
                        ShellMaterialPageRoute<void>(
                          builder: (_) => PlaylistDetailPage(
                            playlistId: RemotePlaylistsRepository.idForServer(p.id),
                            audioPlayerService: widget.audioPlayerService,
                            repository: widget.playlistsRepository,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
              childCount: playlists.length,
            ),
          ),
        ),
      );
    }

    if (albums.isNotEmpty) {
      children.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Text(
              context.t('search.albums'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: palette.textMuted,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      );
      children.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final release = albums[index];
                final originalIndex = _releases.indexOf(release);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _AlbumResultTile(
                    release: release,
                    palette: palette,
                    onTap: () => _onAlbumTap(
                      originalIndex >= 0 ? originalIndex : index,
                    ),
                  ),
                );
              },
              childCount: albums.length,
            ),
          ),
        ),
      );
    }

    if (tracks.isNotEmpty) {
      children.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, (albums.isNotEmpty || playlists.isNotEmpty) ? 12 : 8, 20, 8),
            child: Text(
              context.t('search.tracks'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: palette.textMuted,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      );
      children.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final track = tracks[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SearchTrackTile(
                    track: track,
                    palette: palette,
                    isDownloaded: widget.audioPlayerService.isTrackDownloaded(
                      AudioPlayerService.playablePath(track),
                    ),
                    onTap: () => _onTrackTap(track, tracks),
                  ),
                );
              },
              childCount: tracks.length,
            ),
          ),
        ),
      );
    } else if (albums.isNotEmpty) {
      children.add(
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      );
    }

    return children;
  }

  List<Widget> _buildPeopleResultsSlivers(AppColorPalette palette) {
    final q = _query.trim();
    if (q.length == 1) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 120),
            child: Center(
              child: Text(
                context.t('search.peopleMinChars'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: palette.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ];
    }
    final children = <Widget>[];
    if (_peopleSearchBusy && q.length >= 2) {
      children.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: LinearProgressIndicator(
              minHeight: 3,
              borderRadius: BorderRadius.circular(99),
              color: palette.accent,
            ),
          ),
        ),
      );
    }
    final users = q.length >= 2 ? _peopleResults : const <ListeningFriend>[];
    if (q.length >= 2 && !_peopleSearchBusy && users.isEmpty && _peopleSearchOnlySelf) {
      children.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 120),
            child: Center(
              child: Text(
                context.t('search.peopleSelfSnark'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.35,
                  color: palette.textSecondary,
                ),
              ),
            ),
          ),
        ),
      );
      return children;
    }
    if (q.length >= 2 && !_peopleSearchBusy && users.isEmpty) {
      children.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 120),
            child: Center(
              child: Text(
                context.t('search.usersNotFound'),
                style: TextStyle(
                  fontSize: 16,
                  color: palette.textSecondary,
                ),
              ),
            ),
          ),
        ),
      );
      return children;
    }
    if (users.isEmpty) {
      return children;
    }
    children.add(
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final friend = users[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _UserResultTile(
                  friend: friend,
                  palette: palette,
                  onTap: () {
                    Navigator.of(context).push(
                      ShellMaterialPageRoute<void>(
                        builder: (_) => ArtistPage(
                          artistName: friend.username,
                          coverImageUrl: friend.avatarUrl,
                          audioPlayerService: widget.audioPlayerService,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
            childCount: users.length,
          ),
        ),
      ),
    );
    return children;
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
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

class _AlbumResultTile extends StatelessWidget {
  const _AlbumResultTile({
    required this.release,
    required this.palette,
    required this.onTap,
  });

  final ReleaseItem release;
  final AppColorPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final coverPath = release.coverUrl;
    return Material(
      color: palette.cardBackground.withValues(alpha: 0.85),
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
                  width: 56,
                  height: 56,
                  child: coverPath != null
                      ? Image.asset(
                          coverPath,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _albumPlaceholder(palette),
                        )
                      : _albumPlaceholder(palette),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      release.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: palette.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      Localizations.localeOf(context).languageCode == 'en' ? 'Album · release' : 'Альбом · релиз',
                      style: TextStyle(
                        fontSize: 13,
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.play_circle_fill_rounded,
                color: palette.accent.withValues(alpha: 0.85),
                size: 32,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _albumPlaceholder(AppColorPalette palette) {
    return Container(
      color: palette.primaryDark.withValues(alpha: 0.45),
      alignment: Alignment.center,
      child: Icon(
        Icons.album_rounded,
        color: palette.textMuted,
        size: 28,
      ),
    );
  }
}

class _SearchTrackTile extends StatelessWidget {
  const _SearchTrackTile({
    required this.track,
    required this.palette,
    required this.isDownloaded,
    required this.onTap,
  });

  final Track track;
  final AppColorPalette palette;
  final bool isDownloaded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const coverSize = 56.0;
    final coverSource = track.coverBytes ?? track.coverFallbackPath;

    return Material(
      color: palette.cardBackground.withValues(alpha: 0.85),
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
                      track.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: palette.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isDownloaded) ...[
                      const SizedBox(height: 2),
                      Icon(
                        Icons.download_done_rounded,
                        size: 14,
                        color: palette.accent,
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      track.artistDisplay.isEmpty
                          ? context.t('common.unknownArtist')
                          : track.artistDisplay,
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
              Icon(
                Icons.play_arrow_rounded,
                color: palette.accent,
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PublicPlaylistSearchTile extends StatefulWidget {
  const _PublicPlaylistSearchTile({
    required this.item,
    required this.palette,
    required this.audioPlayerService,
    required this.onTap,
  });

  final PublicPlaylistItemRemote item;
  final AppColorPalette palette;
  final AudioPlayerService audioPlayerService;
  final VoidCallback onTap;

  @override
  State<_PublicPlaylistSearchTile> createState() => _PublicPlaylistSearchTileState();
}

class _PublicPlaylistSearchTileState extends State<_PublicPlaylistSearchTile> {
  late int _likesCount;
  bool _liked = false;
  bool _likeBusy = false;
  bool _canUseLike = false;

  @override
  void initState() {
    super.initState();
    _likesCount = widget.item.likesCount;
    _initLike();
  }

  Future<void> _initLike() async {
    final acc = await AuthSessionStore.readAccount();
    final ok = acc != null &&
        acc.sessionToken.trim().isNotEmpty &&
        acc.userId != null;
    if (!mounted) return;
    setState(() => _canUseLike = ok);
    if (!ok) return;
    try {
      final st = await PlaylistsApi().getPlaylistLike(widget.item.id);
      if (!mounted) return;
      setState(() {
        _liked = st.liked;
        _likesCount = st.likesCount;
      });
    } catch (_) {}
  }

  Future<void> _toggleLike() async {
    if (!_canUseLike || _likeBusy) return;
    setState(() => _likeBusy = true);
    try {
      final st = await PlaylistsApi().postPlaylistLike(widget.item.id);
      if (!mounted) return;
      setState(() {
        _liked = st.liked;
        _likesCount = st.likesCount;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Localizations.localeOf(context).languageCode == 'en'
                ? 'Could not update like'
                : 'Не удалось обновить лайк',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _likeBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final palette = widget.palette;
    final title = (item.title ?? '').trim().isEmpty ? '—' : item.title!.trim();
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    final sub = isEn
        ? '${item.trackCount} tracks · ♥ $_likesCount'
        : '${item.trackCount} треков · ♥ $_likesCount';
    final nick = (item.ownerNickname ?? '').trim();
    final authorLabel = nick.isNotEmpty ? '@$nick' : (isEn ? 'Author' : 'Автор');
    final coverUrl = playlistCoverUrl(item.id);
    final authorAvatar = userAvatarUrl(item.ownerUserId);
    final placeholder = Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: palette.primaryDark.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
      ),
      child: Icon(Icons.queue_music_rounded, color: palette.textMuted),
    );
    return Material(
      color: palette.cardBackground.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: buildTrackCover(
                    coverSource: coverUrl,
                    width: 56,
                    height: 56,
                    borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                    placeholder: placeholder,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: palette.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sub,
                      style: TextStyle(fontSize: 13, color: palette.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            ShellMaterialPageRoute<void>(
                              builder: (_) => ArtistPage(
                                artistName: nick.isNotEmpty ? nick : authorLabel,
                                coverImageUrl: authorAvatar,
                                audioPlayerService: widget.audioPlayerService,
                              ),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ClipOval(
                                child: Image.network(
                                  authorAvatar,
                                  width: 22,
                                  height: 22,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    width: 22,
                                    height: 22,
                                    color: palette.primaryDark.withValues(alpha: 0.5),
                                    alignment: Alignment.center,
                                    child: Icon(
                                      Icons.person_rounded,
                                      size: 14,
                                      color: palette.textMuted,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  authorLabel,
                                  style: TextStyle(
                                    fontSize: 13,
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
                ),
              ),
              if (_canUseLike)
                IconButton(
                  tooltip: isEn ? 'Like' : 'Лайк',
                  onPressed: _likeBusy ? null : _toggleLike,
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
                          _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: _liked ? palette.accent : palette.textMuted,
                        ),
                )
              else
                const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: palette.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeopleSearchAvatar extends StatelessWidget {
  const _PeopleSearchAvatar({
    required this.palette,
    required this.initial,
    required this.imageUrl,
  });

  final AppColorPalette palette;
  final String initial;
  final String? imageUrl;

  static const double _d = 56;

  Widget _fallback() {
    return CircleAvatar(
      radius: 28,
      backgroundColor: palette.accent.withValues(alpha: 0.25),
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: palette.textPrimary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    if (url == null || url.isEmpty) return _fallback();
    return ClipOval(
      child: Image.network(
        url,
        width: _d,
        height: _d,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallback(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return SizedBox(
            width: _d,
            height: _d,
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: palette.accent,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _UserResultTile extends StatelessWidget {
  const _UserResultTile({
    required this.friend,
    required this.palette,
    required this.onTap,
  });

  final ListeningFriend friend;
  final AppColorPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = friend.username;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Material(
      color: palette.cardBackground.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
              _PeopleSearchAvatar(
                palette: palette,
                initial: initial,
                imageUrl: friend.avatarUrl,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
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
                      Localizations.localeOf(context).languageCode == 'en' ? 'User' : 'Пользователь',
                      style: TextStyle(
                        fontSize: 13,
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: palette.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
