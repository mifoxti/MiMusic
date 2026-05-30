import 'package:flutter/material.dart';

import '../../core/audio/audio_player_service.dart';
import '../../core/l10n/app_localization.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/glass_panel.dart';
import '../widgets/settings_glass_scaffold.dart';

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

    return SettingsGlassScaffold(
      title: context.t('settings.language'),
      audioPlayerService: audioPlayerService,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: GlassPanel(
          child: Column(
            children: [
              GlassSettingsRow(
                icon: Icons.language_rounded,
                title: context.t('language.russian'),
                subtitle: 'Русский интерфейс',
                onTap: () => Navigator.of(context).pop('ru'),
                trailing: Icon(
                  currentLanguageCode == 'ru'
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  color: currentLanguageCode == 'ru' ? palette.accent : palette.textMuted,
                ),
              ),
              const GlassSettingsDivider(),
              GlassSettingsRow(
                icon: Icons.language_rounded,
                title: context.t('language.english'),
                subtitle: 'English interface',
                onTap: () => Navigator.of(context).pop('en'),
                trailing: Icon(
                  currentLanguageCode == 'en'
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  color: currentLanguageCode == 'en' ? palette.accent : palette.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
