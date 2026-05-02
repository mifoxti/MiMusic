import 'dart:ui';
import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/audio/audio_player_service.dart';
import '../../core/audio/local_tracks.dart';
import '../../core/audio/track.dart';
import '../../core/constants/app_constants.dart';
import '../../core/player/player_dock_host.dart';
import '../../core/social/listening_room_session.dart';
import '../../core/theme/app_theme.dart';

enum _RoomType { private, open }

enum _PermissionMode { hostOnly, everyone }

class ListeningRoomPage extends StatefulWidget {
  const ListeningRoomPage({super.key, this.audioPlayerService});

  static const String routeName = 'mimusic_listening_room';
  final AudioPlayerService? audioPlayerService;

  @override
  State<ListeningRoomPage> createState() => _ListeningRoomPageState();
}

class _ListeningRoomPageState extends State<ListeningRoomPage> {
  _RoomType _roomType = _RoomType.private;
  _PermissionMode _pauseControl = _PermissionMode.hostOnly;
  _PermissionMode _seekControl = _PermissionMode.hostOnly;
  _PermissionMode _shuffleControl = _PermissionMode.hostOnly;
  _PermissionMode _repeatControl = _PermissionMode.hostOnly;
  _PermissionMode _skipControl = _PermissionMode.hostOnly;
  _PermissionMode _playlistControl = _PermissionMode.hostOnly;

  final Set<String> _selectedFriends = {'alexwave'};
  final Set<String> _selectedPlaylists = {'Night Drive'};
  final Set<String> _selectedTrackPaths = {};
  List<Track> _allTracks = const [];

  final List<String> _friends = const [
    'alexwave',
    'lofi_nora',
    'nightcore_anna',
    'dockfr10',
    'AzukiNHG',
  ];

  final List<String> _playlists = const [
    'Night Drive',
    'Lo-Fi Evening',
    'Future Bass Pulse',
    'Chill Vocals',
  ];

  @override
  void initState() {
    super.initState();
    _loadTracks();
  }

  Future<void> _loadTracks() async {
    final tracks = await loadLocalTracks();
    if (!mounted) return;
    setState(() {
      _allTracks = tracks;
      if (_selectedTrackPaths.isEmpty) {
        _selectedTrackPaths.addAll(tracks.take(5).map((e) => e.assetPath));
      }
    });
  }

  Future<void> _createRoom() async {
    final queue = _allTracks.where((e) => _selectedTrackPaths.contains(e.assetPath)).toList();
    final service = widget.audioPlayerService;
    ListeningRoomSession.instance.start(
      roomTitle: _roomType == _RoomType.private ? 'Private room' : 'Open room',
      listeners: ['mifoxti', ..._selectedFriends],
      hostUsername: 'mifoxti',
      currentUsername: 'mifoxti',
      privateRoom: _roomType == _RoomType.private,
      pauseHostOnly: _pauseControl == _PermissionMode.hostOnly,
      seekHostOnly: _seekControl == _PermissionMode.hostOnly,
      shuffleHostOnly: _shuffleControl == _PermissionMode.hostOnly,
      repeatHostOnly: _repeatControl == _PermissionMode.hostOnly,
      skipHostOnly: _skipControl == _PermissionMode.hostOnly,
      playlistHostOnly: _playlistControl == _PermissionMode.hostOnly,
      selectedPlaylists: _selectedPlaylists.toList(),
      queue: queue,
    );
    if (!mounted) return;
    Navigator.of(context).pop();
    PlayerDockHost.expand();
    if (service != null && queue.isNotEmpty) {
      unawaited(
        service.playTrack(
          queue.first,
          queue: queue,
          leaveListeningRoomSession: false,
        ),
      );
    }
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
                        onSelected: (_) => setState(() => _roomType = _RoomType.private),
                      ),
                      ChoiceChip(
                        label: Text(isEn ? 'Open (anyone can join)' : 'Открытая (вступает кто хочет)'),
                        selected: _roomType == _RoomType.open,
                        onSelected: (_) => setState(() => _roomType = _RoomType.open),
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
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _friends.map((friend) {
                      final selected = _selectedFriends.contains(friend);
                      return FilterChip(
                        label: Text('@$friend'),
                        selected: selected,
                        onSelected: (value) {
                          setState(() {
                            if (value) {
                              _selectedFriends.add(friend);
                            } else {
                              _selectedFriends.remove(friend);
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
                  const SizedBox(height: 8),
                  Text(
                    isEn ? 'Playlists:' : 'Плейлисты:',
                    style: TextStyle(color: palette.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _playlists.map((playlist) {
                      final selected = _selectedPlaylists.contains(playlist);
                      return FilterChip(
                        label: Text(playlist),
                        selected: selected,
                        onSelected: (value) {
                          setState(() {
                            if (value) {
                              _selectedPlaylists.add(playlist);
                            } else {
                              _selectedPlaylists.remove(playlist);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isEn ? 'Tracks:' : 'Треки:',
                    style: TextStyle(color: palette.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  if (_allTracks.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
                    ..._allTracks.take(10).map(
                      (track) {
                        final selected = _selectedTrackPaths.contains(track.assetPath);
                        return CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: selected,
                          title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
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
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _selectedTrackPaths.isEmpty ? null : _createRoom,
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
