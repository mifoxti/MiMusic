import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/l10n/app_localization.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_glass.dart';
import '../../../core/theme/app_theme.dart';

typedef OnboardingCompleted = Future<void> Function();

/// Первый запуск: «стеклянные» карточки без [BackdropFilter] + анимированное перелистывание.
/// Размытие при скролле на нескольких страницах убрано — оно перегружало GPU; сами трансформы безопасны.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key, required this.onCompleted});

  final OnboardingCompleted onCompleted;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final PageController _pageController = PageController(viewportFraction: 0.88);
  int _index = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  static const int _count = 4;

  Future<void> _finish() async {
    await widget.onCompleted();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEn = Localizations.localeOf(context).languageCode == 'en';

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
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
              const SizedBox(height: 12),
              Text(
                isEn ? 'Welcome to MiMusic' : 'Добро пожаловать в MiMusic',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: palette.textPrimary,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                isEn ? 'Swipe or tap to explore' : 'Листайте или нажимайте «Далее»',
                style: TextStyle(
                  fontSize: 14,
                  color: palette.textSecondary,
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  allowImplicitScrolling: false,
                  itemCount: _count,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, index) {
                    return RepaintBoundary(
                      child: AnimatedBuilder(
                        animation: _pageController,
                        builder: (context, child) {
                          double page = index.toDouble();
                          if (_pageController.hasClients &&
                              _pageController.position.haveDimensions) {
                            page =
                                (_pageController.page ?? _index.toDouble()) - index;
                          } else {
                            page = (_index - index).toDouble();
                          }
                          final abs = page.abs().clamp(0.0, 1.0);
                          final scale = Tween<double>(begin: 0.88, end: 1.0)
                              .transform(1 - abs);
                          final opacity = Tween<double>(begin: 0.45, end: 1.0)
                              .transform(1 - abs);
                          final rotY = (page * -0.12).clamp(-0.35, 0.35);
                          final slideX = page * 28;
                          return Center(
                            child: Transform.translate(
                              offset: Offset(slideX, 0),
                              child: Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.identity()
                                  ..setEntry(3, 2, 0.0012)
                                  ..rotateY(rotY),
                                child: Opacity(
                                  opacity: opacity.clamp(0.2, 1.0),
                                  child: Transform.scale(
                                    scale: scale,
                                    child: child,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 20,
                            horizontal: 6,
                          ),
                          child: _OnboardingGlassCard(
                            palette: palette,
                            isDark: isDark,
                            icon: _iconFor(index),
                            title: context.t('onboarding.slide${index + 1}.title'),
                            body: context.t('onboarding.slide${index + 1}.body'),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_count, (i) {
                        final active = i == _index;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: active ? 28 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: active
                                ? palette.accent
                                : palette.textMuted.withValues(alpha: 0.35),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        if (_index > 0)
                          TextButton(
                            onPressed: () {
                              _pageController.previousPage(
                                duration: const Duration(milliseconds: 420),
                                curve: Curves.easeOutCubic,
                              );
                            },
                            child: Text(context.t('onboarding.back')),
                          )
                        else
                          const SizedBox(width: 72),
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: palette.accent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: () {
                              if (_index < _count - 1) {
                                _pageController.nextPage(
                                  duration: const Duration(milliseconds: 480),
                                  curve: Curves.easeOutCubic,
                                );
                              } else {
                                unawaited(_finish());
                              }
                            },
                            child: Text(
                              _index < _count - 1
                                  ? context.t('onboarding.next')
                                  : context.t('onboarding.start'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 72),
                      ],
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

  IconData _iconFor(int i) {
    return switch (i) {
      0 => Icons.music_note_rounded,
      1 => Icons.graphic_eq_rounded,
      2 => Icons.groups_rounded,
      _ => Icons.album_rounded,
    };
  }
}

/// Стекло без размытия фона: тот же tint/бордер/тень, что и у [AppGlass], без [BackdropFilter].
class _OnboardingGlassCard extends StatelessWidget {
  const _OnboardingGlassCard({
    required this.palette,
    required this.isDark,
    required this.icon,
    required this.title,
    required this.body,
  });

  final AppColorPalette palette;
  final bool isDark;
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final borderGlass = AppGlass.border(isDark);
    final glassTint = AppGlass.tint(isDark);
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: borderGlass, width: 1.2),
          color: glassTint,
          boxShadow: AppGlass.cardShadows(isDark),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      palette.accent.withValues(alpha: 0.35),
                      palette.accent.withValues(alpha: 0.08),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: palette.accent.withValues(alpha: 0.22),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(icon, size: 52, color: palette.accent),
              ),
              const SizedBox(height: 28),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: palette.textPrimary,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                body,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: palette.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
