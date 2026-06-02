import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/audio/audio_player_service.dart';
import '../../../../core/audio/track.dart';
import '../../../../core/l10n/app_localization.dart';
import '../../../../core/network/authenticated_dio.dart';
import '../../../../core/network/tracks_api.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_glass.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../features/playlists/data/repositories/local_playlists_repository.dart';
import '../../../../features/playlists/domain/repositories/playlists_repository.dart';
import '../../../../presentation/widgets/glass_bottom_menu_sheet.dart';

/// Меню ⋮ полного плеера: «стеклянная» подложка как у мини-плеера.
Future<void> showFullPlayerTrackMenu(
  BuildContext context, {
  required AudioPlayerService audioPlayerService,
  PlaylistsRepository? playlistsRepository,
}) async {
  final track = audioPlayerService.currentTrack;
  if (track == null) return;

  final palette = AppPaletteExtension.of(context).palette;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final glassTint = isDark
      ? Colors.white.withValues(alpha: 0.12)
      : Colors.white.withValues(alpha: 0.34);
  final borderGlass = Colors.white.withValues(alpha: isDark ? 0.22 : 0.45);

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.paddingOf(ctx).bottom + 12,
          left: 12,
          right: 12,
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(Radius.circular(20)),
                border: Border.all(color: borderGlass),
                color: glassTint,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: palette.textMuted.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  ListTile(
                    leading: Icon(Icons.playlist_add_rounded, color: palette.accent),
                    title: Text(
                      context.t('player.menu.addToPlaylist'),
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      if (!context.mounted) return;
                      showTrackPlaylistPicker(
                        context,
                        track: track,
                        repository: playlistsRepository ?? LocalPlaylistsRepository(),
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.info_outline_rounded, color: palette.textSecondary),
                    title: Text(
                      context.t('player.menu.aboutTrack'),
                      style: TextStyle(color: palette.textPrimary),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      unawaited(_showAboutTrack(context, track, palette));
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.flag_outlined, color: palette.textSecondary),
                    title: Text(
                      context.t('player.menu.reportProblem'),
                      style: TextStyle(color: palette.textPrimary),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.t('player.menu.reportSent')),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: palette.cardBackground,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Добавление трека в плейлист (стеклянный sheet). [omitPlaylistId] — не показывать этот плейлист в списке.
Future<void> showTrackPlaylistPicker(
  BuildContext context, {
  required Track track,
  required PlaylistsRepository repository,
  String? omitPlaylistId,
}) async {
  final playlists = await repository.getPlaylists();
  final filtered = omitPlaylistId == null
      ? playlists
      : playlists.where((p) => p.id != omitPlaylistId).toList();
  if (!context.mounted) return;
  final palette = AppPaletteExtension.of(context).palette;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final glassTint = isDark
      ? Colors.white.withValues(alpha: 0.12)
      : Colors.white.withValues(alpha: 0.34);
  final borderGlass = Colors.white.withValues(alpha: isDark ? 0.22 : 0.45);
  /// Для плейлистов на сервере в списке хранится `server_track_<id>`, а не URL стрима.
  final playlistKey = track.assetPath;

  GlassModalOverlay.push();
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (ctx) {
      final bottomPad = MediaQuery.paddingOf(ctx).bottom + 12;
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.45,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        builder: (context, scrollController) {
          return Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 12, bottomPad),
            child: ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(20)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.all(Radius.circular(20)),
                    border: Border.all(color: borderGlass),
                    color: glassTint,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 10),
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: palette.textMuted.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                        child: Text(
                          context.t('player.menu.selectPlaylist'),
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: palette.textPrimary,
                          ),
                        ),
                      ),
                      Expanded(
                        child: filtered.isEmpty
                            ? Center(
                                child: Text(
                                  omitPlaylistId != null && playlists.isNotEmpty
                                      ? context.t('playlists.track.noOtherPlaylists')
                                      : context.t('player.menu.noPlaylists'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: palette.textSecondary),
                                ),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                itemCount: filtered.length,
                                itemBuilder: (context, i) {
                                  final p = filtered[i];
                                  return ListTile(
                                    title: Text(
                                      p.title,
                                      style: TextStyle(
                                        color: palette.textPrimary,
                                      ),
                                    ),
                                    onTap: () async {
                                      final fresh = await repository.getPlaylist(p.id);
                                      final base = fresh ?? p;
                                      if (base.trackAssetPaths.contains(playlistKey)) {
                                        Navigator.pop(ctx);
                                        return;
                                      }
                                      final next = base.copyWith(
                                        trackAssetPaths: [
                                          ...base.trackAssetPaths,
                                          playlistKey,
                                        ],
                                      );
                                      await repository.savePlaylist(next);
                                      if (context.mounted) {
                                        Navigator.pop(ctx);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              context.tr('player.menu.addedToPlaylist', {'title': p.title}),
                                            ),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  ).whenComplete(GlassModalOverlay.pop);
}

Future<void> _showAboutTrack(
  BuildContext context,
  Track track,
  AppColorPalette palette,
) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  var uploaderLabel = '—';
  final sid = TracksApi().resolveServerTrackId(
    assetPath: track.assetPath,
    audioFilePath: track.audioFilePath,
  );
  if (sid != null) {
    try {
      ServerTrackListItem item;
      try {
        final dio = await createAuthenticatedDio();
        final res = await dio.get<Map<String, dynamic>>('/tracks/$sid');
        final data = res.data;
        if (data != null) {
          item = ServerTrackListItem.fromJson(data);
        } else {
          item = await TracksApi().fetchTrackById(sid);
        }
      } catch (_) {
        item = await TracksApi().fetchTrackById(sid);
      }
      final nick = item.uploaderNickname?.trim();
      if (nick != null && nick.isNotEmpty) {
        uploaderLabel = nick.startsWith('@') ? nick : '@$nick';
      } else if (item.uploaderUserId != null) {
        uploaderLabel = 'ID ${item.uploaderUserId}';
      }
    } catch (_) {}
  }

  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (ctx) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppGlass.border(isDark),
                  ),
                  color: AppGlass.tint(isDark),
                  boxShadow: AppGlass.cardShadows(isDark),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        track.title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        context.tr('player.menu.artist', {
                          'artist': track.artistDisplay.isEmpty
                              ? '—'
                              : track.artistDisplay,
                        }),
                        style: TextStyle(color: palette.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.tr('player.menu.uploadedBy', {'name': uploaderLabel}),
                        style: TextStyle(color: palette.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(context.t('common.close')),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
