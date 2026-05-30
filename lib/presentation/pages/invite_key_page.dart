import 'package:flutter/material.dart';

import '../../core/l10n/app_localization.dart';
import '../widgets/glass_panel.dart';
import '../widgets/invite_key_section.dart';
import '../widgets/settings_glass_scaffold.dart';

/// Экран пригласительного ключа.
class InviteKeyPage extends StatelessWidget {
  const InviteKeyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsGlassScaffold(
      title: context.t('settings.inviteKey'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: GlassPanel(
          padding: const EdgeInsets.all(20),
          child: const InviteKeySection(showSectionTitle: false),
        ),
      ),
    );
  }
}
