import 'package:flutter/material.dart';

import '../../core/audio/audio_player_service.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import 'glass_panel.dart';

/// Нижний inset для [SettingsGlassScaffold] (наследуется потомками [child]).
class SettingsChromeInsets extends InheritedWidget {
  const SettingsChromeInsets({
    super.key,
    required this.bottomContentInset,
    required super.child,
  });

  final double bottomContentInset;

  static SettingsChromeInsets? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SettingsChromeInsets>();
  }

  @override
  bool updateShouldNotify(SettingsChromeInsets oldWidget) {
    return oldWidget.bottomContentInset != bottomContentInset;
  }
}

/// Каркас экранов настроек: полный градиент; контент прокручивается под shell chrome.
class SettingsGlassScaffold extends StatelessWidget {
  const SettingsGlassScaffold({
    super.key,
    required this.title,
    required this.child,
    this.audioPlayerService,
    this.showTitleInAppBar = true,
  });

  final String title;
  final Widget child;
  final AudioPlayerService? audioPlayerService;
  final bool showTitleInAppBar;

  static double bottomContentInset(AudioPlayerService? audioPlayerService) {
    if (audioPlayerService?.currentTrack != null) {
      return AppConstants.shellBottomInsetWithMiniPlayer;
    }
    return AppConstants.shellBottomInset;
  }

  /// Отступ прокрутки под shell chrome (мини-плеер + нижняя навигация).
  static EdgeInsets scrollPaddingFor({
    AudioPlayerService? audioPlayerService,
    EdgeInsets base = const EdgeInsets.fromLTRB(20, 8, 20, 12),
  }) {
    return base.copyWith(
      bottom: base.bottom + bottomContentInset(audioPlayerService),
    );
  }

  static EdgeInsets scrollPadding(
    BuildContext context, {
    AudioPlayerService? audioPlayerService,
    EdgeInsets base = const EdgeInsets.fromLTRB(20, 8, 20, 12),
  }) {
    final inherited = SettingsChromeInsets.maybeOf(context)?.bottomContentInset;
    final inset = inherited ?? bottomContentInset(audioPlayerService);
    return base.copyWith(bottom: base.bottom + inset);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;

    Widget body(double bottomInset) {
      return SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SettingsGlassAppBar(
              title: showTitleInAppBar ? title : null,
            ),
            Expanded(
              child: SettingsChromeInsets(
                bottomContentInset: bottomInset,
                child: child,
              ),
            ),
          ],
        ),
      );
    }

    final scaffold = audioPlayerService == null
        ? body(AppConstants.shellBottomInset)
        : ListenableBuilder(
            listenable: audioPlayerService!,
            builder: (context, _) {
              return body(bottomContentInset(audioPlayerService));
            },
          );

    return Container(
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
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: scaffold,
      ),
    );
  }
}

/// Прокручиваемый контент настроек с нижним отступом под мини-плеер (обновляется при смене трека).
class SettingsGlassScrollView extends StatelessWidget {
  const SettingsGlassScrollView({
    super.key,
    required this.child,
    this.audioPlayerService,
    this.physics,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 12),
  });

  final Widget child;
  final AudioPlayerService? audioPlayerService;
  final ScrollPhysics? physics;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    Widget buildScroll(double bottomInset) {
      return SingleChildScrollView(
        physics: physics,
        padding: padding.copyWith(bottom: padding.bottom + bottomInset),
        child: child,
      );
    }

    if (audioPlayerService == null) {
      return buildScroll(AppConstants.shellBottomInset);
    }

    return ListenableBuilder(
      listenable: audioPlayerService!,
      builder: (context, _) {
        return buildScroll(
          SettingsGlassScaffold.bottomContentInset(audioPlayerService),
        );
      },
    );
  }
}

/// Стеклянная кнопка «назад» и заголовок для экранов настроек.
class SettingsGlassAppBar extends StatelessWidget {
  const SettingsGlassAppBar({super.key, this.title});

  final String? title;

  @override
  Widget build(BuildContext context) {
    final palette = AppPaletteExtension.of(context).palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          GlassIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            iconColor: palette.textPrimary,
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Spacer(),
          if (title != null)
            Text(
              title!,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: palette.textPrimary,
              ),
            ),
          const Spacer(),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}
