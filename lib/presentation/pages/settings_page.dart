import 'package:flutter/material.dart';

import '../../core/audio/audio_player_service.dart';
import '../../core/l10n/app_localization.dart';
import '../../core/settings/app_settings.dart';
import '../../core/settings/settings_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/auth/session_scope.dart';
import '../../core/player/shell_route_back_guard.dart';
import '../widgets/glass_panel.dart';
import '../widgets/settings_glass_scaffold.dart';
import 'about_page.dart';
import 'cache_page.dart';
import 'equalizer_page.dart';
import 'language_page.dart';
import 'invite_key_page.dart';
import 'personal_settings_page.dart';

/// Экран настроек: тема, персональные данные, эквалайзер, прочее.
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
    required this.onLanguageChanged,
    required this.settingsRepository,
    required this.initialSettings,
    required this.audioPlayerService,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;
  final ValueChanged<String> onLanguageChanged;
  final SettingsRepository settingsRepository;
  final AppSettings initialSettings;
  final AudioPlayerService audioPlayerService;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late ThemeMode _themeMode;
  late String _languageCode;
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.themeMode;
    _languageCode = widget.initialSettings.languageCode;
    _notificationsEnabled = widget.initialSettings.notificationsEnabled;
  }

  @override
  void dispose() {
    widget.settingsRepository.getSettings().then((current) {
      widget.settingsRepository.saveSettings(
        current.copyWith(notificationsEnabled: _notificationsEnabled),
      );
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;

    return SettingsGlassScaffold(
      title: context.t('settings.title'),
      audioPlayerService: widget.audioPlayerService,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GlassSectionLabel(context.t('settings.theme')),
                  const SizedBox(height: 10),
                  _buildThemeChips(palette),
                ],
              ),
            ),
            const SizedBox(height: 14),
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GlassSectionLabel(context.t('settings.other')),
                  const SizedBox(height: 8),
                  _buildOtherRows(palette),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeChips(AppColorPalette palette) {
    const options = [
      (ThemeMode.light, 'settings.light', Icons.light_mode_rounded),
      (ThemeMode.dark, 'settings.dark', Icons.dark_mode_rounded),
      (ThemeMode.system, 'settings.system', Icons.brightness_auto_rounded),
    ];
    return Row(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: GlassChoiceChip(
              label: context.t(options[i].$2),
              icon: options[i].$3,
              selected: _themeMode == options[i].$1,
              onTap: () async {
                final mode = options[i].$1;
                setState(() => _themeMode = mode);
                widget.onThemeChanged(mode);
                final current = await widget.settingsRepository.getSettings();
                await widget.settingsRepository.saveSettings(
                  current.copyWith(themeMode: mode),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOtherRows(AppColorPalette palette) {
    return Column(
      children: [
        GlassSettingsRow(
          icon: Icons.person_rounded,
          title: context.t('settings.personal'),
          subtitle: context.t('settings.profile'),
          onTap: () {
            Navigator.of(context).push(
              ShellMaterialPageRoute<void>(
                builder: (context) => PersonalSettingsPage(
                  settingsRepository: widget.settingsRepository,
                  initialSettings: widget.initialSettings,
                  audioPlayerService: widget.audioPlayerService,
                ),
              ),
            );
          },
        ),
        const GlassSettingsDivider(),
        GlassSettingsRow(
          icon: Icons.vpn_key_rounded,
          title: context.t('settings.inviteKey'),
          subtitle: context.t('settings.inviteKeySub'),
          onTap: () {
            Navigator.of(context).push(
              ShellMaterialPageRoute<void>(
                builder: (_) => const InviteKeyPage(),
              ),
            );
          },
        ),
        const GlassSettingsDivider(),
        GlassSettingsRow(
          icon: Icons.graphic_eq_rounded,
          title: context.t('settings.equalizer'),
          subtitle: context.t('settings.equalizerSub'),
          onTap: () {
            Navigator.of(context).push(
              ShellMaterialPageRoute<void>(
                builder: (context) => EqualizerPage(
                  settingsRepository: widget.settingsRepository,
                  initialSettings: widget.initialSettings,
                  audioPlayerService: widget.audioPlayerService,
                ),
              ),
            );
          },
        ),
        const GlassSettingsDivider(),
        GlassSettingsRow(
          icon: Icons.notifications_outlined,
          title: context.t('settings.notifications'),
          trailing: Switch(
            value: _notificationsEnabled,
            onChanged: (v) async {
              setState(() => _notificationsEnabled = v);
              final current = await widget.settingsRepository.getSettings();
              await widget.settingsRepository.saveSettings(
                current.copyWith(notificationsEnabled: v),
              );
            },
            activeThumbColor: palette.accent,
          ),
        ),
        const GlassSettingsDivider(),
        GlassSettingsRow(
          icon: Icons.language_rounded,
          title: context.t('settings.language'),
          subtitle: _languageCode == 'en'
              ? context.t('language.english')
              : context.t('language.russian'),
          onTap: _openLanguagePage,
        ),
        const GlassSettingsDivider(),
        GlassSettingsRow(
          icon: Icons.folder_outlined,
          title: context.t('settings.cache'),
          subtitle: context.t('settings.cacheSub'),
          onTap: () async {
            final fresh = await widget.settingsRepository.getSettings();
            if (!mounted) return;
            await Navigator.of(context).push<void>(
              ShellMaterialPageRoute<void>(
                builder: (context) => CachePage(
                  settingsRepository: widget.settingsRepository,
                  initialSettings: fresh,
                ),
              ),
            );
          },
        ),
        const GlassSettingsDivider(),
        GlassSettingsRow(
          icon: Icons.logout_rounded,
          title: context.t('settings.logout'),
          subtitle: context.t('settings.logoutSub'),
          onTap: () async {
            final nav = Navigator.of(context);
            final signOut = SessionScope.of(context).onSignOut;
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) {
                final p = AppPaletteExtension.of(ctx).palette;
                return AlertDialog(
                  backgroundColor: p.cardBackground,
                  title: Text(context.t('settings.logoutConfirmTitle')),
                  content: Text(context.t('settings.logoutConfirmBody')),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text(context.t('common.cancel')),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(context.t('settings.logoutConfirmAction')),
                    ),
                  ],
                );
              },
            );
            if (ok != true || !context.mounted) return;
            nav.pop();
            await signOut();
          },
        ),
        const GlassSettingsDivider(),
        GlassSettingsRow(
          icon: Icons.info_outline_rounded,
          title: context.t('settings.about'),
          subtitle: context.t('settings.aboutSub'),
          onTap: () {
            Navigator.of(context).push(
              ShellMaterialPageRoute<void>(
                builder: (context) => const AboutPage(),
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _openLanguagePage() async {
    final selected = await Navigator.of(context).push<String>(
      ShellMaterialPageRoute<String>(
        builder: (_) => LanguagePage(
          currentLanguageCode: _languageCode,
          audioPlayerService: widget.audioPlayerService,
        ),
      ),
    );
    if (selected == null || selected == _languageCode) return;
    setState(() => _languageCode = selected);
    widget.onLanguageChanged(selected);
    final current = await widget.settingsRepository.getSettings();
    await widget.settingsRepository.saveSettings(
      current.copyWith(languageCode: selected),
    );
  }
}
