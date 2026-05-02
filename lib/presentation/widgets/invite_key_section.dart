import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/auth/auth_session_store.dart' show AuthSessionStore, LocalAccount;
import '../../core/l10n/app_localization.dart';
import '../../core/theme/app_theme.dart';
import '../../features/auth/presentation/invite_key_generation_page.dart';

/// Блок «пригласительный ключ»: один ключ на аккаунт, формат Steam.
class InviteKeySection extends StatefulWidget {
  const InviteKeySection({super.key, this.showSectionTitle = true});

  /// Если `false`, заголовок не показывается (например, когда он уже в AppBar отдельной страницы).
  final bool showSectionTitle;

  @override
  State<InviteKeySection> createState() => _InviteKeySectionState();
}

class _InviteKeySectionState extends State<InviteKeySection> {
  LocalAccount? _account;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final acc = await AuthSessionStore.readAccount();
    if (!mounted) return;
    setState(() {
      _account = acc;
      _loading = false;
    });
  }

  Future<void> _openGeneration() async {
    final created = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const InviteKeyGenerationPage()),
    );
    if (!mounted) return;
    await _reload();
    if (!context.mounted) return;
    if (created != null && created.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('invite.created'))),
      );
    }
  }

  Future<void> _copy(String key) async {
    await Clipboard.setData(ClipboardData(text: key));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.t('invite.copied'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;

    if (_loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2, color: palette.textSecondary),
          ),
        ),
      );
    }

    final key = _account?.myInviteKey;
    final hasKey = key != null && key.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showSectionTitle) ...[
          Text(
            context.t('invite.sectionTitle'),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: palette.textSecondary,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Text(
          context.t('invite.sectionSubtitle'),
          style: TextStyle(
            fontSize: 12,
            height: 1.35,
            color: palette.textSecondary.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: 14),
        if (hasKey) ...[
          SelectableText(
            key,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              fontFamily: 'monospace',
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _copy(key),
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: Text(context.t('invite.copy')),
          ),
        ] else
          FilledButton.icon(
            onPressed: _openGeneration,
            icon: const Icon(Icons.vpn_key_rounded, size: 20),
            label: Text(context.t('invite.generate')),
          ),
      ],
    );
  }
}
