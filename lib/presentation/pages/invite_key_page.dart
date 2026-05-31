import 'package:flutter/material.dart';

import '../../core/audio/audio_player_service.dart';
import '../../core/l10n/app_localization.dart';
import '../widgets/glass_panel.dart';
import '../widgets/invite_key_section.dart';
import '../widgets/settings_glass_scaffold.dart';

/// Экран пригласительного ключа.
class InviteKeyPage extends StatelessWidget {
  const InviteKeyPage({super.key, this.audioPlayerService});

  final AudioPlayerService? audioPlayerService;

  @override
  Widget build(BuildContext context) {
    return SettingsGlassScaffold(
      title: context.t('settings.inviteKey'),
      audioPlayerService: audioPlayerService,
      child: SettingsGlassScrollView(
        audioPlayerService: audioPlayerService,
        child: GlassPanel(
          padding: const EdgeInsets.all(20),
          child: const InviteKeySection(showSectionTitle: false),
        ),
      ),
    );
  }
}
