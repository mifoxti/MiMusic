import 'package:flutter/material.dart';

import '../../core/audio/audio_player_service.dart';
import '../../core/l10n/app_localization.dart';
import '../../core/settings/app_settings.dart';
import '../../core/settings/settings_repository.dart';
import '../fragments/personal_settings_fragment.dart';
import '../widgets/settings_glass_scaffold.dart';

/// Персональные настройки: профиль (аватар, почта, пароль, ник).
class PersonalSettingsPage extends StatefulWidget {
  const PersonalSettingsPage({
    super.key,
    required this.settingsRepository,
    required this.initialSettings,
    required this.audioPlayerService,
    this.onShellSettingsReload,
  });

  final SettingsRepository settingsRepository;
  final AppSettings initialSettings;
  final AudioPlayerService audioPlayerService;
  final Future<void> Function()? onShellSettingsReload;

  @override
  State<PersonalSettingsPage> createState() => _PersonalSettingsPageState();
}

class _PersonalSettingsPageState extends State<PersonalSettingsPage> {
  late AppSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings;
    WidgetsBinding.instance.addPostFrameCallback((_) => _reloadFromRepository());
  }

  Future<void> _reloadFromRepository() async {
    final s = await widget.settingsRepository.getSettings();
    if (!mounted) return;
    setState(() => _settings = s);
  }

  Future<void> _onProfileSaved() async {
    await _reloadFromRepository();
    await widget.onShellSettingsReload?.call();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsGlassScaffold(
      title: context.t('settings.personal'),
      audioPlayerService: widget.audioPlayerService,
      child: SettingsGlassScrollView(
        audioPlayerService: widget.audioPlayerService,
        child: PersonalSettingsFragment(
          settingsRepository: widget.settingsRepository,
          initialSettings: _settings,
          onProfileSaved: _onProfileSaved,
        ),
      ),
    );
  }
}
