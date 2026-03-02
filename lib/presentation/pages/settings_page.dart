import 'package:flutter/material.dart';

import '../../core/audio/audio_player_service.dart';
import '../../core/settings/app_settings.dart';
import '../../core/settings/settings_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'equalizer_page.dart';
import 'personal_settings_page.dart';

/// Экран настроек: тема, персональные данные, эквалайзер, прочее. Читает/сохраняет через [SettingsRepository].
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
    required this.settingsRepository,
    required this.initialSettings,
    required this.audioPlayerService,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;
  final SettingsRepository settingsRepository;
  final AppSettings initialSettings;
  final AudioPlayerService audioPlayerService;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late ThemeMode _themeMode;
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.themeMode;
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildContentCard(
                      palette,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionLabel(palette, 'Тема'),
                          const SizedBox(height: 10),
                          _buildThemeChips(palette),
                          const SizedBox(height: 24),
                          _sectionLabel(palette, 'Прочее'),
                          const SizedBox(height: 8),
                          _buildOtherRows(palette),
                        ],
                      ),
                    ),
                  ],
                ),
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
            'Настройки',
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
      (ThemeMode.light, 'Светлая', Icons.light_mode_rounded),
      (ThemeMode.dark, 'Тёмная', Icons.dark_mode_rounded),
      (ThemeMode.system, 'Система', Icons.brightness_auto_rounded),
    ];
    return Row(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _buildThemeChip(palette, options[i].$1, options[i].$2, options[i].$3),
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
          'Персональные настройки',
          subtitle: 'Профиль',
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
          'Эквалайзер',
          subtitle: 'Настроить полосы частот',
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
          'Уведомления',
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
        _row(palette, Icons.language_rounded, 'Язык', subtitle: 'Русский', onTap: () {}),
        _rowDivider(palette),
        _row(palette, Icons.folder_outlined, 'Кэш', subtitle: 'Очистить', onTap: () {}),
        _rowDivider(palette),
        _row(palette, Icons.info_outline_rounded, 'О приложении', subtitle: 'MiMusic 1.0.0', onTap: () {}),
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
}
