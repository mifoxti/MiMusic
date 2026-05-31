import 'dart:async';

import 'package:flutter/material.dart';

import '../../presentation/widgets/glass_panel.dart';
import '../constants/app_constants.dart';
import '../l10n/app_localization.dart';
import '../theme/app_theme.dart';
import 'app_update_api.dart';
import 'app_update_service.dart';

Future<void> showAppUpdateDialog(
  BuildContext context,
  AppUpdateCheckResult update,
) {
  return showDialog<void>(
    context: context,
    barrierDismissible: !update.mandatory,
    barrierColor: Colors.black.withValues(alpha: 0.38),
    builder: (ctx) => _AppUpdateDialog(update: update),
  );
}

class _AppUpdateDialog extends StatefulWidget {
  const _AppUpdateDialog({required this.update});

  final AppUpdateCheckResult update;

  @override
  State<_AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<_AppUpdateDialog> {
  bool _busy = false;
  double? _progress;
  String? _error;

  Future<void> _startUpdate() async {
    setState(() {
      _busy = true;
      _error = null;
      _progress = 0;
    });
    try {
      await AppUpdateService.instance.downloadAndInstall(
        widget.update,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _progress = null;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPaletteExtension.of(context).palette;
    const radius = AppConstants.radiusLarge;
    final notes = widget.update.releaseNotes.trim();

    return PopScope(
      canPop: !widget.update.mandatory && !_busy,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Material(
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: GlassPanel(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.t('update.dialog.title'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: p.textPrimary,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    context.tr('update.dialog.body', {
                      'version': widget.update.latestVersionName,
                    }),
                    style: TextStyle(
                      color: p.textSecondary,
                      height: 1.35,
                    ),
                  ),
                  if (notes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      notes,
                      style: TextStyle(
                        color: p.textSecondary,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                  if (_busy && _progress != null) ...[
                    const SizedBox(height: 16),
                    LinearProgressIndicator(value: _progress),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(color: p.accent, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      if (!widget.update.mandatory)
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: Text(context.t('update.dialog.later')),
                        ),
                      const Spacer(),
                      FilledButton(
                        onPressed: _busy ? null : _startUpdate,
                        child: Text(
                          _busy
                              ? context.t('updates.downloading')
                              : context.t('update.dialog.update'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
