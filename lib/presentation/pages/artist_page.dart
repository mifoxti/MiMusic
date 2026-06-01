import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/audio/audio_player_service.dart';
import '../../core/audio/track.dart';
import '../../core/auth/auth_session_store.dart';
import '../../core/constants/app_constants.dart';
import '../../core/l10n/app_localization.dart';
import '../../core/network/artist_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/track_cover.dart';
import '../widgets/artist_names_text.dart';
import '../widgets/collapsing_profile_shell.dart';
import '../widgets/glass_panel.dart';
import 'user_public_profile_page.dart';
import '../../core/player/shell_route_back_guard.dart';

/// Профиль автора по имени: зарегистрированный пользователь → [UserPublicProfilePage],
/// иначе каталоговый автор с обложкой последнего трека.
class ArtistPage extends StatefulWidget {
  const ArtistPage({
    super.key,
    required this.artistName,
    this.coverAssetPath = 'assets/images/geoxor.png',
    this.coverImageUrl,
    this.audioPlayerService,
  });

  final String artistName;
  final String? coverAssetPath;
  final String? coverImageUrl;
  final AudioPlayerService? audioPlayerService;

  @override
  State<ArtistPage> createState() => _ArtistPageState();
}

class _ArtistPageState extends State<ArtistPage> {
  List<Track> _tracks = [];
  Uint8List? _heroCoverBytes;
  String? _heroCoverUrl;
  bool _loading = true;
  bool _isRegistered = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final acc = await AuthSessionStore.readAccount();
      final profile = await ArtistApi().fetchByName(
        widget.artistName,
        userId: acc?.userId,
      );
      if (!mounted) return;

      if (profile.isRegistered && profile.registeredUserId != null) {
        Navigator.of(context).pushReplacement(
          ShellMaterialPageRoute<void>(
            builder: (_) => UserPublicProfilePage(
              userId: profile.registeredUserId!,
              nickname: widget.artistName,
              audioPlayerService: widget.audioPlayerService!,
            ),
          ),
        );
        return;
      }

      final tracks = profile.songs.map((s) => s.toTrack()).toList();
      final latestTrack = tracks.isNotEmpty ? tracks.first : null;
      setState(() {
        _tracks = tracks;
        _heroCoverBytes = profile.heroCoverArt ??
            (profile.songs.isNotEmpty ? profile.songs.first.coverBytes : null);
        _heroCoverUrl = latestTrack?.coverFallbackPath;
        _isRegistered = false;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _tracks = [];
        _loading = false;
      });
    }
  }

  Future<void> _playTrack(Track t) async {
    final s = widget.audioPlayerService;
    if (s == null) return;
    await s.playTrack(t, queue: _tracks.isNotEmpty ? _tracks : [t]);
  }

  Widget _buildCover(AppColorPalette palette) {
    if (_heroCoverBytes != null && _heroCoverBytes!.isNotEmpty) {
      return Image.memory(
        _heroCoverBytes!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    }
    final networkCover = _heroCoverUrl ?? widget.coverImageUrl;
    if (networkCover != null && networkCover.isNotEmpty) {
      return Image.network(
        networkCover,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallbackCover(palette),
      );
    }
    return _fallbackCover(palette);
  }

  Widget _fallbackCover(AppColorPalette palette) {
    final asset = widget.coverAssetPath ?? 'assets/images/geoxor.png';
    return Image.asset(
      asset,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        color: palette.accent.withValues(alpha: 0.5),
        alignment: Alignment.center,
        child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 64),
      ),
    );
  }

  Widget _buildAvatar(AppColorPalette palette) {
    if (_heroCoverBytes != null && _heroCoverBytes!.isNotEmpty) {
      return CircleAvatar(
        backgroundImage: MemoryImage(_heroCoverBytes!),
      );
    }
    final url = _heroCoverUrl ?? widget.coverImageUrl;
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        backgroundImage: NetworkImage(url),
      );
    }
    return CircleAvatar(
      backgroundColor: palette.accent.withValues(alpha: 0.35),
      child: Icon(Icons.person_rounded, color: palette.textPrimary, size: 36),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;

    if (_loading || _isRegistered) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              palette.gradientStart,
              palette.gradientMiddle,
              palette.gradientEnd,
            ],
          ),
        ),
        child: Center(child: CircularProgressIndicator(color: palette.accent)),
      );
    }

    final audio = widget.audioPlayerService;
    if (audio == null) {
      return const SizedBox.shrink();
    }

    return CollapsingProfileShell(
      title: widget.artistName,
      audioPlayerService: audio,
      onRefresh: _load,
      cover: _buildCover(palette),
      avatar: _buildAvatar(palette),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassPanel(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, color: palette.accent, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.t('artist.notRegistered'),
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.35,
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          ProfileGlassSection(
            title: context.t('artist.popularTracks'),
            margin: EdgeInsets.zero,
            child: _tracks.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      context.t('artist.noTracks'),
                      style: TextStyle(color: palette.textSecondary),
                    ),
                  )
                : Column(
                    children: _tracks.take(20).map((t) {
                      return ListTile(
                        leading: SizedBox(
                          width: 48,
                          height: 48,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppConstants.radiusMedium,
                            ),
                            child: buildTrackCover(
                              coverSource: t.coverBytes ?? t.coverFallbackPath,
                              width: 48,
                              height: 48,
                              borderRadius: BorderRadius.circular(
                                AppConstants.radiusMedium,
                              ),
                              placeholder: Container(
                                color: palette.accent.withValues(alpha: 0.35),
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          t.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: t.artistDisplay.isEmpty
                            ? const Text('—')
                            : ArtistNamesText(
                                artistsText: t.artistDisplay,
                                audioPlayerService: widget.audioPlayerService,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                        trailing: IconButton(
                          icon: Icon(Icons.play_arrow_rounded, color: palette.accent),
                          onPressed: () => _playTrack(t),
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
