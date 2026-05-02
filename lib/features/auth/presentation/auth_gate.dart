import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/auth/auth_session_store.dart';
import '../../../core/auth/beta_invite_config.dart';
import '../../../core/auth/password_hash.dart';
import '../../../core/l10n/app_localization.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/settings/settings_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_glass.dart';
import '../../../core/theme/app_theme.dart';

typedef AuthSuccessCallback = Future<void> Function();

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.settingsRepository,
    required this.initialSettings,
    required this.onAuthenticated,
  });

  final SettingsRepository settingsRepository;
  final AppSettings initialSettings;
  final AuthSuccessCallback onAuthenticated;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              palette.gradientStart,
              palette.gradientMiddle,
              palette.gradientEnd,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 16),
              Text(
                context.t('app.title'),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: palette.textPrimary,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.t('auth.subtitle'),
                style: TextStyle(color: palette.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: AppGlass.blurredTintLayerWithSigma(
                    sigma: AppGlass.blurSigma,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppGlass.tint(isDark),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppGlass.border(isDark)),
                        boxShadow: AppGlass.cardShadows(isDark),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                        indicator: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: palette.accent.withValues(alpha: 0.22),
                        ),
                        labelColor: palette.textPrimary,
                        unselectedLabelColor: palette.textMuted,
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                        padding: const EdgeInsets.all(6),
                        tabs: [
                          Tab(text: context.t('auth.loginTab')),
                          Tab(text: context.t('auth.registerTab')),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _LoginTab(
                      palette: palette,
                      isDark: isDark,
                      settingsRepository: widget.settingsRepository,
                      initialSettings: widget.initialSettings,
                      onSuccess: widget.onAuthenticated,
                    ),
                    _RegisterTab(
                      palette: palette,
                      isDark: isDark,
                      settingsRepository: widget.settingsRepository,
                      initialSettings: widget.initialSettings,
                      onSuccess: widget.onAuthenticated,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassFormCard extends StatelessWidget {
  const _GlassFormCard({
    required this.palette,
    required this.isDark,
    required this.child,
  });

  final AppColorPalette palette;
  final bool isDark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: AppGlass.blurredTintLayerWithSigma(
          sigma: AppGlass.blurSigma,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppGlass.border(isDark)),
              color: AppGlass.tint(isDark),
              boxShadow: AppGlass.cardShadows(isDark),
            ),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginTab extends StatefulWidget {
  const _LoginTab({
    required this.palette,
    required this.isDark,
    required this.settingsRepository,
    required this.initialSettings,
    required this.onSuccess,
  });

  final AppColorPalette palette;
  final bool isDark;
  final SettingsRepository settingsRepository;
  final AppSettings initialSettings;
  final AuthSuccessCallback onSuccess;

  @override
  State<_LoginTab> createState() => _LoginTabState();
}

class _LoginTabState extends State<_LoginTab> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      final acc = await AuthSessionStore.readAccount();
      if (acc == null) {
        setState(() => _error = 'auth.error.noAccount');
        return;
      }
      if (!verifyPassword(_password.text, acc.passwordHash)) {
        setState(() => _error = 'auth.error.badCredentials');
        return;
      }
      if (_email.text.trim().toLowerCase() != acc.email.toLowerCase()) {
        setState(() => _error = 'auth.error.badCredentials');
        return;
      }
      final token = AuthSessionStore.generateSessionToken();
      await AuthSessionStore.writeAccount(acc.copyWith(sessionToken: token));
      final current = await widget.settingsRepository.getSettings();
      await widget.settingsRepository.saveSettings(
        current.copyWith(
          email: acc.email,
          nickname: acc.nickname,
        ),
      );
      await widget.onSuccess();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _GlassFormCard(
      palette: widget.palette,
      isDark: widget.isDark,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: _inputDeco(context, widget.palette, context.t('auth.email')),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return context.t('auth.error.emailInvalid');
                if (!v.contains('@')) return context.t('auth.error.emailInvalid');
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _password,
              obscureText: true,
              decoration: _inputDeco(context, widget.palette, context.t('auth.password')),
              validator: (v) {
                if (v == null || v.isEmpty) return context.t('auth.error.passwordEmpty');
                return null;
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                context.t(_error!),
                style: TextStyle(color: widget.palette.accent, fontSize: 13),
              ),
            ],
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _busy ? null : _submit,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: widget.palette.accent,
                foregroundColor: Colors.white,
              ),
              child: _busy
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(context.t('auth.login')),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegisterTab extends StatefulWidget {
  const _RegisterTab({
    required this.palette,
    required this.isDark,
    required this.settingsRepository,
    required this.initialSettings,
    required this.onSuccess,
  });

  final AppColorPalette palette;
  final bool isDark;
  final SettingsRepository settingsRepository;
  final AppSettings initialSettings;
  final AuthSuccessCallback onSuccess;

  @override
  State<_RegisterTab> createState() => _RegisterTabState();
}

class _RegisterTabState extends State<_RegisterTab> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _nickname = TextEditingController();
  final _invite = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(AuthSessionStore.refreshIssuedInviteKeysCache());
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _nickname.dispose();
    _invite.dispose();
    super.dispose();
  }

  Future<void> _pasteInvite() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final t = data?.text?.trim();
    if (t != null && t.isNotEmpty) {
      setState(() => _invite.text = t);
    }
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (BetaInviteConfig.requireInviteKey && !BetaInviteConfig.isValid(_invite.text)) {
      setState(() => _error = 'auth.error.inviteInvalid');
      return;
    }
    final existing = await AuthSessionStore.readAccount();
    if (existing != null) {
      setState(() => _error = 'auth.error.accountExists');
      return;
    }
    setState(() => _busy = true);
    try {
      final email = _email.text.trim();
      final nick = _nickname.text.trim().isEmpty ? email.split('@').first : _nickname.text.trim();
      final hash = hashPassword(_password.text);
      final token = AuthSessionStore.generateSessionToken();
      await AuthSessionStore.writeAccount(
        LocalAccount(
          email: email,
          passwordHash: hash,
          nickname: nick,
          sessionToken: token,
        ),
      );
      final current = await widget.settingsRepository.getSettings();
      await widget.settingsRepository.saveSettings(
        current.copyWith(email: email, nickname: nick),
      );
      await widget.onSuccess();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _GlassFormCard(
      palette: widget.palette,
      isDark: widget.isDark,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: _inputDeco(context, widget.palette, context.t('auth.email')),
              validator: (v) {
                if (v == null || !v.contains('@')) return context.t('auth.error.emailInvalid');
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nickname,
              decoration: _inputDeco(
                context,
                widget.palette,
                context.t('auth.nickname'),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              obscureText: true,
              decoration: _inputDeco(context, widget.palette, context.t('auth.password')),
              validator: (v) {
                if (v == null || v.length < 6) return context.t('auth.error.shortPassword');
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirm,
              obscureText: true,
              decoration: _inputDeco(context, widget.palette, context.t('auth.confirmPassword')),
              validator: (v) {
                if (v != _password.text) return context.t('auth.error.passwordMismatch');
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _invite,
              decoration: _inputDeco(context, widget.palette, context.t('auth.inviteKey')),
              validator: (v) {
                if (!BetaInviteConfig.requireInviteKey) return null;
                if (v == null || v.trim().isEmpty) {
                  return context.t('auth.error.inviteEmpty');
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _pasteInvite,
                icon: Icon(Icons.content_paste_rounded, size: 18, color: widget.palette.accent),
                label: Text(context.t('auth.pasteInvite')),
              ),
            ),
            if (_error != null) ...[
              Text(
                context.t(_error!),
                style: TextStyle(color: widget.palette.accent, fontSize: 13),
              ),
              const SizedBox(height: 8),
            ],
            FilledButton(
              onPressed: _busy ? null : _submit,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: widget.palette.accent,
                foregroundColor: Colors.white,
              ),
              child: _busy
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(context.t('auth.register')),
            ),
          ],
        ),
      ),
    );
  }
}

InputDecoration _inputDeco(BuildContext context, AppColorPalette p, String label) {
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: p.cardBackground.withValues(alpha: 0.55),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: p.textMuted.withValues(alpha: 0.35)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: p.accent, width: 1.5),
    ),
  );
}
