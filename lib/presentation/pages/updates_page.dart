import 'dart:async';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_update/app_update_api.dart';
import '../../core/app_update/app_update_service.dart';
import '../../core/audio/audio_player_service.dart';
import '../../core/l10n/app_localization.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/glass_panel.dart';
import '../widgets/settings_glass_scaffold.dart';

class UpdatesPage extends StatefulWidget {
  const UpdatesPage({super.key, this.audioPlayerService});

  static const String githubRepoUrl = 'https://github.com/mifoxti/MiMusic';

  final AudioPlayerService? audioPlayerService;

  @override
  State<UpdatesPage> createState() => _UpdatesPageState();
}

class _UpdatesPageState extends State<UpdatesPage> {
  PackageInfo? _packageInfo;
  AppUpdateCheckResult? _check;
  bool _checking = false;
  bool _downloading = false;
  double? _progress;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPackageInfo());
    AppUpdateService.instance.downloadProgress.addListener(_onDownloadProgress);
  }

  @override
  void dispose() {
    AppUpdateService.instance.downloadProgress.removeListener(_onDownloadProgress);
    super.dispose();
  }

  void _onDownloadProgress() {
    final p = AppUpdateService.instance.downloadProgress.value;
    if (!mounted) return;
    setState(() {
      _progress = p;
      _downloading = p != null;
    });
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _packageInfo = info);
  }

  Future<void> _checkUpdate() async {
    if (!AppUpdateService.instance.isAndroid) {
      setState(() {
        _statusMessage = context.t('updates.androidOnly');
      });
      return;
    }
    setState(() {
      _checking = true;
      _statusMessage = null;
    });
    final result = await AppUpdateService.instance.checkForUpdate(force: true);
    if (!mounted) return;
    setState(() {
      _checking = false;
      _check = result;
      if (result == null) {
        _statusMessage = context.t('updates.errorCheck');
      } else if (!result.updateAvailable) {
        _statusMessage = context.t('updates.upToDate');
      } else {
        _statusMessage = context.tr('updates.available', {
          'version': result.latestVersionName,
        });
      }
    });
  }

  Future<void> _downloadAndInstall() async {
    final update = _check;
    if (update == null || !update.updateAvailable) return;
    setState(() {
      _downloading = true;
      _progress = 0;
      _statusMessage = context.t('updates.downloading');
    });
    try {
      await AppUpdateService.instance.downloadAndInstall(
        update,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _progress = null;
        _statusMessage = context.t('updates.installStarted');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _progress = null;
        _statusMessage = '${context.t('updates.errorDownload')}: $e';
      });
    }
  }

  Future<void> _openGithub() async {
    final uri = Uri.parse(UpdatesPage.githubRepoUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('updates.githubError'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    final versionLabel = _packageInfo == null
        ? '…'
        : '${_packageInfo!.version} (${_packageInfo!.buildNumber})';

    return SettingsGlassScaffold(
      title: context.t('updates.title'),
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
                Text(
                  context.tr('updates.currentVersion', {'version': versionLabel}),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: palette.textPrimary,
                  ),
                ),
                if (_statusMessage != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _statusMessage!,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: palette.textSecondary,
                    ),
                  ),
                ],
                if (_check?.releaseNotes.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 10),
                  Text(
                    _check!.releaseNotes.trim(),
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: palette.textMuted,
                    ),
                  ),
                ],
                if (_downloading && _progress != null) ...[
                  const SizedBox(height: 14),
                  LinearProgressIndicator(value: _progress),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _checking ? null : _checkUpdate,
                  icon: _checking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded, size: 20),
                  label: Text(
                    _checking
                        ? context.t('updates.checking')
                        : context.t('updates.check'),
                  ),
                ),
                if (_check?.updateAvailable == true) ...[
                  const SizedBox(height: 10),
                  FilledButton.tonalIcon(
                    onPressed: _downloading ? null : _downloadAndInstall,
                    icon: const Icon(Icons.system_update_alt_rounded, size: 20),
                    label: Text(context.t('updates.downloadInstall')),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassPanel(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.code_rounded, color: palette.accent),
              title: Text(
                context.t('updates.github'),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: palette.textPrimary,
                ),
              ),
              subtitle: Text(
                context.t('updates.githubSub'),
                style: TextStyle(color: palette.textSecondary, fontSize: 13),
              ),
              trailing: Icon(Icons.open_in_new_rounded, color: palette.textMuted),
              onTap: _openGithub,
            ),
          ),
          ],
        ),
      ),
    );
  }
}
