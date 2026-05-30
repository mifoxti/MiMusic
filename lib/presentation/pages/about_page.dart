import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
import '../../core/l10n/app_localization.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_glass.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/glass_panel.dart';
import '../widgets/settings_glass_scaffold.dart';

/// Статический экран «О приложении»: версия, ссылки, скрытая пасхалка.
class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  static const String githubUrl = 'https://github.com/mifoxti';
  static const String telegramUrl = 'https://t.me/mifoxti';

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  PackageInfo? _packageInfo;
  int _secretTapCount = 0;
  Timer? _secretTapResetTimer;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _packageInfo = info);
    });
  }

  @override
  void dispose() {
    _secretTapResetTimer?.cancel();
    super.dispose();
  }

  void _onSecretTap() {
    _secretTapResetTimer?.cancel();
    setState(() => _secretTapCount++);
    if (_secretTapCount >= 10) {
      setState(() => _secretTapCount = 0);
      _showEasterEgg();
      return;
    }
    _secretTapResetTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _secretTapCount = 0);
    });
  }

  void _showEasterEgg() {
    HapticFeedback.mediumImpact();
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.38),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final p = AppPaletteExtension.of(ctx).palette;
        final glassTint = AppGlass.tint(isDark);
        final borderGlass = AppGlass.border(isDark);
        const radius = AppConstants.radiusLarge;
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              clipBehavior: Clip.antiAlias,
              child: AppGlass.blurredTintLayer(
                isDark: isDark,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    border: Border.all(color: borderGlass, width: 1),
                    color: glassTint,
                    boxShadow: AppGlass.cardShadows(isDark),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 16, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Text(
                              '🦊',
                              style: TextStyle(fontSize: 28, color: p.textPrimary),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Лис уже здесь',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: p.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Ты нашёл секрет MiMusic. Спасибо, что копаешь глубже обложки альбома.\n\n'
                          'Пусть басы будут ровными, а очередь — из любимых треков.',
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.45,
                            color: p.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(
                              'Продолжить слушать',
                              style: TextStyle(color: p.accent),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    final ok = await canLaunchUrl(uri);
    if (!ok || !mounted) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _copyDiscordHint() async {
    await Clipboard.setData(const ClipboardData(text: 'mifoxti'));
    if (!mounted) return;
    final palette = AppPaletteExtension.of(context).palette;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.t('about.discordCopied')),
        behavior: SnackBarBehavior.floating,
        backgroundColor: palette.cardBackground,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    final versionLabel = _packageInfo == null
        ? '…'
        : '${_packageInfo!.version} (${_packageInfo!.buildNumber})';

    return SettingsGlassScaffold(
      title: context.t('about.title'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Column(
          children: [
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _onSecretTap,
                        behavior: HitTestBehavior.opaque,
                        child: Column(
                          children: [
                            Container(
                              width: 88,
                              height: 88,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    palette.accent.withValues(alpha: 0.85),
                                    palette.accent.withValues(alpha: 0.45),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: palette.accent.withValues(alpha: 0.35),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.music_note_rounded,
                                size: 44,
                                color: Colors.white.withValues(alpha: 0.95),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'MiMusic',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: palette.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              context.tr('about.version', {'version': versionLabel}),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: palette.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      GlassPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GlassSectionLabel(context.t('about.links')),
                            const SizedBox(height: 12),
                            _LinkRow(
                              palette: palette,
                              icon: Icons.code_rounded,
                              title: 'GitHub',
                              subtitle: 'github.com/mifoxti',
                              onTap: () => _openUrl(AboutPage.githubUrl),
                              opensExternally: true,
                            ),
                            _divider(palette),
                            _LinkRow(
                              palette: palette,
                              icon: Icons.send_rounded,
                              title: 'Telegram',
                              subtitle: '@mifoxti',
                              onTap: () => _openUrl(AboutPage.telegramUrl),
                              opensExternally: true,
                            ),
                            _divider(palette),
                            _LinkRow(
                              palette: palette,
                              icon: Icons.chat_rounded,
                              title: 'Discord',
                              subtitle: context.t('about.discordHint'),
                              onTap: _copyDiscordHint,
                              opensExternally: false,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        context.t('about.description'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: palette.textMuted,
                        ),
                      ),
          ],
        ),
      ),
    );
  }

  Widget _divider(AppColorPalette palette) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Divider(
        height: 1,
        indent: 40,
        endIndent: 8,
        color: palette.textMuted.withValues(alpha: 0.2),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.palette,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.opensExternally = true,
  });

  final AppColorPalette palette;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool opensExternally;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(
            children: [
              Icon(icon, size: 22, color: palette.accent),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: palette.textSecondary),
                    ),
                  ],
                ),
              ),
              Icon(
                opensExternally ? Icons.open_in_new_rounded : Icons.copy_rounded,
                size: 18,
                color: palette.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
