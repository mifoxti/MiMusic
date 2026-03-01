import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/home_section.dart';
import '../../domain/use_cases/get_home_section_use_case.dart';
import '../widgets/friends_section.dart';
import '../widgets/history_section.dart';
import '../widgets/nav_card_button.dart';
import '../widgets/playback_control_button.dart';
import '../widgets/releases_section.dart';

/// Фрагмент «Главная»: контент первой вкладки.
/// Состояние плеера (isPlaying, featuredTrack) передаётся в MainShell.
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.getHomeSectionUseCase,
    required this.onSectionLoaded,
    required this.isPlaying,
    required this.onPlaybackToggle,
  });

  final GetHomeSectionUseCase getHomeSectionUseCase;
  final void Function(String? featuredTrackTitle, String? featuredTrackCoverAsset, bool isPlaying) onSectionLoaded;
  final bool isPlaying;
  final VoidCallback onPlaybackToggle;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  HomeSection? _section;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final section = await widget.getHomeSectionUseCase();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _section = section;
        });
        widget.onSectionLoaded(section.featuredTrackTitle, section.featuredTrackCoverAsset, section.isPlaying);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: palette.accent));
    }
    if (_section == null) {
      return Center(
        child: Text('Ошибка загрузки', style: TextStyle(color: palette.textSecondary)),
      );
    }
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Column(
              children: [
                Text(
                  'MiMusic',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: palette.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 20),
                PlaybackControlButton(
                  isPlaying: widget.isPlaying,
                  onPressed: widget.onPlaybackToggle,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    NavCardButton(
                      title: 'Для вас',
                      onTap: () {},
                      avatarColors: const [
                        Color(0xFF5C4A50),
                        Color(0xFF4A3D42),
                      ],
                    ),
                    const SizedBox(width: 12),
                    NavCardButton(
                      title: 'Чарты',
                      onTap: () {},
                      avatarColors: const [
                        Color(0xFFC45C3E),
                        Color(0xFF8B3A2E),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                HistorySection.fromSection(_section!),
                const SizedBox(height: 20),
                FriendsSection(
                  friendPlayback: _section!.friendPlayback,
                  listeningFriends: _section!.listeningFriends,
                ),
                const SizedBox(height: 20),
                ReleasesSection(releases: _section!.latestReleases),
                const SizedBox(height: 88),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
