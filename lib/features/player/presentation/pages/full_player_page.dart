import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../core/audio/audio_player_service.dart';
import '../../../../core/audio/track.dart';
import '../../../../core/offline/download_feedback.dart';
import '../../../../core/l10n/app_localization.dart';
import '../../../../core/network/playlists_api.dart';
import '../../../../core/network/server_connectivity.dart';
import '../../../../core/network/tracks_api.dart';
import '../../../../core/social/colisten_controller.dart';
import '../../../../core/social/listening_room_session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_glass.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/player/full_player_visibility.dart';
import '../../../../core/player/player_cover_glass_colors.dart';
import '../../../../core/player/player_cover_palette_service.dart';
import '../../../../core/player/player_dock_host.dart';
import '../../../../core/player/shell_route_back_guard.dart';
import '../../../../core/widgets/track_cover.dart';
import '../../../playlists/domain/entities/playlist.dart';
import '../../../playlists/domain/repositories/playlists_repository.dart';
import '../../../../presentation/widgets/artist_names_text.dart';
import '../../../../presentation/pages/listening_room_page.dart';
import '../widgets/full_player_track_menu.dart';

/// Контент полного плеера. Полупрозрачное стекло — у родителя ([ExpandablePlayerDock] / мини-плеер).
class FullPlayerDockPanel extends StatelessWidget {
  const FullPlayerDockPanel({
    super.key,
    required this.audioPlayerService,
    this.playerCoverPalette,
    required this.onCollapse,
    required this.playlistsRepository,
  });

  final AudioPlayerService audioPlayerService;
  final PlayerCoverPaletteService? playerCoverPalette;
  final VoidCallback onCollapse;
  final PlaylistsRepository playlistsRepository;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;

