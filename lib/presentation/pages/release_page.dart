import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/audio/audio_player_service.dart';
import '../../core/constants/app_constants.dart';
import '../../core/player/shell_navigator_host.dart';
import '../../core/player/shell_route_back_guard.dart';
import '../../core/theme/app_glass.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/cover_image.dart';
import 'artist_page.dart';

class ReleasePage extends StatelessWidget {
  const ReleasePage({
    super.key,
    required this.title,
    required this.audioPlayerService,
    this.coverUrl,
    this.artistName,
    this.trackTitle,
    this.onListenTap,
  });

  final String title;
  final AudioPlayerService audioPlayerService;
  final String? coverUrl;
  final String? artistName;
  final String? trackTitle;
  final Future<void> Function()? onListenTap;

  static Future<void> show(
    BuildContext context, {
    required String title,
    required AudioPlayerService audioPlayerService,
    String? coverUrl,
    String? artistName,
    String? trackTitle,
    Future<void> Function()? onListenTap,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => ReleasePage(
        title: title,
        audioPlayerService: audioPlayerService,
        coverUrl: coverUrl,
        artistName: artistName,
        trackTitle: trackTitle,
        onListenTap: onListenTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final releaseArtist = (artistName ?? '').trim().isEmpty
        ? (Localizations.localeOf(context).languageCode == 'en' ? 'Unknown artist' : 'Неизвестный автор')
        : artistName!;
    final newTrackTitle = (trackTitle ?? '').trim().isEmpty ? title : trackTitle!;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        child: AppGlass.blurredTintLayer(
          isDark: isDark,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppGlass.tint(isDark),
              borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
              border: Border.all(color: AppGlass.border(isDark)),
              boxShadow: AppGlass.cardShadows(isDark),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildCoverImage(
                  imageUrl: coverUrl,
                  width: 84,
                  height: 84,
                  borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
                  placeholder: _placeholder(palette),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: palette.accent.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: palette.accent.withValues(alpha: 0.45)),
                        ),
                        child: Text(
                          'NEW RELEASE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: palette.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            Navigator.of(context).pop();
                            final route = ShellMaterialPageRoute<void>(
                              builder: (_) => ArtistPage(
                                artistName: releaseArtist,
                                coverImageUrl: coverUrl,
                                audioPlayerService: audioPlayerService,
                              ),
                            );
                            final pushed = ShellNavigatorHost.push(route);
                            if (!pushed) {
                              Navigator.of(context).push(route);
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                            child: Text(
                              releaseArtist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: palette.textPrimary,
                                decoration: TextDecoration.underline,
                                decorationColor: palette.textSecondary.withValues(alpha: 0.45),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        newTrackTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            Icons.music_note_rounded,
                            size: 14,
                            color: palette.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            Localizations.localeOf(context).languageCode == 'en'
                                ? 'Single'
                                : 'Сингл',
                            style: TextStyle(
                              fontSize: 12,
                              color: palette.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.fiber_new_rounded,
                            size: 14,
                            color: palette.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            Localizations.localeOf(context).languageCode == 'en'
                                ? 'Just now'
                                : 'Только что',
                            style: TextStyle(
                              fontSize: 12,
                              color: palette.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 34,
                        child: FilledButton.icon(
                          onPressed: () {
                            final listen = onListenTap;
                            Navigator.of(context).pop();
                            if (listen != null) {
                              unawaited(listen());
                            }
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: palette.accent.withValues(alpha: 0.85),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                          ),
                          icon: const Icon(Icons.play_arrow_rounded, size: 18),
                          label: Text(
                            Localizations.localeOf(context).languageCode == 'en'
                                ? 'Listen'
                                : 'Слушать',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder(AppColorPalette palette) {
    return Container(
      color: palette.primaryLight.withValues(alpha: 0.45),
      alignment: Alignment.center,
      child: Icon(
        Icons.music_note_rounded,
        size: 34,
        color: palette.textMuted,
      ),
    );
  }
}
