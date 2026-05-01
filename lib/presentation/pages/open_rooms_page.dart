import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/audio/audio_player_service.dart';
import '../../core/audio/local_tracks.dart';
import '../../core/audio/track.dart';
import '../../core/constants/app_constants.dart';
import '../../core/player/player_dock_host.dart';
import '../../core/social/listening_room_session.dart';
import '../../core/theme/app_theme.dart';

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
  final List<_OpenRoomVm> _rooms = const [
    _OpenRoomVm(
      id: 'room-alex',
      hostUsername: 'alexwave',
      trackTitle: 'Fragments',
      trackArtist: 'Rivora',
      listenersCount: 12,
    ),
    _OpenRoomVm(
      id: 'room-nora',
      hostUsername: 'lofi_nora',
      trackTitle: 'Night Walk',
      trackArtist: 'Mira K',
      listenersCount: 8,
    ),
    _OpenRoomVm(
      id: 'room-dock',
      hostUsername: 'dockfr10',
      trackTitle: 'Sea Lights',
      trackArtist: 'Astra',
      listenersCount: 5,
    ),
  ];

  Future<void> _connectToRoom(_OpenRoomVm room) async {
    final tracks = await loadLocalTracks();
    if (!mounted) return;

    final title = room.trackTitle.trim().toLowerCase();
    final artist = room.trackArtist.trim().toLowerCase();

    final exact = tracks.where((t) {
      return t.title.trim().toLowerCase() == title &&
          t.artistDisplay.trim().toLowerCase() == artist;
    }).toList();
    final byTitle = tracks.where((t) => t.title.trim().toLowerCase() == title).toList();
    final List<Track> queue = exact.isNotEmpty
        ? exact
        : (byTitle.isNotEmpty ? byTitle : (tracks.isNotEmpty ? <Track>[tracks.first] : <Track>[]));

    final listeners = <String>[widget.currentUsername, room.hostUsername];
    final extra = (room.listenersCount - listeners.length).clamp(0, 100);
    for (var i = 0; i < extra; i++) {
      listeners.add('listener_${room.id}_$i');
    }

    ListeningRoomSession.instance.start(
      roomTitle: '@${room.hostUsername}',
      listeners: listeners,
      hostUsername: room.hostUsername,
      currentUsername: widget.currentUsername,
      privateRoom: false,
      pauseHostOnly: true,
      seekHostOnly: true,
      shuffleHostOnly: true,
      repeatHostOnly: true,
      skipHostOnly: true,
      playlistHostOnly: true,
      selectedPlaylists: const [],
      queue: queue,
    );
    PlayerDockHost.expand();
    if (queue.isNotEmpty) {
      await widget.audioPlayerService.playTrack(queue.first, queue: queue);
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
          colors: [palette.gradientStart, palette.gradientMiddle, palette.gradientEnd],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text(isEn ? 'Open rooms' : 'Открытые комнаты'),
        ),
        body: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, AppConstants.shellBottomInset),
          itemCount: _rooms.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final room = _rooms[index];
            return ClipRRect(
              borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: palette.cardBackground.withValues(alpha: 0.42),
                    borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
                    border: Border.all(color: palette.textPrimary.withValues(alpha: 0.14)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: palette.accent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                        ),
                        alignment: Alignment.center,
                        child: Icon(Icons.groups_rounded, color: palette.accent),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '@${room.hostUsername}',
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${room.trackArtist} - ${room.trackTitle}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: palette.textSecondary, fontSize: 13),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isEn
                                  ? '${room.listenersCount} listening'
                                  : 'Слушают: ${room.listenersCount}',
                              style: TextStyle(color: palette.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      FilledButton(
                        onPressed: () => _connectToRoom(room),
                        child: Text(isEn ? 'Join' : 'Подключиться'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OpenRoomVm {
  const _OpenRoomVm({
    required this.id,
    required this.hostUsername,
    required this.trackTitle,
    required this.trackArtist,
    required this.listenersCount,
  });

  final String id;
  final String hostUsername;
  final String trackTitle;
  final String trackArtist;
  final int listenersCount;
}