    return SafeArea(
      child: ListenableBuilder(
        listenable: Listenable.merge([
          audioPlayerService,
          ListeningRoomSession.instance,
          ?playerCoverPalette,
        ]),
        builder: (context, _) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final coverColors =
              playerCoverPalette?.colors ?? PlayerCoverGlassColors.fallback;
          final track = audioPlayerService.currentTrack;
          final position = audioPlayerService.position;
          final duration = audioPlayerService.duration ?? Duration.zero;
          final isPlaying = audioPlayerService.isPlaying;
          final path = audioPlayerService.currentPlayablePath ?? '';
          final liked = path.isNotEmpty && audioPlayerService.isPathLiked(path);
          final disliked =
              path.isNotEmpty && audioPlayerService.isPathDisliked(path);
          final shuffleOn = audioPlayerService.shuffleEnabled;
          final loop = audioPlayerService.loopMode;
          final multiQueue = audioPlayerService.hasMultiTrackQueue;
          final roomSession = ListeningRoomSession.instance;
          final roomActive = roomSession.active;
          final roomJoining = roomSession.joining;
          final guestMode = roomActive && !roomSession.isHost;
          final roomAccent = guestMode
              ? const Color(0xFFC084FC)
              : const Color(0xFF5FD1FF);
          final guestEnabledColor = guestMode
              ? const Color(0xFFE9D5FF)
              : palette.textSecondary;
          final guestDisabledColor = guestMode
              ? const Color(0xFF21132F)
              : palette.textMuted.withValues(alpha: 0.35);
          final guestControlSurface = guestMode
              ? const Color(0xFF3B1A57).withValues(alpha: 0.82)
              : Colors.white.withValues(alpha: 0.18);
          final trackAccent =
              roomActive ? roomAccent : coverColors.contrastAccent(isDark);
          final trackTitleAccent = roomActive
              ? palette.textPrimary
              : coverColors.titleAccent(isDark);
          final trackAccentSoft = roomActive
              ? roomAccent.withValues(alpha: 0.82)
              : coverColors.contrastAccentSoft(isDark);
          final trackAccentMuted = roomActive
              ? roomAccent.withValues(alpha: 0.72)
              : coverColors.contrastAccentMuted(isDark);
          if (track == null) {
            return Center(
              child: Text(
                context.t('player.nothingPlaying'),
                style: TextStyle(color: palette.textSecondary, fontSize: 16),
              ),
            );
          }
          final trackKey = track.assetPath;
          final downloading = audioPlayerService.isTrackDownloading(trackKey);
          final downloaded = audioPlayerService.isTrackDownloaded(trackKey);

          final clampedPosition = position.inMilliseconds.clamp(
            0,
            duration.inMilliseconds == 0 ? 0 : duration.inMilliseconds,
          );
          final sliderMax = duration.inMilliseconds == 0
              ? 1.0
              : duration.inMilliseconds.toDouble();
          final sliderValue = duration.inMilliseconds == 0
              ? 0.0
              : clampedPosition.toDouble();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      color: palette.textPrimary,
                      iconSize: 30,
                      onPressed: onCollapse,
                    ),
                    const Spacer(),
                    if (roomActive)
                      IconButton(
                        icon: const Icon(Icons.stop_rounded),
                        color: roomAccent,
                        tooltip:
                            Localizations.localeOf(context).languageCode == 'en'
                            ? 'Leave room'
                            : 'Покинуть комнату',
                        onPressed: () => roomSession.end(),
                      ),
                    IconButton(
                      icon: const Icon(Icons.queue_music_rounded),
                      color: roomActive ? roomAccent : trackAccentSoft,
                      tooltip:
                          Localizations.localeOf(context).languageCode == 'en'
                          ? 'Queue'
                          : 'Очередь',
                      onPressed: () {
                        _showPlayerQueueSheet(
                          context: context,
                          palette: palette,
                          audioPlayerService: audioPlayerService,
                          roomSession: roomSession,
                          roomActive: roomActive,
                          currentTrack: track,
                          playlistsRepository: playlistsRepository,
                        );
                      },
                    ),
                    IconButton(
                      icon: downloading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              downloaded
                                  ? Icons.download_done_rounded
                                  : Icons.download_rounded,
                            ),
                      color: roomActive ? roomAccent : trackAccentSoft,
                      tooltip:
                          Localizations.localeOf(context).languageCode == 'en'
                          ? (downloaded ? 'Cached' : 'Download track')
                          : (downloaded ? 'Закешировано' : 'Скачать трек'),
                      onPressed: downloading || downloaded
                          ? null
                          : () async {
                              if (!await ServerConnectivity.instance
                                  .ensureOnline(context)) {
                                return;
                              }
                              final result =
                                  await audioPlayerService.downloadTrack(track);
                              if (!context.mounted) return;
                              showTrackDownloadSnackBar(context, result);
                            },
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_vert_rounded),
                      color: roomActive ? roomAccent : trackAccentSoft,
                      onPressed: () => showFullPlayerTrackMenu(
                        context,
                        audioPlayerService: audioPlayerService,
                        playlistsRepository: playlistsRepository,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    children: [
                      Hero(
                        tag: 'mimusic_player_cover',
                        child: buildTrackCover(
                          coverSource:
                              track.coverBytes ?? track.coverFallbackPath,
                          width: 260,
                          height: 260,
                          borderRadius: BorderRadius.circular(32),
                          placeholder: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(32),
                              color: trackAccent.withValues(alpha: 0.9),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.music_note_rounded,
                              size: 56,
                              color: Colors.white.withValues(alpha: 0.95),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Column(
                          children: [
                            Text(
                              track.title,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                                height: 1.12,
                                color: trackTitleAccent,
                                shadows: roomActive
                                    ? null
                                    : [
                                        Shadow(
                                          color: trackTitleAccent.withValues(
                                            alpha: isDark ? 0.35 : 0.2,
                                          ),
                                          blurRadius: 12,
                                        ),
                                      ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: track.artistDisplay.trim().isEmpty
                                  ? Text(
                                      context.t('common.notSpecifiedArtist'),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: palette.textMuted,
                                      ),
                                    )
                                  : ArtistNamesText(
                                      artistsText: track.artistDisplay,
                                      textAlign: TextAlign.center,
                                      audioPlayerService: audioPlayerService,
                                      onBeforeNavigate: PlayerDockHost.collapse,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: trackAccent,
                                      ),
                                    ),
                            ),
                            const SizedBox(height: 24),
                            _PlayerSeekBar(
                              audioPlayerService: audioPlayerService,
                              accentColor: trackAccent,
                              timeLabelColor: trackAccentMuted,
                              disabledColor: guestDisabledColor,
                              enabled:
                                  !roomActive || roomSession.canControlSeek,
                              clampedPositionMs: clampedPosition,
                              duration: duration,
                              sliderMax: sliderMax,
                              sliderValueFromService: sliderValue.clamp(
                                0.0,
                                sliderMax,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _RoundIconButton(
                                  icon: Icons.skip_previous_rounded,
                                  onPressed:
                                      roomActive && !roomSession.canControlSkip
                                      ? null
                                      : audioPlayerService.skipToPrevious,
                                  foregroundColor: roomActive
                                      ? guestEnabledColor
                                      : trackAccent,
                                  disabledColor: guestDisabledColor,
                                  backgroundColor: guestControlSurface,
                                ),
                                const SizedBox(width: 20),
                                _PlayPauseButton(
                                  isPlaying: isPlaying,
                                  onPressed:
                                      roomActive && !roomSession.canControlPause
                                      ? null
                                      : audioPlayerService.togglePlayPause,
                                  iconOverride: null,
                                  foregroundColor: trackAccent,
                                  disabledColor: guestDisabledColor,
                                ),
                                const SizedBox(width: 20),
                                _RoundIconButton(
                                  icon: Icons.skip_next_rounded,
                                  onPressed:
                                      roomActive && !roomSession.canControlSkip
                                      ? null
                                      : audioPlayerService.skipToNext,
                                  foregroundColor: roomActive
                                      ? guestEnabledColor
                                      : trackAccent,
                                  disabledColor: guestDisabledColor,
                                  backgroundColor: guestControlSurface,
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            if (roomActive) ...[
                              if (roomJoining) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: palette.primaryDark.withValues(
                                      alpha: 0.28,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: palette.textPrimary.withValues(
                                        alpha: 0.2,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: roomAccent,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          Localizations.localeOf(
                                                    context,
                                                  ).languageCode ==
                                                  'en'
                                              ? 'Connecting to room...'
                                              : 'Подключение к комнате...',
                                          style: TextStyle(
                                            color: palette.textPrimary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: trackAccent.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: trackAccent.withValues(alpha: 0.45),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.groups_rounded,
                                      color: trackAccent,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        Localizations.localeOf(
                                                  context,
                                                ).languageCode ==
                                                'en'
                                            ? 'Room active: ${roomSession.listenersCount} listeners'
                                            : 'Комната активна: ${roomSession.listenersCount} слушают',
                                        style: TextStyle(
                                          color: palette.textPrimary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    if (roomSession.isHost)
                                      IconButton(
                                        tooltip:
                                            Localizations.localeOf(
                                                  context,
                                                ).languageCode ==
                                                'en'
                                            ? 'Room settings'
                                            : 'Настройки комнаты',
                                        icon: const Icon(
                                          Icons.settings_rounded,
                                        ),
                                        color: trackAccent,
                                        onPressed: () {
                                          _showRoomManageSheet(
                                            context: context,
                                            palette: palette,
                                            audioPlayerService:
                                                audioPlayerService,
                                            roomSession: roomSession,
                                            initialView:
                                                _RoomManageView.settings,
                                          );
                                        },
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            if (!roomActive)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: _ListenTogetherGlassButton(
                                  label: context.t('player.listenTogether'),
                                  accentColor: trackAccent,
                                  isDark: isDark,
                                  onPressed: () {
                                    if (FullPlayerVisibility.open.value) {
                                      PlayerDockHost.collapse();
                                    }
                                    Navigator.of(context).push(
                                      ShellMaterialPageRoute<void>(
                                        settings: const RouteSettings(
                                          name: ListeningRoomPage.routeName,
                                        ),
                                        builder: (_) => ListeningRoomPage(
                                          audioPlayerService:
                                              audioPlayerService,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            const SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Center(
                                      child: _LikeCircle(
                                        icon: disliked
                                            ? Icons.thumb_down_rounded
                                            : Icons.thumb_down_off_alt_rounded,
                                        filled: disliked,
                                        onPressed: () => audioPlayerService
                                            .toggleDislikeCurrent(),
                                        palette: palette,
                                        accentWhenOn: guestMode
                                            ? guestEnabledColor
                                            : trackAccentSoft,
                                        backgroundColor: guestMode
                                            ? guestControlSurface
                                            : null,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Center(
                                      child: _RepeatGlyph(
                                        mode: loop,
                                        onPressed:
                                            roomActive &&
                                                !roomSession.canControlRepeat
                                            ? null
                                            : () => audioPlayerService
                                                  .cycleLoopMode(),
                                        palette: palette,
                                        accentColor: roomActive
                                            ? roomAccent
                                            : (loop != LoopMode.off
                                                  ? trackAccent
                                                  : trackAccentSoft),
                                        disabledColor: guestDisabledColor,
                                        backgroundColor: guestControlSurface,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Center(
                                      child: _TransportGlyph(
                                        icon: Icons.shuffle_rounded,
                                        active: shuffleOn,
                                        enabled:
                                            multiQueue &&
                                            (!roomActive ||
                                                roomSession.canControlShuffle),
                                        onPressed:
                                            multiQueue &&
                                                (!roomActive ||
                                                    roomSession
                                                        .canControlShuffle)
                                            ? () => audioPlayerService
                                                  .toggleShuffle()
                                            : null,
                                        palette: palette,
                                        accentColor: roomActive
                                            ? roomAccent
                                            : (shuffleOn
                                                  ? trackAccent
                                                  : trackAccentSoft),
                                        disabledColor: guestDisabledColor,
                                        backgroundColor: guestControlSurface,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Center(
                                      child: _LikeCircle(
                                        icon: liked
                                            ? Icons.favorite_rounded
                                            : Icons.favorite_border_rounded,
                                        filled: liked,
                                        onPressed: () =>
                                            audioPlayerService.toggleLike(),
                                        palette: palette,
                                        accentWhenOn: trackAccent,
                                        backgroundColor: guestMode
                                            ? guestControlSurface
                                            : null,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

void _showPlayerQueueSheet({
  required BuildContext context,
  required AppColorPalette palette,
  required AudioPlayerService audioPlayerService,
  required ListeningRoomSession roomSession,
  required bool roomActive,
  required Track currentTrack,
  required PlaylistsRepository playlistsRepository,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.78,
            ),
            decoration: BoxDecoration(
              color: palette.cardBackground.withValues(alpha: 0.72),
              border: Border.all(
                color: palette.textPrimary.withValues(alpha: 0.12),
              ),
            ),
            child: ListenableBuilder(
              listenable: Listenable.merge([
                audioPlayerService,
                if (roomActive) roomSession,
              ]),
              builder: (context, _) {
                final queue = audioPlayerService.activeQueue;
                final canEditQueue = roomActive
                    ? roomSession.canEditQueue
                    : true;
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              Localizations.localeOf(context).languageCode ==
                                      'en'
                                  ? 'Playback queue'
                                  : 'Очередь воспроизведения',
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip:
                                Localizations.localeOf(context).languageCode ==
                                    'en'
                                ? 'Add track'
                                : 'Добавить трек',
                            icon: const Icon(Icons.add_rounded),
                            onPressed: canEditQueue
                                ? () => _showAddTrackToQueueSheet(
                                    context: context,
                                    palette: palette,
                                    audioPlayerService: audioPlayerService,
                                    roomSession: roomSession,
                                    roomActive: roomActive,
                                    playlistsRepository: playlistsRepository,
                                  )
                                : null,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: queue.length,
                        itemBuilder: (_, index) {
                          final item = queue[index];
                          final selected =
                              item.assetPath == currentTrack.assetPath;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Dismissible(
                              key: ValueKey('queue_${item.assetPath}_$index'),
                              direction: canEditQueue
                                  ? DismissDirection.endToStart
                                  : DismissDirection.none,
                              confirmDismiss: (_) async {
                                return await showDialog<bool>(
                                      context: context,
                                      barrierDismissible: true,
                                      builder: (_) {
                                        return AlertDialog(
                                          backgroundColor: palette
                                              .cardBackground
                                              .withValues(alpha: 0.82),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            side: BorderSide(
                                              color: palette.textPrimary
                                                  .withValues(alpha: 0.16),
                                            ),
                                          ),
                                          title: Text(
                                            Localizations.localeOf(
                                                      context,
                                                    ).languageCode ==
                                                    'en'
                                                ? 'Remove from queue?'
                                                : 'Удалить из очереди?',
                                          ),
                                          content: Text(
                                            item.title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.of(
                                                context,
                                              ).pop(false),
                                              child: Text(
                                                Localizations.localeOf(
                                                          context,
                                                        ).languageCode ==
                                                        'en'
                                                    ? 'Cancel'
                                                    : 'Отмена',
                                              ),
                                            ),
                                            FilledButton(
                                              onPressed: () => Navigator.of(
                                                context,
                                              ).pop(true),
                                              child: Text(
                                                Localizations.localeOf(
                                                          context,
                                                        ).languageCode ==
                                                        'en'
                                                    ? 'Delete'
                                                    : 'Удалить',
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ) ??
                                    false;
                              },
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.delete_rounded),
                              ),
                              onDismissed: (_) {
                                if (roomActive) {
                                  audioPlayerService.removeFromQueue(
                                    item.assetPath,
                                  );
                                } else {
                                  audioPlayerService.removeFromQueue(
                                    item.assetPath,
                                  );
                                }
                              },
                              child: ListTile(
                                tileColor: palette.primaryDark.withValues(
                                  alpha: 0.2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                leading: Icon(
                                  selected
                                      ? Icons.graphic_eq_rounded
                                      : Icons.music_note_rounded,
                                  color: selected
                                      ? palette.accent
                                      : palette.textSecondary,
                                ),
                                title: Text(item.title),
                                subtitle: Text(item.artistDisplay),
                                trailing: IconButton(
                                  tooltip:
                                      Localizations.localeOf(
                                            context,
                                          ).languageCode ==
                                          'en'
                                      ? 'Play next'
                                      : 'Играть следующим',
                                  icon: const Icon(Icons.playlist_play_rounded),
                                  onPressed: canEditQueue
                                      ? () {
                                          if (roomActive) {
                                            audioPlayerService.moveToPlayNext(
                                              item.assetPath,
                                            );
                                          } else {
                                            audioPlayerService.moveToPlayNext(
                                              item.assetPath,
                                            );
                                          }
                                        }
                                      : null,
                                ),
                                onTap: () {
                                  audioPlayerService.playTrack(
                                    item,
                                    queue: queue,
                                    leaveListeningRoomSession: false,
                                  );
                                  Navigator.of(context).pop();
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    },
  );
}

Future<void> _showAddTrackToQueueSheet({
  required BuildContext context,
  required AppColorPalette palette,
  required AudioPlayerService audioPlayerService,
  required ListeningRoomSession roomSession,
  required bool roomActive,
  required PlaylistsRepository playlistsRepository,
}) async {
  final tracks = await _loadQueuePickerTracks();
  final playlists = await _loadQueuePickerPlaylists(playlistsRepository);
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) {
      var query = '';
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.78,
            ),
            decoration: BoxDecoration(
              color: palette.cardBackground.withValues(alpha: 0.72),
              border: Border.all(
                color: palette.textPrimary.withValues(alpha: 0.12),
              ),
            ),
            child: DefaultTabController(
              length: 3,
              child: StatefulBuilder(
                builder: (context, setSheetState) {
                  final normalizedQuery = query.trim().toLowerCase();
                  final visibleTracks = normalizedQuery.isEmpty
                      ? tracks
                      : tracks.where((track) {
                          return track.title.toLowerCase().contains(
                                normalizedQuery,
                              ) ||
                              track.artistDisplay.toLowerCase().contains(
                                normalizedQuery,
                              );
                        }).toList();
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: TextField(
                          onChanged: (value) =>
                              setSheetState(() => query = value),
                          decoration: InputDecoration(
                            hintText:
                                Localizations.localeOf(context).languageCode ==
                                    'en'
                                ? 'Search tracks'
                                : 'Поиск треков',
                            isDense: true,
                            prefixIcon: const Icon(Icons.search_rounded),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      TabBar(
                        tabs: [
                          Tab(
                            text:
                                Localizations.localeOf(context).languageCode ==
                                    'en'
                                ? 'Tracks'
                                : 'Треки',
                          ),
                          Tab(
                            text:
                                Localizations.localeOf(context).languageCode ==
                                    'en'
                                ? 'My playlists'
                                : 'Мои',
                          ),
                          Tab(
                            text:
                                Localizations.localeOf(context).languageCode ==
                                    'en'
                                ? 'Liked'
                                : 'С лайком',
                          ),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _QueueTrackList(
                              palette: palette,
                              tracks: visibleTracks,
                              emptyText:
                                  Localizations.localeOf(
                                        context,
                                      ).languageCode ==
                                      'en'
                                  ? 'No tracks found'
                                  : 'Треки не найдены',
                              onAdd: (track) {
                                audioPlayerService.addToQueue(track);
                                Navigator.of(context).pop();
                              },
                            ),
                            _QueuePlaylistList(
                              palette: palette,
                              playlists: playlists
                                  .where((p) => !p.isLiked)
                                  .toList(),
                              tracks: tracks,
                              playlistsRepository: playlistsRepository,
                              audioPlayerService: audioPlayerService,
                              emptyText:
                                  Localizations.localeOf(
                                        context,
                                      ).languageCode ==
                                      'en'
                                  ? 'No playlists yet'
                                  : 'Плейлистов пока нет',
                              onDone: () => Navigator.of(context).pop(),
                            ),
                            _QueuePlaylistList(
                              palette: palette,
                              playlists: playlists
                                  .where((p) => p.isLiked)
                                  .toList(),
                              tracks: tracks,
                              playlistsRepository: playlistsRepository,
                              audioPlayerService: audioPlayerService,
                              emptyText:
                                  Localizations.localeOf(
                                        context,
                                      ).languageCode ==
                                      'en'
                                  ? 'No liked playlists'
                                  : 'Нет плейлистов с лайком',
                              onDone: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
    },
  );
}

Future<List<Track>> _loadQueuePickerTracks() async {
  try {
    final remote = await TracksApi().fetchTracks(limit: 200);
    return remote
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
    return const [];
  }
}

Future<List<Playlist>> _loadQueuePickerPlaylists(
  PlaylistsRepository playlistsRepository,
) async {
  try {
    return await playlistsRepository.getPlaylists();
  } catch (_) {
    return const [];
  }
}

Track? _trackByAssetPath(List<Track> tracks, String assetPath) {
  for (final track in tracks) {
    if (track.assetPath == assetPath) return track;
  }
  return null;
}

Future<List<Track>> _tracksFromPlaylist({
  required Playlist playlist,
  required List<Track> knownTracks,
  required PlaylistsRepository playlistsRepository,
}) async {
  var detailed = playlist;
  if (detailed.trackAssetPaths.isEmpty) {
    detailed = await playlistsRepository.getPlaylist(playlist.id) ?? playlist;
  }
  final out = <Track>[];
  for (final path in detailed.trackAssetPaths) {
    final known = _trackByAssetPath(knownTracks, path);
    if (known != null) {
      out.add(known);
      continue;
    }
    final id = TracksApi().parseServerTrackId(path);
    if (id == null) continue;
    try {
      final remote = await TracksApi().fetchTrackById(id);
      out.add(
        Track(
          assetPath: 'server_track_${remote.id}',
          title: remote.title.trim().isEmpty ? '—' : remote.title.trim(),
          artist: remote.artist,
          audioFilePath: remote.streamUrl(),
          coverAssetPath: remote.coverUrl(),
          coverBytes: remote.coverBytes,
        ),
      );
    } catch (_) {}
  }
  return out;
}

class _QueueTrackList extends StatelessWidget {
  const _QueueTrackList({
    required this.palette,
    required this.tracks,
    required this.emptyText,
    required this.onAdd,
  });

  final AppColorPalette palette;
  final List<Track> tracks;
  final String emptyText;
  final ValueChanged<Track> onAdd;

  @override
  Widget build(BuildContext context) {
    if (tracks.isEmpty) {
      return Center(
        child: Text(emptyText, style: TextStyle(color: palette.textMuted)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: tracks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = tracks[index];
        return ListTile(
          tileColor: palette.primaryDark.withValues(alpha: 0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          leading: const Icon(Icons.music_note_rounded),
          title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            item.artistDisplay,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(Icons.add_circle_outline_rounded),
          onTap: () => onAdd(item),
        );
      },
    );
  }
}

class _QueuePlaylistList extends StatelessWidget {
  const _QueuePlaylistList({
    required this.palette,
    required this.playlists,
    required this.tracks,
    required this.playlistsRepository,
    required this.audioPlayerService,
    required this.emptyText,
    required this.onDone,
  });

  final AppColorPalette palette;
  final List<Playlist> playlists;
  final List<Track> tracks;
  final PlaylistsRepository playlistsRepository;
  final AudioPlayerService audioPlayerService;
  final String emptyText;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    if (playlists.isEmpty) {
      return Center(
        child: Text(emptyText, style: TextStyle(color: palette.textMuted)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: playlists.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final playlist = playlists[index];
        return ListTile(
          tileColor: palette.primaryDark.withValues(alpha: 0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          leading: const Icon(Icons.library_music_rounded),
          title: Text(
            playlist.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text('${playlist.displayTrackCount} tracks'),
          trailing: const Icon(Icons.add_circle_outline_rounded),
          onTap: () async {
            final selected = await _tracksFromPlaylist(
              playlist: playlist,
              knownTracks: tracks,
              playlistsRepository: playlistsRepository,
            );
            for (final track in selected) {
              await audioPlayerService.addToQueue(track);
            }
            onDone();
          },
        );
      },
    );
  }
}

void _showRoomManageSheet({
  required BuildContext context,
  required AppColorPalette palette,
  required AudioPlayerService audioPlayerService,
  required ListeningRoomSession roomSession,
  required _RoomManageView initialView,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) {
      var currentView = initialView;
      void applyRoomSettings({
        required bool privateRoom,
        required bool pauseHostOnly,
        required bool seekHostOnly,
        required bool shuffleHostOnly,
        required bool repeatHostOnly,
        required bool skipHostOnly,
        required bool playlistHostOnly,
      }) {
        roomSession.updateSettings(
          privateRoom: privateRoom,
          pauseHostOnly: pauseHostOnly,
          seekHostOnly: seekHostOnly,
          shuffleHostOnly: shuffleHostOnly,
          repeatHostOnly: repeatHostOnly,
          skipHostOnly: skipHostOnly,
          playlistHostOnly: playlistHostOnly,
        );
        ColistenController.instance.updateRoomSettings(
          privateRoom: privateRoom,
          pauseHostOnly: pauseHostOnly,
          seekHostOnly: seekHostOnly,
          shuffleHostOnly: shuffleHostOnly,
          repeatHostOnly: repeatHostOnly,
          skipHostOnly: skipHostOnly,
          playlistHostOnly: playlistHostOnly,
        );
      }

      return StatefulBuilder(
        builder: (context, setSheetState) {
          return FractionallySizedBox(
            heightFactor: 0.76,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: palette.cardBackground.withValues(alpha: 0.72),
                    border: Border.all(
                      color: palette.textPrimary.withValues(alpha: 0.12),
                    ),
                  ),
                  child: ListenableBuilder(
                    listenable: roomSession,
                    builder: (context, _) {
                      final participantIds = roomSession.participantIds;
                      final listeners = roomSession.listeners;
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        children: [
                          SegmentedButton<_RoomManageView>(
                            segments: [
                              ButtonSegment(
                                value: _RoomManageView.listeners,
                                icon: const Icon(Icons.groups_rounded),
                                label: Text(
                                  Localizations.localeOf(
                                            context,
                                          ).languageCode ==
                                          'en'
                                      ? 'Listeners'
                                      : 'Слушатели',
                                ),
                              ),
                              ButtonSegment(
                                value: _RoomManageView.settings,
                                icon: const Icon(Icons.settings_rounded),
                                label: Text(
                                  Localizations.localeOf(
                                            context,
                                          ).languageCode ==
                                          'en'
                                      ? 'Settings'
                                      : 'Настройки',
                                ),
                              ),
                            ],
                            selected: {currentView},
                            onSelectionChanged: (v) {
                              setSheetState(() => currentView = v.first);
                            },
                          ),
                          const SizedBox(height: 10),
                          if (currentView == _RoomManageView.listeners) ...[
                            if (participantIds.isNotEmpty)
                              ...participantIds.map((userId) {
                                final username = roomSession.participantName(
                                  userId,
                                );
                                final isSelf =
                                    username == roomSession.currentUsername;
                                final canKick = roomSession.isHost && !isSelf;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    tileColor: palette.primaryDark.withValues(
                                      alpha: 0.2,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    leading: CircleAvatar(
                                      backgroundImage: NetworkImage(
                                        userAvatarUrl(userId),
                                      ),
                                    ),
                                    title: Text('@$username'),
                                    trailing: canKick
                                        ? IconButton(
                                            icon: const Icon(
                                              Icons.person_remove_rounded,
                                            ),
                                            onPressed: () => ColistenController
                                                .instance
                                                .kickParticipant(userId),
                                          )
                                        : null,
                                  ),
                                );
                              })
                            else
                              ...listeners.map((username) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    tileColor: palette.primaryDark.withValues(
                                      alpha: 0.2,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    leading: CircleAvatar(
                                      child: Text(username[0].toUpperCase()),
                                    ),
                                    title: Text('@$username'),
                                    trailing: null,
                                  ),
                                );
                              }),
                          ] else ...[
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                Localizations.localeOf(context).languageCode ==
                                        'en'
                                    ? 'Private room'
                                    : 'Приватная комната',
                              ),
                              value: roomSession.privateRoom,
                              onChanged: (v) {
                                applyRoomSettings(
                                  privateRoom: v,
                                  pauseHostOnly: roomSession.pauseHostOnly,
                                  seekHostOnly: roomSession.seekHostOnly,
                                  shuffleHostOnly: roomSession.shuffleHostOnly,
                                  repeatHostOnly: roomSession.repeatHostOnly,
                                  skipHostOnly: roomSession.skipHostOnly,
                                  playlistHostOnly:
                                      roomSession.playlistHostOnly,
                                );
                              },
                            ),
                            _roomPermissionTile(
                              context: context,
                              palette: palette,
                              title:
                                  Localizations.localeOf(
                                        context,
                                      ).languageCode ==
                                      'en'
                                  ? 'Edit queue'
                                  : 'Редактирование очереди',
                              value: roomSession.playlistHostOnly,
                              onChanged: (v) => applyRoomSettings(
                                privateRoom: roomSession.privateRoom,
                                pauseHostOnly: roomSession.pauseHostOnly,
                                seekHostOnly: roomSession.seekHostOnly,
                                shuffleHostOnly: roomSession.shuffleHostOnly,
                                repeatHostOnly: roomSession.repeatHostOnly,
                                skipHostOnly: roomSession.skipHostOnly,
                                playlistHostOnly: v,
                              ),
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: () {
                                if (!roomSession.isHost) {
                                  audioPlayerService.stop();
                                }
                                roomSession.end();
                                Navigator.of(context).pop();
                              },
                              icon: const Icon(Icons.stop_circle_outlined),
                              label: Text(
                                Localizations.localeOf(context).languageCode ==
                                        'en'
                                    ? 'End listening room'
                                    : 'Завершить комнату',
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

enum _RoomManageView { listeners, settings }

Widget _roomPermissionTile({
  required BuildContext context,
  required AppColorPalette palette,
  required String title,
  required bool value,
  required ValueChanged<bool> onChanged,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: TextStyle(color: palette.textSecondary)),
        ),
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(
              value: true,
              label: Text(
                Localizations.localeOf(context).languageCode == 'en'
                    ? 'Host'
                    : 'Хост',
              ),
            ),
            ButtonSegment(
              value: false,
              label: Text(
                Localizations.localeOf(context).languageCode == 'en'
                    ? 'All'
                    : 'Все',
              ),
            ),
          ],
          selected: {value},
          onSelectionChanged: (v) => onChanged(v.first),
        ),
      ],
    ),
  );
}

class _TransportGlyph extends StatelessWidget {
  const _TransportGlyph({
    required this.icon,
    required this.active,
    required this.enabled,
    required this.onPressed,
    required this.palette,
    required this.accentColor,
    required this.disabledColor,
    required this.backgroundColor,
  });

  final IconData icon;
  final bool active;
  final bool enabled;
  final VoidCallback? onPressed;
  final AppColorPalette palette;
  final Color accentColor;
  final Color disabledColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final color = !enabled
        ? disabledColor.withValues(alpha: 0.55)
        : active
        ? accentColor
        : accentColor.withValues(alpha: 0.82);
    return Material(
      color: enabled ? backgroundColor : disabledColor.withValues(alpha: 0.95),
      shape: const CircleBorder(),
      child: IconButton(
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        padding: EdgeInsets.zero,
        icon: Icon(icon),
        color: color,
        iconSize: 24,
        onPressed: onPressed,
      ),
    );
  }
}

class _RepeatGlyph extends StatelessWidget {
  const _RepeatGlyph({
    required this.mode,
    required this.onPressed,
    required this.palette,
    required this.accentColor,
    required this.disabledColor,
    required this.backgroundColor,
  });

  final LoopMode mode;
  final VoidCallback? onPressed;
  final AppColorPalette palette;
  final Color accentColor;
  final Color disabledColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color color;
    switch (mode) {
      case LoopMode.off:
        icon = Icons.repeat_rounded;
        color = accentColor.withValues(alpha: 0.82);
        break;
      case LoopMode.all:
        icon = Icons.repeat_rounded;
        color = accentColor;
        break;
      case LoopMode.one:
        icon = Icons.repeat_one_rounded;
        color = accentColor;
        break;
    }
    final enabled = onPressed != null;
    return Material(
      color: enabled ? backgroundColor : disabledColor.withValues(alpha: 0.95),
      shape: const CircleBorder(),
      child: IconButton(
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        padding: EdgeInsets.zero,
        icon: Icon(icon),
        color: enabled ? color : disabledColor.withValues(alpha: 0.55),
        iconSize: 24,
        onPressed: onPressed,
      ),
    );
  }
}

class _LikeCircle extends StatelessWidget {
  const _LikeCircle({
    required this.icon,
    required this.filled,
    required this.onPressed,
    required this.palette,
    required this.accentWhenOn,
    this.backgroundColor,
  });

  final IconData icon;
  final bool filled;
  final VoidCallback onPressed;
  final AppColorPalette palette;
  final Color accentWhenOn;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor ?? Colors.white.withValues(alpha: 0.14),
      shape: const CircleBorder(),
      child: IconButton(
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        padding: EdgeInsets.zero,
        icon: Icon(icon),
        color: filled ? accentWhenOn : palette.textPrimary,
        iconSize: 24,
        onPressed: onPressed,
      ),
    );
  }
}

/// «Слушать вместе» — стекло и акцент обложки, как у остальных контролов плеера.
class _ListenTogetherGlassButton extends StatelessWidget {
  const _ListenTogetherGlassButton({
    required this.label,
    required this.accentColor,
    required this.isDark,
    required this.onPressed,
  });

  final String label;
  final Color accentColor;
  final bool isDark;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final border = Color.lerp(AppGlass.border(isDark), accentColor, 0.4)!;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AppGlass.blurredTintLayer(
            isDark: isDark,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border, width: 1.25),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accentColor.withValues(alpha: isDark ? 0.28 : 0.18),
                    AppGlass.tint(isDark),
                  ],
                ),
                boxShadow: [
                  ...AppGlass.cardShadows(isDark),
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.groups_rounded, size: 22, color: accentColor),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: accentColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Слайдер прогресса: при перетаскивании локальное значение (важно для web и плавного scrub).
class _PlayerSeekBar extends StatefulWidget {
  const _PlayerSeekBar({
    required this.audioPlayerService,
    required this.accentColor,
    required this.timeLabelColor,
    required this.disabledColor,
    required this.enabled,
    required this.clampedPositionMs,
    required this.duration,
    required this.sliderMax,
    required this.sliderValueFromService,
  });

  final AudioPlayerService audioPlayerService;
  final Color accentColor;
  final Color timeLabelColor;
  final Color disabledColor;
  final bool enabled;
  final int clampedPositionMs;
  final Duration duration;
  final double sliderMax;
  final double sliderValueFromService;

  @override
  State<_PlayerSeekBar> createState() => _PlayerSeekBarState();
}

class _PlayerSeekBarState extends State<_PlayerSeekBar> {
  bool _dragging = false;
  double _dragValue = 0;

  @override
  Widget build(BuildContext context) {
    final maxV = widget.sliderMax <= 0 ? 1.0 : widget.sliderMax;
    final fromService = widget.sliderValueFromService.clamp(0.0, maxV);
    final thumb = _dragging ? _dragValue.clamp(0.0, maxV) : fromService;

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            thumbColor: widget.enabled
                ? widget.accentColor
                : widget.disabledColor,
            activeTrackColor: widget.enabled
                ? widget.accentColor
                : widget.disabledColor,
            inactiveTrackColor: widget.enabled
                ? widget.accentColor.withValues(alpha: 0.24)
                : widget.disabledColor.withValues(alpha: 0.55),
            disabledThumbColor: widget.disabledColor,
            disabledActiveTrackColor: widget.disabledColor,
            disabledInactiveTrackColor: widget.disabledColor.withValues(
              alpha: 0.55,
            ),
          ),
          child: Slider(
            min: 0,
            max: maxV,
            value: thumb,
            onChangeStart: widget.enabled
                ? (_) {
                    setState(() {
                      _dragging = true;
                      _dragValue = fromService;
                    });
                  }
                : null,
            onChanged:
                !widget.enabled ||
                    (maxV <= 1 && widget.duration.inMilliseconds == 0)
                ? null
                : (value) {
                    setState(() => _dragValue = value);
                  },
            onChangeEnd: widget.enabled
                ? (value) {
                    widget.audioPlayerService.seek(
                      Duration(milliseconds: value.toInt()),
                    );
                    setState(() => _dragging = false);
                  }
                : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDurationLabel(
                  Duration(
                    milliseconds: _dragging
                        ? _dragValue.toInt().clamp(0, 1 << 30)
                        : widget.clampedPositionMs,
                  ),
                ),
                style: TextStyle(fontSize: 12, color: widget.timeLabelColor),
              ),
              Text(
                _formatDurationLabel(widget.duration),
                style: TextStyle(fontSize: 12, color: widget.timeLabelColor),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDurationLabel(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    final minutesStr = minutes.toString().padLeft(1, '0');
    final secondsStr = seconds.toString().padLeft(2, '0');
    return '$minutesStr:$secondsStr';
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onPressed,
    required this.foregroundColor,
    required this.disabledColor,
    required this.backgroundColor,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final Color foregroundColor;
  final Color disabledColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Material(
      color: enabled ? backgroundColor : disabledColor.withValues(alpha: 0.95),
      shape: const CircleBorder(),
      child: IconButton(
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        padding: const EdgeInsets.all(8),
        icon: Icon(icon),
        color: enabled
            ? foregroundColor
            : disabledColor.withValues(alpha: 0.55),
        iconSize: 28,
        onPressed: onPressed,
      ),
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({
    required this.isPlaying,
    required this.onPressed,
    required this.foregroundColor,
    required this.disabledColor,
    this.iconOverride,
  });

  final bool isPlaying;
  final VoidCallback? onPressed;
  final Color foregroundColor;
  final Color disabledColor;
  final IconData? iconOverride;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enabled = onPressed != null;
    final bgColors = isDark
        ? [
            enabled ? palette.playbackButtonBg : disabledColor,
            enabled
                ? palette.playbackButtonBg.withValues(alpha: 0.9)
                : disabledColor,
          ]
        : [
            enabled ? Colors.white.withValues(alpha: 0.95) : disabledColor,
            enabled ? Colors.white.withValues(alpha: 0.8) : disabledColor,
          ];
    final iconColor = enabled
        ? foregroundColor
        : disabledColor.withValues(alpha: 0.55);
    final shadowColor = isDark
        ? Colors.black.withValues(alpha: 0.4)
        : Colors.black.withValues(alpha: 0.18);
    return SizedBox(
      width: 76,
      height: 76,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: bgColors),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: IconButton(
          padding: EdgeInsets.zero,
          icon: Icon(
            iconOverride ??
                (isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
          ),
          iconSize: 38,
          color: iconColor,
          onPressed: onPressed,
        ),
      ),
    );
  }
}
