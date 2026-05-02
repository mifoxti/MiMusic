import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../core/audio/audio_player_service.dart';
import '../../../../core/audio/local_tracks.dart';
import '../../../../core/audio/track.dart';
import '../../../../core/l10n/app_localization.dart';
import '../../../../core/social/listening_room_session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/player/player_dock_host.dart';
import '../../../../core/player/shell_route_back_guard.dart';
import '../../../../core/player/shell_navigator_host.dart';
import '../../../../core/widgets/track_cover.dart';
import '../../../../presentation/pages/artist_page.dart';
import '../../../../presentation/pages/listening_room_page.dart';
import '../widgets/full_player_track_menu.dart';

/// Контент полного плеера. Полупрозрачное стекло — у родителя ([ExpandablePlayerDock] / мини-плеер).
class FullPlayerDockPanel extends StatelessWidget {
  const FullPlayerDockPanel({
    super.key,
    required this.audioPlayerService,
    required this.onCollapse,
  });

  final AudioPlayerService audioPlayerService;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;

    return SafeArea(
      child: ListenableBuilder(
        listenable: Listenable.merge([audioPlayerService, ListeningRoomSession.instance]),
        builder: (context, _) {
                  final track = audioPlayerService.currentTrack;
                  final position = audioPlayerService.position;
                  final duration = audioPlayerService.duration ?? Duration.zero;
                  final isPlaying = audioPlayerService.isPlaying;
                  final path = audioPlayerService.currentPlayablePath ?? '';
                  final liked =
                      path.isNotEmpty && audioPlayerService.isPathLiked(path);
                  final disliked =
                      path.isNotEmpty &&
                      audioPlayerService.isPathDisliked(path);
                  final shuffleOn = audioPlayerService.shuffleEnabled;
                  final loop = audioPlayerService.loopMode;
                  final multiQueue = audioPlayerService.hasMultiTrackQueue;
                  final roomSession = ListeningRoomSession.instance;
                  final roomActive = roomSession.active;
                  final guestMode = roomActive && !roomSession.isHost;
                  final roomAccent = guestMode
                      ? const Color(0xFFA5AEBB)
                      : const Color(0xFF5FD1FF);

                  if (track == null) {
                    return Center(
                      child: Text(
                        context.t('player.nothingPlaying'),
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 16,
                        ),
                      ),
                    );
                  }
                  final playable = AudioPlayerService.playablePath(track);
                  final downloading = audioPlayerService.isTrackDownloading(
                    playable,
                  );
                  final downloaded = audioPlayerService.isTrackDownloaded(
                    playable,
                  );

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
                              icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                              ),
                              color: palette.textPrimary,
                              iconSize: 30,
                              onPressed: onCollapse,
                            ),
                            const Spacer(),
                            if (roomActive)
                              IconButton(
                                icon: const Icon(Icons.stop_rounded),
                                color: roomAccent,
                                tooltip: Localizations.localeOf(context).languageCode == 'en'
                                    ? 'Leave room'
                                    : 'Покинуть комнату',
                                onPressed: () => roomSession.end(),
                              ),
                            IconButton(
                              icon: const Icon(Icons.queue_music_rounded),
                              color: palette.textSecondary,
                              tooltip: Localizations.localeOf(context).languageCode == 'en'
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
                              color: palette.textSecondary,
                              tooltip: Localizations.localeOf(context).languageCode == 'en'
                                  ? (downloaded ? 'Cached' : 'Download track')
                                  : (downloaded ? 'Закешировано' : 'Скачать трек'),
                              onPressed: downloading || downloaded
                                  ? null
                                  : () async {
                                final isEn = Localizations.localeOf(context).languageCode == 'en';
                                await audioPlayerService.cacheTrackMock(track);
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    behavior: SnackBarBehavior.floating,
                                    content: Text(
                                      isEn
                                          ? 'Track is cached locally (mock).'
                                          : 'Трек закеширован локально (mock).',
                                    ),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.more_vert_rounded),
                              color: palette.textSecondary,
                              onPressed: () => showFullPlayerTrackMenu(
                                context,
                                audioPlayerService: audioPlayerService,
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
                                      track.coverBytes ??
                                      track.coverFallbackPath,
                                  width: 260,
                                  height: 260,
                                  borderRadius: BorderRadius.circular(32),
                                  placeholder: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(32),
                                      color: (roomActive ? roomAccent : palette.accent).withValues(
                                        alpha: 0.9,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Icon(
                                      Icons.music_note_rounded,
                                      size: 56,
                                      color: Colors.white.withValues(
                                        alpha: 0.95,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 28),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 28,
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      track.title,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w700,
                                        color: palette.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap:
                                            track.artistDisplay.trim().isEmpty
                                            ? null
                                            : () {
                                                final route =
                                                    ShellMaterialPageRoute<void>(
                                                  builder: (_) => ArtistPage(
                                                    artistName:
                                                        track.artistDisplay,
                                                    coverAssetPath: track
                                                        .coverFallbackPath,
                                                    audioPlayerService:
                                                        audioPlayerService,
                                                  ),
                                                );
                                                final pushed =
                                                    ShellNavigatorHost.push(
                                                  route,
                                                );
                                                if (pushed) {
                                                  PlayerDockHost.collapse();
                                                } else {
                                                  Navigator.of(context).push(
                                                    route,
                                                  );
                                                }
                                              },
                                        borderRadius: BorderRadius.circular(8),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          child: Text(
                                            track.artistDisplay.isEmpty
                                                ? context.t('common.notSpecifiedArtist')
                                                : track.artistDisplay,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                              color:
                                                  track.artistDisplay
                                                      .trim()
                                                      .isEmpty
                                                  ? palette.textMuted
                                                  : (roomActive ? roomAccent : palette.accent),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    _PlayerSeekBar(
                                      audioPlayerService: audioPlayerService,
                                      palette: palette,
                                      accentColor: roomActive ? roomAccent : palette.accent,
                                      enabled: !roomActive || roomSession.canControlSeek,
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        _RoundIconButton(
                                          icon: Icons.skip_previous_rounded,
                                          onPressed: roomActive && !roomSession.canControlSkip
                                              ? null
                                              : audioPlayerService.skipToPrevious,
                                          foregroundColor:
                                              palette.textSecondary,
                                        ),
                                        const SizedBox(width: 20),
                                        _PlayPauseButton(
                                          isPlaying: isPlaying,
                                          onPressed: audioPlayerService.togglePlayPause,
                                          foregroundColor:
                                              roomActive ? roomAccent : palette.textPrimary,
                                        ),
                                        const SizedBox(width: 20),
                                        _RoundIconButton(
                                          icon: Icons.skip_next_rounded,
                                          onPressed: roomActive && !roomSession.canControlSkip
                                              ? null
                                              : audioPlayerService.skipToNext,
                                          foregroundColor:
                                              palette.textSecondary,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    if (roomActive) ...[
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: (roomActive ? roomAccent : palette.accent)
                                              .withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: (roomActive ? roomAccent : palette.accent)
                                                .withValues(alpha: 0.45),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.groups_rounded,
                                              color: roomActive ? roomAccent : palette.accent,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                Localizations.localeOf(context).languageCode == 'en'
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
                                                tooltip: Localizations.localeOf(context).languageCode == 'en'
                                                    ? 'Room settings'
                                                    : 'Настройки комнаты',
                                                icon: const Icon(Icons.settings_rounded),
                                                color: roomActive ? roomAccent : palette.accent,
                                                onPressed: () {
                                                  _showRoomManageSheet(
                                                    context: context,
                                                    palette: palette,
                                                    roomSession: roomSession,
                                                    initialView: _RoomManageView.settings,
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
                                        child: SizedBox(
                                          width: double.infinity,
                                          child: FilledButton.icon(
                                            onPressed: () {
                                              Navigator.of(context).push(
                                                ShellMaterialPageRoute<void>(
                                                  settings: const RouteSettings(
                                                    name: ListeningRoomPage.routeName,
                                                  ),
                                                  builder: (_) => ListeningRoomPage(
                                                    audioPlayerService: audioPlayerService,
                                                  ),
                                                ),
                                              );
                                            },
                                            icon: const Icon(
                                              Icons.groups_rounded,
                                              size: 22,
                                            ),
                                            label: Padding(
                                              padding: const EdgeInsets.symmetric(
                                                vertical: 4,
                                              ),
                                              child: Text(
                                                context.t('player.listenTogether'),
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            style: FilledButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(
                                                vertical: 14,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                            ),
                                          ),
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
                                                    : Icons
                                                          .thumb_down_off_alt_rounded,
                                                filled: disliked,
                                                onPressed: () =>
                                                    audioPlayerService
                                                        .toggleDislikeCurrent(),
                                                palette: palette,
                                                accentWhenOn:
                                                    palette.textSecondary,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Center(
                                              child: _RepeatGlyph(
                                                mode: loop,
                                                onPressed: roomActive &&
                                                        !roomSession.canControlRepeat
                                                    ? null
                                                    : () => audioPlayerService
                                                          .cycleLoopMode(),
                                                palette: palette,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Center(
                                              child: _TransportGlyph(
                                                icon: Icons.shuffle_rounded,
                                                active: shuffleOn,
                                                enabled: multiQueue &&
                                                    (!roomActive ||
                                                        roomSession.canControlShuffle),
                                                onPressed: multiQueue &&
                                                        (!roomActive ||
                                                            roomSession.canControlShuffle)
                                                    ? () => audioPlayerService
                                                          .toggleShuffle()
                                                    : null,
                                                palette: palette,
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Center(
                                              child: _LikeCircle(
                                                icon: liked
                                                    ? Icons.favorite_rounded
                                                    : Icons
                                                          .favorite_border_rounded,
                                                filled: liked,
                                                onPressed: () =>
                                                    audioPlayerService
                                                        .toggleLike(),
                                                palette: palette,
                                                accentWhenOn: palette.accent,
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
              listenable: roomActive ? roomSession : audioPlayerService,
              builder: (context, _) {
                final queue = roomActive ? roomSession.queue : audioPlayerService.activeQueue;
                final canEditQueue = roomActive ? roomSession.canEditQueue : true;
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              Localizations.localeOf(context).languageCode == 'en'
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
                            tooltip: Localizations.localeOf(context).languageCode == 'en'
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
                          final selected = item.assetPath == currentTrack.assetPath;
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
                                          backgroundColor: palette.cardBackground.withValues(
                                            alpha: 0.82,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                            side: BorderSide(
                                              color: palette.textPrimary.withValues(alpha: 0.16),
                                            ),
                                          ),
                                          title: Text(
                                            Localizations.localeOf(context).languageCode == 'en'
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
                                              onPressed: () => Navigator.of(context).pop(false),
                                              child: Text(
                                                Localizations.localeOf(context).languageCode == 'en'
                                                    ? 'Cancel'
                                                    : 'Отмена',
                                              ),
                                            ),
                                            FilledButton(
                                              onPressed: () => Navigator.of(context).pop(true),
                                              child: Text(
                                                Localizations.localeOf(context).languageCode == 'en'
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
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.delete_rounded),
                              ),
                              onDismissed: (_) {
                                if (roomActive) {
                                  roomSession.removeFromQueue(item.assetPath);
                                } else {
                                  audioPlayerService.removeFromQueue(item.assetPath);
                                }
                              },
                              child: ListTile(
                                tileColor: palette.primaryDark.withValues(alpha: 0.2),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                leading: Icon(
                                  selected ? Icons.graphic_eq_rounded : Icons.music_note_rounded,
                                  color: selected ? palette.accent : palette.textSecondary,
                                ),
                                title: Text(item.title),
                                subtitle: Text(item.artistDisplay),
                                trailing: IconButton(
                                  tooltip: Localizations.localeOf(context).languageCode == 'en'
                                      ? 'Play next'
                                      : 'Играть следующим',
                                  icon: const Icon(Icons.playlist_play_rounded),
                                  onPressed: canEditQueue
                                      ? () {
                                          if (roomActive) {
                                            roomSession.moveToPlayNext(
                                              assetPath: item.assetPath,
                                              currentAssetPath: currentTrack.assetPath,
                                            );
                                          } else {
                                            audioPlayerService.moveToPlayNext(item.assetPath);
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
}) async {
  final tracks = await loadLocalTracks();
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    showDragHandle: true,
    builder: (_) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: palette.cardBackground.withValues(alpha: 0.72),
              border: Border.all(
                color: palette.textPrimary.withValues(alpha: 0.12),
              ),
            ),
            child: ListView.separated(
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
                  title: Text(item.title),
                  subtitle: Text(item.artistDisplay),
                  trailing: const Icon(Icons.add_circle_outline_rounded),
                  onTap: () {
                    if (roomActive) {
                      roomSession.insertIntoQueue(roomSession.queue.length, item);
                    } else {
                      audioPlayerService.addToQueue(item);
                    }
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
          ),
        ),
      );
    },
  );
}

void _showRoomManageSheet({
  required BuildContext context,
  required AppColorPalette palette,
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
      return StatefulBuilder(
        builder: (context, setSheetState) {
          return FractionallySizedBox(
            heightFactor: 0.76,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: palette.cardBackground.withValues(alpha: 0.72),
                    border: Border.all(color: palette.textPrimary.withValues(alpha: 0.12)),
                  ),
                  child: ListenableBuilder(
                    listenable: roomSession,
                    builder: (context, _) {
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
                                Localizations.localeOf(context).languageCode == 'en'
                                    ? 'Listeners'
                                    : 'Слушатели',
                              ),
                            ),
                            ButtonSegment(
                              value: _RoomManageView.settings,
                              icon: const Icon(Icons.settings_rounded),
                              label: Text(
                                Localizations.localeOf(context).languageCode == 'en'
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
                          ...listeners.map((username) {
                            final canKick = username != 'mifoxti';
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                tileColor: palette.primaryDark.withValues(alpha: 0.2),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                leading: CircleAvatar(
                                  child: Text(username[0].toUpperCase()),
                                ),
                                title: Text('@$username'),
                                trailing: canKick
                                    ? IconButton(
                                        icon: const Icon(Icons.person_remove_rounded),
                                        onPressed: () => roomSession.removeParticipant(username),
                                      )
                                    : null,
                              ),
                            );
                          }),
                        ] else ...[
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              Localizations.localeOf(context).languageCode == 'en'
                                  ? 'Private room'
                                  : 'Приватная комната',
                            ),
                            value: roomSession.privateRoom,
                            onChanged: (v) {
                              roomSession.updateSettings(
                                privateRoom: v,
                                pauseHostOnly: roomSession.pauseHostOnly,
                                seekHostOnly: roomSession.seekHostOnly,
                                shuffleHostOnly: roomSession.shuffleHostOnly,
                                repeatHostOnly: roomSession.repeatHostOnly,
                                skipHostOnly: roomSession.skipHostOnly,
                                playlistHostOnly: roomSession.playlistHostOnly,
                              );
                            },
                          ),
                          _roomPermissionTile(
                            context: context,
                            palette: palette,
                            title: Localizations.localeOf(context).languageCode == 'en'
                                ? 'Pause / resume'
                                : 'Пауза / продолжить',
                            value: roomSession.pauseHostOnly,
                            onChanged: (v) => roomSession.updateSettings(
                              privateRoom: roomSession.privateRoom,
                              pauseHostOnly: v,
                              seekHostOnly: roomSession.seekHostOnly,
                              shuffleHostOnly: roomSession.shuffleHostOnly,
                              repeatHostOnly: roomSession.repeatHostOnly,
                              skipHostOnly: roomSession.skipHostOnly,
                              playlistHostOnly: roomSession.playlistHostOnly,
                            ),
                          ),
                          _roomPermissionTile(
                            context: context,
                            palette: palette,
                            title: Localizations.localeOf(context).languageCode == 'en'
                                ? 'Seek progress bar'
                                : 'Перемотка трека',
                            value: roomSession.seekHostOnly,
                            onChanged: (v) => roomSession.updateSettings(
                              privateRoom: roomSession.privateRoom,
                              pauseHostOnly: roomSession.pauseHostOnly,
                              seekHostOnly: v,
                              shuffleHostOnly: roomSession.shuffleHostOnly,
                              repeatHostOnly: roomSession.repeatHostOnly,
                              skipHostOnly: roomSession.skipHostOnly,
                              playlistHostOnly: roomSession.playlistHostOnly,
                            ),
                          ),
                          _roomPermissionTile(
                            context: context,
                            palette: palette,
                            title: Localizations.localeOf(context).languageCode == 'en'
                                ? 'Shuffle queue'
                                : 'Перемешивание очереди',
                            value: roomSession.shuffleHostOnly,
                            onChanged: (v) => roomSession.updateSettings(
                              privateRoom: roomSession.privateRoom,
                              pauseHostOnly: roomSession.pauseHostOnly,
                              seekHostOnly: roomSession.seekHostOnly,
                              shuffleHostOnly: v,
                              repeatHostOnly: roomSession.repeatHostOnly,
                              skipHostOnly: roomSession.skipHostOnly,
                              playlistHostOnly: roomSession.playlistHostOnly,
                            ),
                          ),
                          _roomPermissionTile(
                            context: context,
                            palette: palette,
                            title: Localizations.localeOf(context).languageCode == 'en'
                                ? 'Repeat mode'
                                : 'Режим повтора',
                            value: roomSession.repeatHostOnly,
                            onChanged: (v) => roomSession.updateSettings(
                              privateRoom: roomSession.privateRoom,
                              pauseHostOnly: roomSession.pauseHostOnly,
                              seekHostOnly: roomSession.seekHostOnly,
                              shuffleHostOnly: roomSession.shuffleHostOnly,
                              repeatHostOnly: v,
                              skipHostOnly: roomSession.skipHostOnly,
                              playlistHostOnly: roomSession.playlistHostOnly,
                            ),
                          ),
                          _roomPermissionTile(
                            context: context,
                            palette: palette,
                            title: Localizations.localeOf(context).languageCode == 'en'
                                ? 'Skip tracks'
                                : 'Переключение треков',
                            value: roomSession.skipHostOnly,
                            onChanged: (v) => roomSession.updateSettings(
                              privateRoom: roomSession.privateRoom,
                              pauseHostOnly: roomSession.pauseHostOnly,
                              seekHostOnly: roomSession.seekHostOnly,
                              shuffleHostOnly: roomSession.shuffleHostOnly,
                              repeatHostOnly: roomSession.repeatHostOnly,
                              skipHostOnly: v,
                              playlistHostOnly: roomSession.playlistHostOnly,
                            ),
                          ),
                          _roomPermissionTile(
                            context: context,
                            palette: palette,
                            title: Localizations.localeOf(context).languageCode == 'en'
                                ? 'Edit queue'
                                : 'Редактирование очереди',
                            value: roomSession.playlistHostOnly,
                            onChanged: (v) => roomSession.updateSettings(
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
                              roomSession.end();
                              Navigator.of(context).pop();
                            },
                            icon: const Icon(Icons.stop_circle_outlined),
                            label: Text(
                              Localizations.localeOf(context).languageCode == 'en'
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
          child: Text(
            title,
            style: TextStyle(color: palette.textSecondary),
          ),
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
  });

  final IconData icon;
  final bool active;
  final bool enabled;
  final VoidCallback? onPressed;
  final AppColorPalette palette;

  @override
  Widget build(BuildContext context) {
    final color = !enabled
        ? palette.textMuted.withValues(alpha: 0.35)
        : active
        ? palette.accent
        : palette.textSecondary;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: Colors.white.withValues(alpha: 0.14),
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
      ),
    );
  }
}

class _RepeatGlyph extends StatelessWidget {
  const _RepeatGlyph({
    required this.mode,
    required this.onPressed,
    required this.palette,
  });

  final LoopMode mode;
  final VoidCallback? onPressed;
  final AppColorPalette palette;

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color color;
    switch (mode) {
      case LoopMode.off:
        icon = Icons.repeat_rounded;
        color = palette.textSecondary;
        break;
      case LoopMode.all:
        icon = Icons.repeat_rounded;
        color = palette.accent;
        break;
      case LoopMode.one:
        icon = Icons.repeat_one_rounded;
        color = palette.accent;
        break;
    }
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: Colors.white.withValues(alpha: 0.14),
        shape: const CircleBorder(),
        child: IconButton(
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          padding: EdgeInsets.zero,
          icon: Icon(icon),
          color: enabled ? color : palette.textMuted.withValues(alpha: 0.35),
          iconSize: 24,
          onPressed: onPressed,
        ),
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
  });

  final IconData icon;
  final bool filled;
  final VoidCallback onPressed;
  final AppColorPalette palette;
  final Color accentWhenOn;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.14),
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

/// Слайдер прогресса: при перетаскивании локальное значение (важно для web и плавного scrub).
class _PlayerSeekBar extends StatefulWidget {
  const _PlayerSeekBar({
    required this.audioPlayerService,
    required this.palette,
    required this.accentColor,
    required this.enabled,
    required this.clampedPositionMs,
    required this.duration,
    required this.sliderMax,
    required this.sliderValueFromService,
  });

  final AudioPlayerService audioPlayerService;
  final AppColorPalette palette;
  final Color accentColor;
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
    final palette = widget.palette;
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
            thumbColor: widget.accentColor,
            activeTrackColor: widget.accentColor,
            inactiveTrackColor: palette.cardBackground.withValues(alpha: 0.7),
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
            onChanged: !widget.enabled || (maxV <= 1 && widget.duration.inMilliseconds == 0)
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
                style: TextStyle(fontSize: 12, color: palette.textSecondary),
              ),
              Text(
                _formatDurationLabel(widget.duration),
                style: TextStyle(fontSize: 12, color: palette.textSecondary),
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
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onPressed == null ? 0.45 : 1.0,
      child: Material(
        color: Colors.white.withValues(alpha: 0.18),
        shape: const CircleBorder(),
        child: IconButton(
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          padding: const EdgeInsets.all(8),
          icon: Icon(icon),
          color: foregroundColor,
          iconSize: 28,
          onPressed: onPressed,
        ),
      ),
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({
    required this.isPlaying,
    required this.onPressed,
    required this.foregroundColor,
  });

  final bool isPlaying;
  final VoidCallback? onPressed;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColors = isDark
        ? [
            palette.playbackButtonBg,
            palette.playbackButtonBg.withValues(alpha: 0.9),
          ]
        : [
            Colors.white.withValues(alpha: 0.95),
            Colors.white.withValues(alpha: 0.8),
          ];
    final iconColor = isDark ? palette.playbackButtonIcon : foregroundColor;
    final shadowColor = isDark
        ? Colors.black.withValues(alpha: 0.4)
        : Colors.black.withValues(alpha: 0.18);
    return Opacity(
      opacity: onPressed == null ? 0.45 : 1.0,
      child: SizedBox(
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
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            ),
            iconSize: 38,
            color: iconColor,
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }
}
