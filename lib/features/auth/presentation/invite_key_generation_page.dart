import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/auth/auth_session_store.dart';
import '../../../core/auth/invite_key_format.dart';
import '../../../core/l10n/app_localization.dart';
import '../../../core/network/profile_api.dart';
import '../../../core/theme/app_theme.dart';

/// Полноэкранная анимация формирования ключа; по завершении сохраняет ключ и возвращает его через [Navigator.pop].
class InviteKeyGenerationPage extends StatefulWidget {
  const InviteKeyGenerationPage({super.key});

  @override
  State<InviteKeyGenerationPage> createState() => _InviteKeyGenerationPageState();
}

class _InviteKeyGenerationPageState extends State<InviteKeyGenerationPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final String _key;
  final _rand = math.Random();
  late final List<Alignment> _particleStart;
  late final List<Alignment> _particleEnd;
  late final List<double> _particlePhase;
  bool _finished = false;

  static const _chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

  @override
  void initState() {
    super.initState();
    _key = InviteKeyFormat.generate();
    _particleStart = List.generate(
      36,
      (_) => Alignment(
        _rand.nextDouble() * 2 - 1,
        _rand.nextDouble() * 2 - 1,
      ),
    );
    _particleEnd = List.generate(
      36,
      (_) => Alignment(
        (_rand.nextDouble() * 2 - 1) * 0.35,
        (_rand.nextDouble() * 2 - 1) * 0.35,
      ),
    );
    _particlePhase = List.generate(36, (_) => _rand.nextDouble() * 0.15);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..addStatusListener(_onStatus);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final acc = await AuthSessionStore.readAccount();
    if (!mounted) return;
    if (acc != null &&
        acc.sessionToken.trim().isNotEmpty &&
        acc.userId != null) {
      try {
        final existing = await ProfileApi().fetchMyInviteKey();
        if (existing != null && existing.trim().isNotEmpty) {
          await AuthSessionStore.writeAccount(
            acc.copyWith(myInviteKey: InviteKeyFormat.normalize(existing)),
          );
          if (mounted) Navigator.of(context).pop<String?>(null);
          return;
        }
      } catch (_) {}
    }
    if (acc?.hasMyInviteKey ?? false) {
      if (!mounted) return;
      Navigator.of(context).pop<String?>(null);
      return;
    }
    _controller.forward();
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _finished) return;
    _finished = true;
    unawaited(_complete());
  }

  Future<void> _complete() async {
    final acc = await AuthSessionStore.readAccount();
    final norm = InviteKeyFormat.normalize(_key);
    if (acc != null &&
        acc.sessionToken.trim().isNotEmpty &&
        acc.userId != null) {
      try {
        final saved = await ProfileApi().postMyInviteKey(keyCode: norm);
        final k = InviteKeyFormat.normalize(saved);
        await AuthSessionStore.registerIssuedInviteKey(k);
        await AuthSessionStore.writeAccount(acc.copyWith(myInviteKey: k));
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              Localizations.localeOf(context).languageCode == 'en'
                  ? 'Could not save invite key on server'
                  : 'Не удалось сохранить ключ на сервере',
            ),
          ),
        );
        Navigator.of(context).pop<String?>(null);
        return;
      }
    } else {
      await AuthSessionStore.saveGeneratedInviteKey(_key);
    }
    if (!mounted) return;
    Navigator.of(context).pop<String>(_key);
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onStatus);
    _controller.dispose();
    super.dispose();
  }

  int _slotIndex(int stringIndex) {
    if (stringIndex < 5) return stringIndex;
    if (stringIndex < 11) return stringIndex - 1;
    return stringIndex - 2;
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_finished) return;
        _controller.stop();
        if (mounted) Navigator.of(context).pop<String?>(null);
      },
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
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
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () {
                      if (_finished) return;
                      _controller.stop();
                      Navigator.of(context).pop<String?>(null);
                    },
                    icon: Icon(Icons.close_rounded, color: palette.textPrimary),
                  ),
                ),
                Expanded(
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      final v = _controller.value;
                      return Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          ...List.generate(36, (j) {
                            final t = ((v * 1.08 - _particlePhase[j]) / 0.92).clamp(0.0, 1.0);
                            final curved = Curves.easeInOut.transform(t);
                            final a = Alignment.lerp(
                              _particleStart[j],
                              _particleEnd[j],
                              curved,
                            )!;
                            final opacity = (1.0 - t * 1.15).clamp(0.0, 1.0);
                            if (opacity <= 0.01) return const SizedBox.shrink();
                            final bucket = (v * 120).floor();
                            final ch = _chars[math.Random(j * 7919 + bucket).nextInt(_chars.length)];
                            return Align(
                              alignment: a,
                              child: Opacity(
                                opacity: opacity,
                                child: Text(
                                  ch,
                                  style: TextStyle(
                                    fontSize: 14 + (j % 5) * 2,
                                    fontWeight: FontWeight.w700,
                                    color: palette.textSecondary.withValues(alpha: 0.55),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            );
                          }),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                context.t('invite.generating'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: palette.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 28),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: List.generate(17, (i) {
                                    if (i == 5 || i == 11) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 2),
                                        child: Text(
                                          '-',
                                          style: TextStyle(
                                            fontSize: 26,
                                            fontWeight: FontWeight.w800,
                                            color: palette.textSecondary.withValues(alpha: 0.7),
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      );
                                    }
                                    final slot = _slotIndex(i);
                                    final stagger = slot / 15 * 0.62;
                                    final localT = ((v - stagger) / (1 - stagger)).clamp(0.0, 1.0);
                                    final curved = Curves.easeOutCubic.transform(localT);
                                    final dy = (1 - curved) * -56;
                                    final rot = (1 - curved) * 0.65;
                                    final scramble = localT < 0.88;
                                    final bucket = (v * 200).floor();
                                    final ch = scramble
                                        ? _chars[math.Random(slot * 9973 + bucket).nextInt(_chars.length)]
                                        : _key[i];
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 1),
                                      child: Transform.translate(
                                        offset: Offset(0, dy),
                                        child: Transform.rotate(
                                          angle: rot * (slot.isEven ? 1 : -1),
                                          child: Text(
                                            ch,
                                            style: TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 1.2,
                                              color: palette.textPrimary,
                                              fontFamily: 'monospace',
                                              shadows: isDark
                                                  ? [
                                                      Shadow(
                                                        color: Colors.black.withValues(alpha: 0.45),
                                                        blurRadius: 8,
                                                        offset: const Offset(0, 2),
                                                      ),
                                                    ]
                                                  : null,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
