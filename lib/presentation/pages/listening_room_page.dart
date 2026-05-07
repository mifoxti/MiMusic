import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/audio/audio_player_service.dart';
import '../../core/audio/track.dart';
import '../../core/auth/auth_session_store.dart';
import '../../core/constants/app_constants.dart';
import '../../core/l10n/app_localization.dart';
import '../../core/network/colisten_api.dart';
import '../../core/network/friends_api.dart';
import '../../core/network/tracks_api.dart';
import '../../core/player/player_dock_host.dart';
import '../../core/social/colisten_controller.dart';
import '../../core/social/listening_room_session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../features/playlists/data/repositories/session_aware_playlists_repository.dart';
import '../../features/playlists/domain/entities/playlist.dart';
import '../../features/playlists/domain/repositories/playlists_repository.dart';

enum _RoomType { private, open }

enum _PermissionMode { hostOnly, everyone }

class ListeningRoomPage extends StatefulWidget {
  const ListeningRoomPage({super.key, this.audioPlayerService});

  static const String routeName = 'mimusic_listening_room';
  final AudioPlayerService? audioPlayerService;

  @override
  State<ListeningRoomPage> createState() => _ListeningRoomPageState();
}

class _ListeningRoomPageState extends State<ListeningRoomPage>
    with TickerProviderStateMixin {
  _RoomType _roomType = _RoomType.private;
  _PermissionMode _pauseControl = _PermissionMode.hostOnly;
  _PermissionMode _seekControl = _PermissionMode.hostOnly;
  _PermissionMode _shuffleControl = _PermissionMode.hostOnly;
  _PermissionMode _repeatControl = _PermissionMode.hostOnly;
  _PermissionMode _skipControl = _PermissionMode.hostOnly;
  _PermissionMode _playlistControl = _PermissionMode.hostOnly;

  final Set<int> _selectedFriendIds = {};
  final Set<String> _selectedPlaylistIds = {};
  final Set<String> _selectedTrackPaths = {};
  List<Track> _allTracks = const [];
  List<Playlist> _playlists = const [];

  final PlaylistsRepository _playlistRepo = SessionAwarePlaylistsRepository();

  late final TabController _playlistTabController;
  late final TabController _trackTabController;

  void _tabIndexListener() {
    if (mounted) setState(() {});
  }

  String _trackSearchQuery = '';

  List<FriendRemoteDto> _serverFriends = const [];

  @override
  void initState() {
    super.initState();
    _playlistTabController = TabController(length: 2, vsync: this);
    _trackTabController = TabController(length: 2, vsync: this);
    _playlistTabController.addListener(_tabIndexListener);
    _trackTabController.addListener(_tabIndexListener);
    widget.audioPlayerService?.addListener(_onAudioServiceChanged);
    unawaited(_loadPlaylists());
    unawaited(_loadTracks());
    unawaited(_loadServerFriends());
  }

  Future<void> _loadServerFriends() async {
    try {
      final acc = await AuthSessionStore.readAccount();
      if (acc == null || acc.sessionToken.trim().isEmpty) return;
      final rows = await FriendsApi().fetchFriends();
      if (!mounted) return;
      setState(() => _serverFriends = rows);
    } catch (_) {}
  }

  @override
  void dispose() {
    _playlistTabController.removeListener(_tabIndexListener);
    _trackTabController.removeListener(_tabIndexListener);
    _playlistTabController.dispose();
    _trackTabController.dispose();
    widget.audioPlayerService?.removeListener(_onAudioServiceChanged);
    super.dispose();
  }

  void _onAudioServiceChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadPlaylists() async {
    final list = await _playlistRepo.getPlaylists();
    if (!mounted) return;
    setState(() {
      _playlists = list;
      _selectedPlaylistIds.removeWhere((id) => !list.any((p) => p.id == id));
    });
  }

  Future<void> _loadTracks() async {
    List<Track> tracks;
    try {
      final remote = await TracksApi().fetchTracks(limit: 200);
      tracks = remote
          .map(
            (e) => Track(
              assetPath: 'server_track_${e.id}',
              title: e.title.trim().isEmpty ? '—' : e.title.trim(),
              artist: e.artist,
              audioFilePath: e.streamUrl(),
              coverAssetPath: e.coverUrl(),
              coverBytes: e.coverBytes,
            ),
          )
          .toList();
    } catch (_) {
      tracks = const [];
    }
    if (!mounted) return;
    setState(() {
      _allTracks = tracks;
      if (_selectedTrackPaths.isEmpty) {
        final fav = _favoriteTracksList(tracks);
        if (fav.isNotEmpty) {
          _selectedTrackPaths.addAll(fav.take(5).map((e) => e.assetPath));
        } else {
          _selectedTrackPaths.addAll(tracks.take(5).map((e) => e.assetPath));
        }
        final cur = widget.audioPlayerService?.currentTrack;
        if (cur != null &&
            cur.audioFilePath == null &&
            tracks.any((t) => t.assetPath == cur.assetPath)) {
          _selectedTrackPaths.add(cur.assetPath);
        }
      }
    });
  }

  List<Playlist> get _myPlaylistsUnliked =>
      _playlists.where((p) => !p.isLiked).toList();

  List<Playlist> get _likedPlaylistsOnly =>
      _playlists.where((p) => p.isLiked).toList();

  List<Track> _favoriteTracksList([List<Track>? pool]) {
    final src = pool ?? _allTracks;
    final svc = widget.audioPlayerService;
    if (svc == null) return [];
    final liked = svc.likedPaths;
    return src.where((t) {
      final p = AudioPlayerService.playablePath(t);
      return liked.contains(p) || liked.contains(t.assetPath);
    }).toList();
  }

  List<Track> _searchTracksList() {
    final q = _trackSearchQuery.trim().toLowerCase();
    if (q.isEmpty) return List<Track>.from(_allTracks);
    return _allTracks.where((t) {
      return t.title.toLowerCase().contains(q) ||
          t.artistDisplay.toLowerCase().contains(q);
    }).toList();
  }

  List<Track> _visibleTracksForCurrentTab() {
    return _trackTabController.index == 0
        ? _favoriteTracksList()
        : _searchTracksList();
  }

  void _selectAllVisibleTracks() {
    final visible = _visibleTracksForCurrentTab();
    if (visible.isEmpty) return;
    setState(() {
      _selectedTrackPaths.addAll(visible.map((e) => e.assetPath));
    });
  }

  void _clearSelectionVisibleTracks() {
    final visible = _visibleTracksForCurrentTab().map((e) => e.assetPath).toSet();
    if (visible.isEmpty) return;
    setState(() {
      _selectedTrackPaths.removeWhere(visible.contains);
    });
  }

  /// Очередь комнаты: выбранные треки + текущий трек хоста (если его не выбрали вручную).
  List<Track> _queueTracksFromSelection() {
    final selected =
        _allTracks.where((e) => _selectedTrackPaths.contains(e.assetPath)).toList();
    final current = widget.audioPlayerService?.currentTrack;
    if (current == null) return selected;
    final exists = selected.any((t) => t.assetPath == current.assetPath);
    if (exists) return selected;
    return [current, ...selected];
  }

  Future<void> _createRoom() async {
    final queue = _queueTracksFromSelection();
    final service = widget.audioPlayerService;
    final acc = await AuthSessionStore.readAccount();
    if (acc == null || acc.sessionToken.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('friends.loginToFriend'))),
      );
      return;
    }
    final nick = acc.nickname.trim().isEmpty ? 'user' : acc.nickname;
    final queueTrackKeys = queue
        .map((t) => TracksApi().trackKeyForPaths(
              assetPath: t.assetPath,
              audioFilePath: t.audioFilePath,
            ))
        .toList();
    if (service != null && queue.isNotEmpty) {
      final current = service.currentTrack;
      final currentInQueue = current != null &&
          queue.any((t) => t.assetPath == current.assetPath);
      if (!currentInQueue) {
        await service.playTrack(
          queue.first,
          queue: queue,
          leaveListeningRoomSession: false,
        );
      } else {
        await service.replaceQueueFromRoomSync(queue);
      }
    }
    final current = service?.currentTrack;
    final tid = current == null
        ? null
        : TracksApi().resolveServerTrackId(
            assetPath: current.assetPath,
            audioFilePath: current.audioFilePath,
          );
    final trackKey = current == null
        ? null
        : TracksApi().trackKeyForPaths(
            assetPath: current.assetPath,
            audioFilePath: current.audioFilePath,
          );
    final pos = service == null ? 0.0 : service.position.inMilliseconds / 1000.0;
    final playing = service?.isPlaying ?? false;
    String roomId;
    try {
      roomId = await ColistenApi().createRoom(
        isOpen: _roomType == _RoomType.open,
        trackId: tid,
        trackKey: trackKey,
        queueTrackKeys: queueTrackKeys,
        positionSeconds: pos,
        playing: playing,
        controlPauseHostOnly: _pauseControl == _PermissionMode.hostOnly,
        controlSeekHostOnly: _seekControl == _PermissionMode.hostOnly,
        controlShuffleHostOnly: _shuffleControl == _PermissionMode.hostOnly,
        controlRepeatHostOnly: _repeatControl == _PermissionMode.hostOnly,
        controlSkipHostOnly: _skipControl == _PermissionMode.hostOnly,
        controlPlaylistHostOnly: _playlistControl == _PermissionMode.hostOnly,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('common.errorLoading'))),
      );
      return;
    }
    final playlistTitles = _playlists
        .where((p) => _selectedPlaylistIds.contains(p.id))
        .map((p) => p.title)
        .toList();
    final listeners = <String>[nick];
    ListeningRoomSession.instance.start(
      roomTitle: _roomType == _RoomType.private ? 'Private room' : 'Open room',
      listeners: listeners,
      hostUsername: nick,
      currentUsername: nick,
      privateRoom: _roomType == _RoomType.private,
      pauseHostOnly: _pauseControl == _PermissionMode.hostOnly,
      seekHostOnly: _seekControl == _PermissionMode.hostOnly,
      shuffleHostOnly: _shuffleControl == _PermissionMode.hostOnly,
      repeatHostOnly: _repeatControl == _PermissionMode.hostOnly,
      skipHostOnly: _skipControl == _PermissionMode.hostOnly,
      playlistHostOnly: _playlistControl == _PermissionMode.hostOnly,
      selectedPlaylists: playlistTitles,
      queue: queue,
    );
    if (service != null) {
      try {
        await ColistenController.instance.connectHost(roomId: roomId, audio: service);
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('common.errorLoading'))),
        );
      }
    }
    if (_selectedFriendIds.isNotEmpty) {
      try {
        await ColistenApi().inviteUsers(
          roomId: roomId,
          userIds: _selectedFriendIds.toList(),
        );
      } catch (_) {}
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    PlayerDockHost.expand();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    final isEn = Localizations.localeOf(context).languageCode == 'en';
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
          backgroundColor: Colors.transparent,
          foregroundColor: palette.textPrimary,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: () => Navigator.maybePop(context),
          ),
          title: Text(isEn ? 'Listening together' : 'Совместное прослушивание'),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _glassCard(
              context,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle(context, isEn ? '1. Room type' : '1. Тип комнаты'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text(isEn ? 'Private (friends only)' : 'Приватная (только друзья)'),
                        selected: _roomType == _RoomType.private,
                        onSelected: (v) {
                          if (v) setState(() => _roomType = _RoomType.private);
                        },
                      ),
                      ChoiceChip(
                        label: Text(isEn ? 'Open (anyone can join)' : 'Открытая (вступает кто хочет)'),
                        selected: _roomType == _RoomType.open,
                        onSelected: (v) {
                          if (v) setState(() => _roomType = _RoomType.open);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _glassCard(
              context,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle(context, isEn ? '2. Control permissions' : '2. Тип управления'),
                  const SizedBox(height: 10),
                  _permissionRow(
                    context,
                    label: isEn ? 'Pause / resume' : 'Пауза / продолжить',
                    value: _pauseControl,
                    onChanged: (v) => setState(() => _pauseControl = v),
                  ),
                  _permissionRow(
                    context,
                    label: isEn ? 'Seek progress bar' : 'Перемотка трека',
                    value: _seekControl,
                    onChanged: (v) => setState(() => _seekControl = v),
                  ),
                  _permissionRow(
                    context,
                    label: isEn ? 'Shuffle queue' : 'Перемешивание очереди',
                    value: _shuffleControl,
                    onChanged: (v) => setState(() => _shuffleControl = v),
                  ),
                  _permissionRow(
                    context,
                    label: isEn ? 'Repeat mode' : 'Режим повтора',
                    value: _repeatControl,
                    onChanged: (v) => setState(() => _repeatControl = v),
                  ),
                  _permissionRow(
                    context,
                    label: isEn ? 'Skip tracks' : 'Переключение треков',
                    value: _skipControl,
                    onChanged: (v) => setState(() => _skipControl = v),
                  ),
                  _permissionRow(
                    context,
                    label: isEn ? 'Edit playlist queue' : 'Редактирование очереди',
                    value: _playlistControl,
                    onChanged: (v) => setState(() => _playlistControl = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _glassCard(
              context,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle(context, isEn ? '3. Invite friends' : '3. Приглашение друзей'),
                  const SizedBox(height: 10),
                  _serverFriends.isEmpty
                      ? Text(
                          isEn ? 'Log in and add friends to invite them.' : 'Войдите и добавьте друзей для приглашений.',
                          style: TextStyle(color: palette.textSecondary, fontSize: 13),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _serverFriends.map((f) {
                            final selected = _selectedFriendIds.contains(f.id);
                            return FilterChip(
                              label: Text('@${f.username}'),
                              selected: selected,
                              onSelected: (value) {
                                setState(() {
                                  if (value) {
                                    _selectedFriendIds.add(f.id);
                                  } else {
                                    _selectedFriendIds.remove(f.id);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _glassCard(
              context,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle(context, isEn ? '4. Queue content' : '4. Наполнение очереди'),
                  const SizedBox(height: 10),
                  Text(
                    isEn ? 'Playlists' : 'Плейлисты',
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _studioStyleTabBar(
                    palette: palette,
                    controller: _playlistTabController,
                    tabs: [
                      Tab(text: context.t('listeningRoom.playlistTabMine')),
                      Tab(text: context.t('listeningRoom.playlistTabLiked')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 152,
                    child: TabBarView(
                      controller: _playlistTabController,
                      children: [
                        _buildPlaylistTabPage(
                          context,
                          palette,
                          isEn,
                          mineTab: true,
                        ),
                        _buildPlaylistTabPage(
                          context,
                          palette,
                          isEn,
                          mineTab: false,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    isEn ? 'Tracks' : 'Треки',
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _studioStyleTabBar(
                    palette: palette,
                    controller: _trackTabController,
                    tabs: [
                      Tab(text: context.t('listeningRoom.tracksTabFavorites')),
                      Tab(text: context.t('listeningRoom.tracksTabSearch')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 320,
                    child: TabBarView(
                      controller: _trackTabController,
                      children: [
                        _buildTracksFavoritesTab(context, palette, isEn),
                        _buildTracksSearchTab(context, palette, isEn),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _queueTracksFromSelection().isEmpty ? null : _createRoom,
              icon: const Icon(Icons.headphones_rounded),
              label: Text(isEn ? 'Create room and open player' : 'Создать комнату и открыть плеер'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Как на экране «Студия»: фон + индикатор вкладки.
  Widget _studioStyleTabBar({
    required AppColorPalette palette,
    required TabController controller,
    required List<Tab> tabs,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: palette.cardBackground.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: Border.all(
          color: palette.textPrimary.withValues(alpha: 0.12),
        ),
      ),
      child: TabBar(
        controller: controller,
        dividerColor: Colors.transparent,
        labelColor: palette.textPrimary,
        unselectedLabelColor: palette.textMuted,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: palette.accent.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge - 2),
        ),
        tabs: tabs,
      ),
    );
  }

  Widget _buildPlaylistTabPage(
    BuildContext context,
    AppColorPalette palette,
    bool isEn, {
    required bool mineTab,
  }) {
    if (_playlists.isEmpty) {
      return Center(
        child: Text(
          context.t('listeningRoom.playlistsSectionEmpty'),
          textAlign: TextAlign.center,
          style: TextStyle(color: palette.textMuted, fontSize: 13),
        ),
      );
    }
    final items = mineTab ? _myPlaylistsUnliked : _likedPlaylistsOnly;
    if (items.isEmpty) {
      return Center(
        child: Text(
          mineTab
              ? (isEn
                  ? 'All playlists are on the «Liked» tab, or create a new one.'
                  : 'Все плейлисты на вкладке «С лайком» или создайте новый.')
              : context.t('listeningRoom.likedPlaylistsHint'),
          textAlign: TextAlign.center,
          style: TextStyle(color: palette.textMuted, fontSize: 13),
        ),
      );
    }
    return SingleChildScrollView(
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items.map((playlist) {
          final selected = _selectedPlaylistIds.contains(playlist.id);
          return FilterChip(
            label: Text(
              playlist.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            selected: selected,
            onSelected: (value) {
              setState(() {
                if (value) {
                  _selectedPlaylistIds.add(playlist.id);
                } else {
                  _selectedPlaylistIds.remove(playlist.id);
                }
              });
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTracksFavoritesTab(
    BuildContext context,
    AppColorPalette palette,
    bool isEn,
  ) {
    if (_allTracks.isEmpty) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    final visible = _favoriteTracksList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: visible.isEmpty ? null : _selectAllVisibleTracks,
                child: Text(context.t('listeningRoom.selectAllTracks')),
              ),
            ),
            Expanded(
              child: TextButton(
                onPressed: visible.isEmpty ? null : _clearSelectionVisibleTracks,
                child: Text(context.t('listeningRoom.clearTrackSelection')),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Expanded(
          child: _buildTrackListBody(
            context,
            palette,
            isEn,
            tabIndex: 0,
            visible: visible,
          ),
        ),
      ],
    );
  }

  Widget _buildTracksSearchTab(
    BuildContext context,
    AppColorPalette palette,
    bool isEn,
  ) {
    if (_allTracks.isEmpty) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    final visible = _searchTracksList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          onChanged: (v) => setState(() => _trackSearchQuery = v),
          style: TextStyle(color: palette.textPrimary, fontSize: 15),
          decoration: InputDecoration(
            hintText: context.t('listeningRoom.searchTracksHint'),
            isDense: true,
            filled: true,
            fillColor: palette.cardBackground.withValues(alpha: 0.35),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: palette.textMuted.withValues(alpha: 0.35)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: palette.textMuted.withValues(alpha: 0.35)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: visible.isEmpty ? null : _selectAllVisibleTracks,
                child: Text(context.t('listeningRoom.selectAllTracks')),
              ),
            ),
            Expanded(
              child: TextButton(
                onPressed: visible.isEmpty ? null : _clearSelectionVisibleTracks,
                child: Text(context.t('listeningRoom.clearTrackSelection')),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Expanded(
          child: _buildTrackListBody(
            context,
            palette,
            isEn,
            tabIndex: 1,
            visible: visible,
          ),
        ),
      ],
    );
  }

  Widget _buildTrackListBody(
    BuildContext context,
    AppColorPalette palette,
    bool isEn, {
    required int tabIndex,
    required List<Track> visible,
  }) {
    if (tabIndex == 0 && visible.isEmpty) {
      return Center(
        child: Text(
          context.t('listeningRoom.favoriteTracksEmpty'),
          textAlign: TextAlign.center,
          style: TextStyle(color: palette.textSecondary, fontSize: 14),
        ),
      );
    }
    if (tabIndex == 1 &&
        _trackSearchQuery.trim().isNotEmpty &&
        visible.isEmpty) {
      return Center(
        child: Text(
          isEn ? 'Nothing matches your search' : 'Ничего не найдено',
          style: TextStyle(color: palette.textSecondary, fontSize: 14),
        ),
      );
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: visible.length,
      itemBuilder: (context, index) {
        final track = visible[index];
        final selected = _selectedTrackPaths.contains(track.assetPath);
        return CheckboxListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          value: selected,
          title: Text(
            track.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            track.artistDisplay,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onChanged: (value) {
            setState(() {
              if (value ?? false) {
                _selectedTrackPaths.add(track.assetPath);
              } else {
                _selectedTrackPaths.remove(track.assetPath);
              }
            });
          },
        );
      },
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    final palette = AppPaletteExtension.of(context).palette;
    return Text(
      text,
      style: TextStyle(
        color: palette.textPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 15,
      ),
    );
  }

  Widget _permissionRow(
    BuildContext context, {
    required String label,
    required _PermissionMode value,
    required ValueChanged<_PermissionMode> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          SegmentedButton<_PermissionMode>(
            segments: const [
              ButtonSegment(
                value: _PermissionMode.hostOnly,
                label: Text('Host'),
              ),
              ButtonSegment(
                value: _PermissionMode.everyone,
                label: Text('All'),
              ),
            ],
            selected: {value},
            onSelectionChanged: (v) => onChanged(v.first),
          ),
        ],
      ),
    );
  }

  Widget _glassCard(BuildContext context, {required Widget child}) {
    final palette = AppPaletteExtension.of(context).palette;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.cardBackground.withValues(alpha: 0.46),
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
            border: Border.all(
              color: palette.textPrimary.withValues(alpha: 0.14),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
