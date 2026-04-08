import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/audio/audio_player_service.dart';
import '../../../../core/audio/track.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../features/playlists/data/repositories/local_playlists_repository.dart';
import '../../../../features/playlists/domain/repositories/playlists_repository.dart';

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
                      'Добавить в плейлист',
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showPlaylistPicker(
                        context,
                        track: track,
                        audioPlayerService: audioPlayerService,
                        repository: playlistsRepository ?? LocalPlaylistsRepository(),
                      );
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.info_outline_rounded, color: palette.textSecondary),
                    title: Text(
                      'О треке',
                      style: TextStyle(color: palette.textPrimary),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showAboutTrack(context, track, palette);
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.flag_outlined, color: palette.textSecondary),
                    title: Text(
                      'Сообщить о проблеме',
                      style: TextStyle(color: palette.textPrimary),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                            'Спасибо. Мы получили обращение.',
                          ),
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

Future<void> _showPlaylistPicker(
  BuildContext context, {
  required Track track,
  required AudioPlayerService audioPlayerService,
  required PlaylistsRepository repository,
}) async {
  final playlists = await repository.getPlaylists();
  if (!context.mounted) return;
  final palette = AppPaletteExtension.of(context).palette;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final glassTint = isDark
      ? Colors.white.withValues(alpha: 0.12)
      : Colors.white.withValues(alpha: 0.34);
  final borderGlass = Colors.white.withValues(alpha: isDark ? 0.22 : 0.45);
  final path = AudioPlayerService.playablePath(track);

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.45,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        builder: (context, scrollController) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
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
                          'Выберите плейлист',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: palette.textPrimary,
                          ),
                        ),
                      ),
                      Expanded(
                        child: playlists.isEmpty
                            ? Center(
                                child: Text(
                                  'Нет плейлистов. Создайте в разделе «Плейлисты».',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: palette.textSecondary),
                                ),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                itemCount: playlists.length,
                                itemBuilder: (context, i) {
                                  final p = playlists[i];
                                  return ListTile(
                                    title: Text(
                                      p.title,
                                      style: TextStyle(
                                        color: palette.textPrimary,
                                      ),
                                    ),
                                    onTap: () async {
                                      if (p.trackAssetPaths.contains(path)) {
                                        Navigator.pop(ctx);
                                        return;
                                      }
                                      final next = p.copyWith(
                                        trackAssetPaths: [
                                          ...p.trackAssetPaths,
                                          path,
                                        ],
                                      );
                                      await repository.savePlaylist(next);
                                      if (context.mounted) {
                                        Navigator.pop(ctx);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Добавлено в «${p.title}»',
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
  );
}

void _showAboutTrack(
  BuildContext context,
  Track track,
  AppColorPalette palette,
) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: palette.cardBackground,
      title: Text(
        track.title,
        style: TextStyle(color: palette.textPrimary),
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Исполнитель: ${track.artistDisplay.isEmpty ? '—' : track.artistDisplay}',
              style: TextStyle(color: palette.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              'Файл: ${track.audioFilePath ?? track.assetPath}',
              style: TextStyle(
                fontSize: 12,
                color: palette.textMuted,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Закрыть'),
        ),
      ],
    ),
  );
}
