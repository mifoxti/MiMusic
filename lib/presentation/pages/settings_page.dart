import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/audio/audio_player_service.dart';
import '../../core/constants/app_constants.dart';
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
import 'updates_page.dart';
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
    this.onShellSettingsReload,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;
  final ValueChanged<String> onLanguageChanged;
  final SettingsRepository settingsRepository;
  final AppSettings initialSettings;
  final AudioPlayerService audioPlayerService;
  final Future<void> Function()? onShellSettingsReload;

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
      child: SettingsGlassScrollView(
        audioPlayerService: widget.audioPlayerService,
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
            _SupportProjectButton(palette: palette),
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
              ShellMaterialPageRoute.forSettings<void>(
                subpath: 'personal',
                builder: (context) => PersonalSettingsPage(
                  settingsRepository: widget.settingsRepository,
                  initialSettings: widget.initialSettings,
                  audioPlayerService: widget.audioPlayerService,
                  onShellSettingsReload: widget.onShellSettingsReload,
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
              ShellMaterialPageRoute.forSettings<void>(
                subpath: 'invite',
                builder: (_) => InviteKeyPage(
                  audioPlayerService: widget.audioPlayerService,
                ),
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
              ShellMaterialPageRoute.forSettings<void>(
                subpath: 'equalizer',
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
              ShellMaterialPageRoute.forSettings<void>(
                subpath: 'cache',
                builder: (context) => CachePage(
                  settingsRepository: widget.settingsRepository,
                  initialSettings: fresh,
                  audioPlayerService: widget.audioPlayerService,
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
          icon: Icons.system_update_alt_rounded,
          title: context.t('settings.updates'),
          subtitle: context.t('settings.updatesSub'),
          onTap: () {
            Navigator.of(context).push(
              ShellMaterialPageRoute.forSettings<void>(
                subpath: 'updates',
                builder: (context) => UpdatesPage(
                  audioPlayerService: widget.audioPlayerService,
                ),
              ),
            );
          },
        ),
        const GlassSettingsDivider(),
        GlassSettingsRow(
          icon: Icons.info_outline_rounded,
          title: context.t('settings.about'),
          subtitle: context.t('settings.aboutSub'),
          onTap: () {
            Navigator.of(context).push(
              ShellMaterialPageRoute.forSettings<void>(
                subpath: 'about',
                builder: (context) => AboutPage(
                  audioPlayerService: widget.audioPlayerService,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _openLanguagePage() async {
    final selected = await Navigator.of(context).push<String>(
      ShellMaterialPageRoute.forSettings<String>(
        subpath: 'language',
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

/// Яркая кнопка перехода на страницу поддержки (CloudTips).
class _SupportProjectButton extends StatelessWidget {
  const _SupportProjectButton({required this.palette});

  final AppColorPalette palette;

  Future<void> _open(BuildContext context) async {
    final uri = Uri.parse(AppConstants.supportProjectUrl);
    final ok = await canLaunchUrl(uri);
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('settings.supportProjectError'))),
      );
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppConstants.radiusXLarge);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: palette.accent.withValues(alpha: 0.45),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _open(context),
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    palette.accent,
                    Color.lerp(palette.accent, Colors.deepOrange, 0.35)!,
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                      child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.t('settings.supportProject'),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.t('settings.supportProjectSub'),
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.25,
                              color: Colors.white.withValues(alpha: 0.92),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.open_in_new_rounded,
                      color: Colors.white.withValues(alpha: 0.95),
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
