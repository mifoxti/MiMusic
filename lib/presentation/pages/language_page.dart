import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/audio/audio_player_service.dart';
import '../../core/constants/app_constants.dart';
import '../../core/l10n/app_localization.dart';
import '../../core/theme/app_theme.dart';

class LanguagePage extends StatelessWidget {
  const LanguagePage({
    super.key,
    required this.currentLanguageCode,
    required this.audioPlayerService,
  });

  final String currentLanguageCode;
  final AudioPlayerService audioPlayerService;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    return Scaffold(
      backgroundColor: palette.gradientStart,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: audioPlayerService,
          builder: (context, _) {
            final hasMiniPlayer = audioPlayerService.currentTrack != null;
            final bottomContentInset = hasMiniPlayer
                ? AppConstants.shellBottomInsetWithMiniPlayer
                : AppConstants.shellBottomInset;
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 20,
                            color: palette.textPrimary,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: palette.cardBackground.withValues(alpha: 0.6),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          context.t('settings.language'),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: palette.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, bottomContentInset),
                  sliver: SliverList.list(
                    children: [
                      _LanguageCard(
                        title: context.t('language.russian'),
                        subtitle: 'Русский интерфейс',
                        selected: currentLanguageCode == 'ru',
                        onTap: () => Navigator.of(context).pop('ru'),
                      ),
                      const SizedBox(height: 12),
                      _LanguageCard(
                        title: context.t('language.english'),
                        subtitle: 'English interface',
                        selected: currentLanguageCode == 'en',
                        onTap: () => Navigator.of(context).pop('en'),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: palette.cardBackground.withValues(alpha: 0.55),
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
                border: Border.all(
                  color: selected
                      ? palette.accent.withValues(alpha: 0.7)
                      : palette.textPrimary.withValues(alpha: 0.15),
                  width: selected ? 1.6 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.language_rounded,
                    color: selected ? palette.accent : palette.textSecondary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: palette.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: palette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                    color: selected ? palette.accent : palette.textMuted,
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
