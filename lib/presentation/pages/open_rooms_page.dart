import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/audio/audio_player_service.dart';
import '../../core/auth/auth_session_store.dart';
import '../../core/constants/app_constants.dart';
import '../../core/l10n/app_localization.dart';
import '../../core/network/colisten_api.dart';
import '../../core/player/player_dock_host.dart';
import '../../core/social/colisten_controller.dart';
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
      final list = await ColistenApi().fetchOpenRooms();
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
                ? Center(child: Text(_error!, style: TextStyle(color: palette.textSecondary)))
                : _rooms.isEmpty
                    ? Center(
                        child: Text(
                          isEn ? 'No open rooms' : 'Нет открытых комнат',
                          style: TextStyle(color: palette.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, AppConstants.shellBottomInset),
                        itemCount: _rooms.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final room = _rooms[index];
                          final title = (room.trackTitle ?? '—').trim();
                          final artist = (room.trackArtist ?? '').trim();
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
                                            '@${room.ownerNickname}',
                                            style: TextStyle(
                                              color: palette.textPrimary,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            artist.isEmpty ? title : '$artist — $title',
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
