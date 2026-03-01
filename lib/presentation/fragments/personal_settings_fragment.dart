import 'package:flutter/material.dart';

import '../../core/settings/app_settings.dart';
import '../../core/settings/settings_repository.dart';
import 'profile_edit_fragment.dart';

/// Фрагмент персональных настроек: только профиль (аватар, почта, пароль, ник). Тема в общих настройках.
class PersonalSettingsFragment extends StatelessWidget {
  const PersonalSettingsFragment({
    super.key,
    required this.settingsRepository,
    required this.initialSettings,
  });

  final SettingsRepository settingsRepository;
  final AppSettings initialSettings;

  @override
  Widget build(BuildContext context) {
    return ProfileEditFragment(
      settingsRepository: settingsRepository,
      initialSettings: initialSettings,
    );
  }
}
