import 'package:flutter/material.dart';

import '../../core/settings/app_settings.dart';
import '../../core/settings/settings_repository.dart';
import 'profile_edit_fragment.dart';

/// Фрагмент персональных настроек: только профиль (аватар, почта, пароль, ник).
class PersonalSettingsFragment extends StatelessWidget {
  const PersonalSettingsFragment({
    super.key,
    required this.settingsRepository,
    required this.initialSettings,
    this.onProfileSaved,
  });

  final SettingsRepository settingsRepository;
  final AppSettings initialSettings;
  final Future<void> Function()? onProfileSaved;

  @override
  Widget build(BuildContext context) {
    return ProfileEditFragment(
      settingsRepository: settingsRepository,
      initialSettings: initialSettings,
      onProfileSaved: onProfileSaved,
    );
  }
}
