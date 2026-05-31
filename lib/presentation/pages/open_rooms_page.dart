import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/audio/audio_player_service.dart';
import '../../core/auth/auth_session_store.dart';
import '../../core/constants/app_constants.dart';
import '../../core/l10n/app_localization.dart';
import '../../core/network/api_config.dart';
import '../../core/network/colisten_api.dart';
import '../../core/network/playlists_api.dart';
import '../../core/player/player_dock_host.dart';
import '../../core/social/colisten_controller.dart';
import '../../core/social/listening_room_session.dart';
import '../../core/theme/app_theme.dart';
import '../../features/home/domain/entities/listening_friend.dart';
import '../widgets/colisten_listening_card.dart';

class OpenRoomsPage extends StatefulWidget {
  const OpenRoomsPage({
    super.key,
    required this.currentUsername,
    required this.audioPlayerService,
  });

  final String currentUsername;
  final AudioPlayerService audioPlayerService;

  @override
  State<OpenRoomsPage> createState() => _OpenRoomsPageState();
}

class _OpenRoomsPageState extends State<OpenRoomsPage> {
  bool _loading = true;
  String? _error;
  List<OpenColistenRoomDto> _rooms = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = _dedupeOpenRooms(await ColistenApi().fetchOpenRooms());
      list.sort((a, b) => b.listenersCount.compareTo(a.listenersCount));
      if (!mounted) return;
      setState(() {
        _rooms = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = context.t('common.errorLoading');
        _loading = false;
      });
    }
  }

  Future<void> _connectToRoom(OpenColistenRoomDto room) async {
    final acc = await AuthSessionStore.readAccount();
    if (acc == null || acc.sessionToken.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('friends.loginToFriend'))),
      );
      return;
    }
    try {
      ListeningRoomSession.instance.start(
        roomTitle: '@${room.ownerNickname}',
        listeners: [widget.currentUsername, room.ownerNickname],
        hostUsername: room.ownerNickname,
        currentUsername: widget.currentUsername,
        privateRoom: false,
        pauseHostOnly: true,
        seekHostOnly: true,
        shuffleHostOnly: true,
        repeatHostOnly: true,
        skipHostOnly: true,
        playlistHostOnly: true,
        selectedPlaylists: const [],
        queue: const [],
      );
      await ColistenController.instance.connectGuest(
        roomId: room.roomId,
        audio: widget.audioPlayerService,
      );
      PlayerDockHost.expand();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('common.errorLoading'))),
      );
    }
  }

  List<OpenColistenRoomDto> _dedupeOpenRooms(List<OpenColistenRoomDto> raw) {
    final byRoomId = <String, OpenColistenRoomDto>{};
    for (final room in raw) {
      final id = room.roomId.trim();
      if (id.isEmpty) continue;
      byRoomId[id] = room;
    }
    final byOwner = <int, OpenColistenRoomDto>{};
    for (final room in byRoomId.values) {
      final existing = byOwner[room.ownerId];
      if (existing == null ||
          room.listenersCount > existing.listenersCount ||
          (room.listenersCount == existing.listenersCount &&
              room.wallClockMs > existing.wallClockMs)) {
        byOwner[room.ownerId] = room;
      }
    }
    return byOwner.values.toList(growable: false);
  }

  String? _coverUrlForTrack(int? trackId) {
    if (trackId == null) return null;
    final base = ApiConfig.baseUrl.replaceAll(RegExp(r'/+$'), '');
    return '$base/tracks/$trackId/cover';
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
          colors: [palette.gradientStart, palette.gradientMiddle, palette.gradientEnd],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text(isEn ? 'Open rooms' : 'Открытые комнаты'),
          actions: [
            IconButton(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: _loading
            ? Center(child: CircularProgressIndicator(color: palette.accent))
            : _error != null
                ? Center(
                    child: Text(
                      _error!,
                      style: TextStyle(color: palette.textSecondary),
                    ),
                  )
                : _rooms.isEmpty
                    ? Center(
                        child: Text(
                          isEn ? 'No open rooms' : 'Нет открытых комнат',
                          style: TextStyle(color: palette.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          16,
                          12,
                          16,
                          AppConstants.shellBottomInset,
                        ),
                        itemCount: _rooms.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final room = _rooms[index];
                          final title = (room.trackTitle ?? '—').trim();
                          final artist = (room.trackArtist ?? '').trim();
                          return ColistenListeningCard(
                            title: title,
                            artistName: artist,
                            coverUrl: _coverUrlForTrack(room.trackId),
                            listeners: [
                              ListeningFriend(
                                username: '@${room.ownerNickname}',
                                avatarUrl: userAvatarUrl(room.ownerId),
                                userId: room.ownerId,
                              ),
                            ],
                            listenerCount: room.listenersCount,
                            positionSeconds: room.positionSeconds,
                            durationSeconds: room.durationSeconds,
                            playing: room.playing,
                            wallClockMs: room.wallClockMs,
                            onTap: () => _connectToRoom(room),
                          );
                        },
                      ),
      ),
    );
  }
}
