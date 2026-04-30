import 'package:flutter/material.dart';

import '../../core/audio/audio_player_service.dart';
import '../../core/constants/app_constants.dart';
import '../../core/l10n/app_localization.dart';
import '../../core/settings/app_settings.dart';
import '../../core/settings/settings_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'about_page.dart';
import 'cache_page.dart';
import 'equalizer_page.dart';
import 'language_page.dart';
import 'personal_settings_page.dart';

/// Экран настроек: тема, персональные данные, эквалайзер, прочее. Читает/сохраняет через [SettingsRepository].
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

    return Scaffold(
      backgroundColor: palette.gradientStart,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(palette),
            Expanded(
              child: ListenableBuilder(
                listenable: widget.audioPlayerService,
                builder: (context, _) {
                  final hasMiniPlayer = widget.audioPlayerService.currentTrack != null;
                  final bottomContentInset = hasMiniPlayer
                      ? AppConstants.shellBottomInsetWithMiniPlayer
                      : AppConstants.shellBottomInset;
                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(20, 8, 20, bottomContentInset),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildContentCard(
                          palette,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionLabel(palette, context.t('settings.theme')),
                              const SizedBox(height: 10),
                              _buildThemeChips(palette),
                              const SizedBox(height: 24),
                              _sectionLabel(palette, context.t('settings.other')),
                              const SizedBox(height: 8),
                              _buildOtherRows(palette),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(AppColorPalette palette) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: palette.textPrimary),
            style: IconButton.styleFrom(
              backgroundColor: palette.cardBackground.withValues(alpha: 0.6),
            ),
          ),
          const Spacer(),
          Text(
            context.t('settings.title'),
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
    );
  }

  Widget _buildContentCard(AppColorPalette palette, {required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.cardBackground.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionLabel(AppColorPalette palette, String text) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: palette.textMuted,
        letterSpacing: 1.2,
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
            child: _buildThemeChip(
              palette,
              options[i].$1,
              context.t(options[i].$2),
              options[i].$3,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildThemeChip(AppColorPalette palette, ThemeMode mode, String label, IconData icon) {
    final isSelected = _themeMode == mode;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          setState(() => _themeMode = mode);
          widget.onThemeChanged(mode);
          final current = await widget.settingsRepository.getSettings();
          await widget.settingsRepository.saveSettings(current.copyWith(themeMode: mode));
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? palette.accent.withValues(alpha: 0.2) : palette.primaryLight.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? palette.accent : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: isSelected ? palette.accent : palette.textMuted),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? palette.textPrimary : palette.textSecondary,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOtherRows(AppColorPalette palette) {
    return Column(
      children: [
        _row(
          palette,
          Icons.person_rounded,
          context.t('settings.personal'),
          subtitle: context.t('settings.profile'),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => PersonalSettingsPage(
                  settingsRepository: widget.settingsRepository,
                  initialSettings: widget.initialSettings,
                ),
              ),
            );
          },
        ),
        _rowDivider(palette),
        _row(
          palette,
          Icons.graphic_eq_rounded,
          context.t('settings.equalizer'),
          subtitle: context.t('settings.equalizerSub'),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => EqualizerPage(
                  settingsRepository: widget.settingsRepository,
                  initialSettings: widget.initialSettings,
                  audioPlayerService: widget.audioPlayerService,
                ),
              ),
            );
          },
        ),
        _rowDivider(palette),
        _row(
          palette,
          Icons.notifications_outlined,
          context.t('settings.notifications'),
          trailing: Switch(
            value: _notificationsEnabled,
            onChanged: (v) async {
              setState(() => _notificationsEnabled = v);
              final current = await widget.settingsRepository.getSettings();
              await widget.settingsRepository.saveSettings(current.copyWith(notificationsEnabled: v));
            },
            activeThumbColor: palette.accent,
          ),
        ),
        _rowDivider(palette),
        _row(
          palette,
          Icons.language_rounded,
          context.t('settings.language'),
          subtitle: _languageCode == 'en'
              ? context.t('language.english')
              : context.t('language.russian'),
          onTap: _openLanguagePage,
        ),
        _rowDivider(palette),
        _row(
          palette,
          Icons.folder_outlined,
          context.t('settings.cache'),
          subtitle: context.t('settings.cacheSub'),
          onTap: () async {
            final fresh = await widget.settingsRepository.getSettings();
            if (!mounted) return;
            await Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (context) => CachePage(
                  settingsRepository: widget.settingsRepository,
                  initialSettings: fresh,
                ),
              ),
            );
          },
        ),
        _rowDivider(palette),
        _row(
          palette,
          Icons.info_outline_rounded,
          context.t('settings.about'),
          subtitle: context.t('settings.aboutSub'),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => const AboutPage(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _row(AppColorPalette palette, IconData icon, String title, {String? subtitle, Widget? trailing, VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Row(
            children: [
              Icon(icon, size: 22, color: palette.accent),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: palette.textPrimary)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle, style: TextStyle(fontSize: 12, color: palette.textSecondary)),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing else Icon(Icons.chevron_right_rounded, size: 20, color: palette.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rowDivider(AppColorPalette palette) {
    return Divider(height: 1, indent: 40, endIndent: 8, color: palette.textMuted.withValues(alpha: 0.2));
  }

  Future<void> _openLanguagePage() async {
    final selected = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
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
