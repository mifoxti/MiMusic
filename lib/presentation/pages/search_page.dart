import 'package:flutter/material.dart';

import '../../core/audio/audio_player_service.dart';
import '../../core/audio/local_tracks.dart';
import '../../core/audio/track.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/track_cover.dart';
import '../../features/home/domain/entities/listening_friend.dart';
import '../../features/home/domain/entities/release_item.dart';
import '../../features/home/domain/use_cases/get_home_section_use_case.dart';
import '../../features/player/presentation/pages/full_player_page.dart';

/// Режим поиска: музыка (треки + релизы как альбомы) или пользователи.
enum _SearchMode { music, people }

/// Вкладка «Поиск»: переключатель музыка / люди, поле ввода, результаты в стиле приложения.
class SearchPage extends StatefulWidget {
  const SearchPage({
    super.key,
    required this.audioPlayerService,
    required this.getHomeSectionUseCase,
  });

  final AudioPlayerService audioPlayerService;
  final GetHomeSectionUseCase getHomeSectionUseCase;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _queryController = TextEditingController();
  _SearchMode _mode = _SearchMode.music;

  List<Track> _allTracks = [];
  List<ReleaseItem> _releases = [];
  List<ListeningFriend> _friends = [];
  List<String> _suggestionArtists = [];
  bool _loading = true;

  bool _isFullPlayerOpen = false;

  @override
  void initState() {
    super.initState();
    _load();
    _queryController.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _queryController.removeListener(_onQueryChanged);
    _queryController.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    setState(() {});
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
        _friends = section.listeningFriends;
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

  List<ListeningFriend> get _filteredFriends {
    final q = _query.toLowerCase();
    if (q.isEmpty) return [];
    return _friends
        .where((f) => f.username.toLowerCase().contains(q))
        .toList();
  }

  void _openFullPlayer() {
    if (_isFullPlayerOpen) return;
    _isFullPlayerOpen = true;
    Navigator.of(context)
        .push(
      PageRouteBuilder<void>(
        settings: const RouteSettings(name: FullPlayerPage.routeName),
        pageBuilder: (context, animation, secondaryAnimation) => FullPlayerPage(
          audioPlayerService: widget.audioPlayerService,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.1),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 380),
      ),
    )
        .whenComplete(() {
      if (!mounted) {
        _isFullPlayerOpen = false;
        return;
      }
      setState(() => _isFullPlayerOpen = false);
    });
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
                          'Поиск',
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
                              ? 'Треки, альбомы и исполнители'
                              : 'Пользователи MiMusic',
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
                                ? 'Название, автор, альбом…'
                                : 'Никнейм…',
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
                            'Часто ищут',
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
                                ? 'Введите запрос, чтобы найти треки и релизы'
                                : 'Введите ник, чтобы найти пользователя',
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
              label: 'Музыка',
              icon: Icons.library_music_rounded,
              selected: _mode == _SearchMode.music,
              palette: palette,
              isDark: isDark,
              onTap: () => setState(() => _mode = _SearchMode.music),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _ModeChip(
              label: 'Люди',
              icon: Icons.person_search_rounded,
              selected: _mode == _SearchMode.people,
              palette: palette,
              isDark: isDark,
              onTap: () => setState(() => _mode = _SearchMode.people),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMusicResultsSlivers(AppColorPalette palette) {
    final albums = _filteredAlbums;
    final tracks = _filteredTracks;
    if (albums.isEmpty && tracks.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 120),
            child: Center(
              child: Text(
                'Ничего не найдено',
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

    if (albums.isNotEmpty) {
      children.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Text(
              'Альбомы и релизы',
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
            padding: EdgeInsets.fromLTRB(20, albums.isNotEmpty ? 12 : 8, 20, 8),
            child: Text(
              'Треки',
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
    final users = _filteredFriends;
    if (users.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 120),
            child: Center(
              child: Text(
                'Пользователи не найдены',
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
    return [
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Профиль ${friend.username} — скоро',
                        ),
                        behavior: SnackBarBehavior.floating,
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
    ];
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
                      'Альбом · релиз',
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
    required this.onTap,
  });

  final Track track;
  final AppColorPalette palette;
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
                    const SizedBox(height: 2),
                    Text(
                      track.artistDisplay.isEmpty
                          ? 'Неизвестный исполнитель'
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
              CircleAvatar(
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
                      'Пользователь',
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
