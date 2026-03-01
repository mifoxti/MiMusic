import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/home_section.dart';
import '../../domain/use_cases/get_home_section_use_case.dart';
import '../widgets/featured_play_button.dart';
import '../widgets/friends_section.dart';
import '../widgets/history_section.dart';
import '../widgets/nav_card_button.dart';
import '../widgets/playback_control_button.dart';
import '../widgets/releases_section.dart';

/// Главный экран приложения MiMusic.
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.getHomeSectionUseCase,
  });

  final GetHomeSectionUseCase getHomeSectionUseCase;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  HomeSection? _section;
  bool _isLoading = true;
  bool _isPlaying = true;

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
          _section = section;
          _isPlaying = section.isPlaying;
          _isLoading = false;
        });
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
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              palette.gradientStart,
              palette.gradientMiddle,
              palette.gradientEnd,
            ],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? Center(child: CircularProgressIndicator(color: palette.accent))
              : CustomScrollView(
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
                              isPlaying: _isPlaying,
                              onPressed: () => setState(() => _isPlaying = !_isPlaying),
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
                            const SizedBox(height: 16),
                            if (_section!.featuredTrackTitle != null)
                              FeaturedPlayButton(
                                trackTitle: _section!.featuredTrackTitle!,
                                onPressed: () {},
                              ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
      bottomNavigationBar: _BottomNavBar(selectedIndex: 0),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({required this.selectedIndex});

  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
      decoration: BoxDecoration(
        color: palette.navBarBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            icon: Icons.music_note_rounded,
            label: 'Music',
            isSelected: selectedIndex == 0,
            onTap: () {},
          ),
          _NavItem(
            icon: Icons.search_rounded,
            label: 'Search',
            isSelected: selectedIndex == 1,
            onTap: () {},
          ),
          _NavItem(
            icon: Icons.person_rounded,
            label: 'Profile',
            isSelected: selectedIndex == 2,
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? palette.navActiveBackground : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 26,
              color: isSelected ? palette.textPrimary : palette.textMuted,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? palette.textPrimary : palette.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
